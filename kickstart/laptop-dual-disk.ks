# laptop-dual-disk.ks — Fedora Silverblue kickstart for laptop hardware.
#
# WARNING: This will erase ALL data on both NVMe drives.
# Adjust device names in includes/partitioning-laptop.ks for your hardware.
#
# What this does:
#   - Installs Fedora Silverblue with LUKS2 + Btrfs on dual NVMe
#   - Creates user with passwordless sudo (for provisioning)
#   - Installs YubiKey and 1Password packages
#   - Copies provision-laptop repo from OEMDRV volume
#   - No SSH (not needed on physical laptop)
#
# After first boot:
#   1. Enroll YubiKey for LUKS:
#        sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p3
#        sudo systemd-cryptenroll --fido2-device=auto /dev/nvme1n1p1
#   2. Install & sign into 1Password, enable SSH agent
#   3. cd ~/provision-laptop && git remote set-url origin git@github.com:sdegroot/provision-laptop.git
#   4. git pull && bin/apply

# Include common configuration
%include base.ks

# Laptop-specific: firewall enabled, NO SSH
firewall --enabled
services --enabled=NetworkManager

# Include laptop partitioning (LUKS2 + Btrfs on dual NVMe)
%include includes/partitioning-laptop.ks

# Select Silverblue environment (x86_64 for laptop hardware)
ostreesetup --osname=fedora --url=file:///ostree/repo --ref=fedora/43/x86_64/silverblue --nogpg

# Post-install script
# Log to /var/log/ — on ostree, /root is a symlink to /var/roothome which
# may not resolve correctly in all contexts.
%post --log=/var/log/kickstart-post.log

echo "=== Post-install: configuring laptop ==="

# Ensure graphical desktop starts after boot — the 'text' kickstart directive
# (used for unattended install) sets the default target to multi-user.target,
# but Silverblue's GNOME desktop is part of the ostree image and should start.
systemctl set-default graphical.target

# Passwordless sudo for provisioning (remove after setup if desired)
echo "sdegroot ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sdegroot
chmod 0440 /etc/sudoers.d/sdegroot

# --- Layer essential packages on first boot ---
# rpm-ostree install doesn't persist during Anaconda %post because the ostree
# deployment isn't fully active. Instead, create a one-shot systemd service
# that layers the packages on first boot, then reboots into the new deployment.
cat > /etc/systemd/system/kickstart-packages.service <<'UNIT'
[Unit]
Description=Layer kickstart packages via rpm-ostree
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/kickstart-packages.done

[Service]
Type=oneshot
ExecStart=/bin/bash -c ' \
    rpm-ostree install \
        libfido2 \
        yubikey-manager \
        pam-u2f && \
    touch /var/lib/kickstart-packages.done && \
    systemctl reboot'
ExecStartPost=/usr/bin/touch /var/lib/kickstart-packages.done
RemainAfterExit=yes
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable kickstart-packages.service

# --- Configure FIDO2 for LUKS unlock ---
# We can't enroll the YubiKey during kickstart (no USB access in %post),
# but we can configure dracut to include FIDO2 support so that after
# enrollment, the YubiKey unlock works on boot.
cat > /etc/dracut.conf.d/fido2.conf <<DRACUT
add_dracutmodules+=" fido2 "
DRACUT

echo "=== Post-install complete ==="
echo ""
echo "After first boot:"
echo "  1. Enroll YubiKey for LUKS (systemd-cryptenroll --fido2-device=auto)"
echo "  2. Install & configure 1Password"
echo "  3. cd ~/provision-laptop && git pull && bin/apply"
%end

# --- Layer 1: nochroot %post — mount USB and stage repo ---
#
# Belt-and-suspenders approach for copying the provisioning repo from OEMDRV.
# Three previous attempts failed due to the ostree + dual-disk combo:
#   1. Chrooted %post: OEMDRV mount fails silently (no USB device access)
#   2. Nochroot %post writing to /mnt/sysroot/home: separate LUKS volume not mounted
#   3. Nochroot staging to /mnt/sysroot/var/tmp: ostree symlinks unresolvable,
#      --log path through symlinks may cause Anaconda to skip entire section
#
# Key insight: log to /tmp/ (installer tmpfs, always writable) — NOT through
# ostree symlinks. Use readlink -f to resolve staging paths.
%post --nochroot --log=/tmp/kickstart-nochroot.log
set -x

echo "=== Nochroot: staging provisioning repo from OEMDRV ==="

# --- Diagnostics ---
echo "--- mount state ---"
mount | grep -E 'sysroot|home|ostree' || true
echo "--- /mnt/sysroot layout ---"
ls -la /mnt/sysroot/ 2>/dev/null || true
echo "--- /mnt/sysroot symlinks ---"
ls -la /mnt/sysroot/var /mnt/sysroot/root /mnt/sysroot/home 2>/dev/null || true
echo "--- readlink tests ---"
readlink -f /mnt/sysroot/var 2>/dev/null || echo "readlink /mnt/sysroot/var failed"
readlink -f /mnt/sysroot/root 2>/dev/null || echo "readlink /mnt/sysroot/root failed"
echo "--- block devices ---"
ls -la /dev/disk/by-label/ 2>/dev/null || true

# --- Mount OEMDRV ---
OEMDRV_DEV="/dev/disk/by-label/OEMDRV"
OEMDRV_MOUNT="/mnt/oemdrv"

if [[ ! -e "$OEMDRV_DEV" ]]; then
    echo "WARNING: OEMDRV device not found at $OEMDRV_DEV"
    echo "Repo will need to be cloned manually after boot."
    exit 0
fi

mkdir -p "$OEMDRV_MOUNT"
if ! mount "$OEMDRV_DEV" "$OEMDRV_MOUNT"; then
    echo "WARNING: Failed to mount $OEMDRV_DEV"
    exit 0
fi

if [[ ! -d "${OEMDRV_MOUNT}/provision-laptop" ]]; then
    echo "WARNING: provision-laptop not found on OEMDRV"
    ls -la "$OEMDRV_MOUNT"
    umount "$OEMDRV_MOUNT"
    exit 0
fi

# --- Copy to installer tmpfs first (known-good) ---
echo "Copying repo to installer /tmp/..."
cp -a "${OEMDRV_MOUNT}/provision-laptop" /tmp/provision-laptop
du -sh /tmp/provision-laptop
umount "$OEMDRV_MOUNT"

# --- Stage to /mnt/sysroot using resolved paths ---
STAGED=""

# Attempt 1: resolve /mnt/sysroot/var via readlink (handles ostree symlinks)
RESOLVED_VAR="$(readlink -f /mnt/sysroot/var 2>/dev/null || true)"
if [[ -n "$RESOLVED_VAR" ]] && [[ -d "$RESOLVED_VAR" ]]; then
    STAGING="${RESOLVED_VAR}/tmp/provision-laptop"
    echo "Staging to resolved path: $STAGING"
    mkdir -p "$(dirname "$STAGING")"
    if cp -a /tmp/provision-laptop "$STAGING"; then
        STAGED="$STAGING"
        echo "SUCCESS: staged at $STAGING"
    else
        echo "FAILED: cp to $STAGING"
    fi
fi

# Attempt 2: direct ostree physical path (no symlink resolution needed)
if [[ -z "$STAGED" ]]; then
    STAGING="/mnt/sysroot/ostree/deploy/fedora/var/tmp/provision-laptop"
    echo "Trying direct ostree path: $STAGING"
    mkdir -p "$(dirname "$STAGING")"
    if cp -a /tmp/provision-laptop "$STAGING"; then
        STAGED="$STAGING"
        echo "SUCCESS: staged at $STAGING"
    else
        echo "FAILED: cp to $STAGING"
    fi
fi

# Attempt 3: root of sysroot btrfs (always exists)
if [[ -z "$STAGED" ]]; then
    STAGING="/mnt/sysroot/provision-staging/provision-laptop"
    echo "Trying sysroot root fallback: $STAGING"
    mkdir -p "$(dirname "$STAGING")"
    if cp -a /tmp/provision-laptop "$STAGING"; then
        STAGED="$STAGING"
        echo "SUCCESS: staged at $STAGING"
    else
        echo "FAILED: cp to $STAGING — all staging attempts exhausted"
    fi
fi

# Copy nochroot log alongside staging for post-boot debugging
if [[ -n "$STAGED" ]]; then
    cp /tmp/kickstart-nochroot.log "$(dirname "$STAGED")/" 2>/dev/null || true
fi

echo "=== Nochroot: done (staged=$STAGED) ==="
exit 0
%end

# --- Layer 2: chrooted %post — move staged repo to /home/ ---
#
# In the chroot, all target filesystems (/home on the data disk) are properly
# mounted, so we can move the staged repo to its final location.
%post --log=/var/log/kickstart-post-repo.log
set -x

echo "=== Chrooted: moving staged repo to /home/sdegroot/ ==="

TARGET="/home/sdegroot/provision-laptop"

# Check staging locations in order of preference
FOUND=""
for candidate in \
    /var/tmp/provision-laptop \
    /provision-staging/provision-laptop; do
    echo "Checking: $candidate"
    if [[ -d "$candidate" ]]; then
        FOUND="$candidate"
        echo "Found staged repo at $candidate"
        break
    fi
done

if [[ -n "$FOUND" ]]; then
    # Move to final location
    if [[ ! -d /home/sdegroot ]]; then
        mkdir -p /home/sdegroot
        chown sdegroot:sdegroot /home/sdegroot
    fi
    echo "Moving $FOUND -> $TARGET"
    mv "$FOUND" "$TARGET"
    chown -R sdegroot:sdegroot "$TARGET"
    restorecon -R "$TARGET" 2>/dev/null || true
    du -sh "$TARGET"
    echo "SUCCESS: provisioning repo at $TARGET"
else
    echo "No staged repo found. Trying direct OEMDRV mount as last resort..."
    # Last resort: try mounting OEMDRV directly (may fail in chroot)
    OEMDRV_DEV="/dev/disk/by-label/OEMDRV"
    if [[ -e "$OEMDRV_DEV" ]]; then
        mkdir -p /mnt/oemdrv
        if mount "$OEMDRV_DEV" /mnt/oemdrv 2>/dev/null; then
            if [[ -d /mnt/oemdrv/provision-laptop ]]; then
                mkdir -p /home/sdegroot
                chown sdegroot:sdegroot /home/sdegroot
                cp -a /mnt/oemdrv/provision-laptop "$TARGET"
                chown -R sdegroot:sdegroot "$TARGET"
                restorecon -R "$TARGET" 2>/dev/null || true
                echo "SUCCESS: copied directly from OEMDRV in chroot"
            fi
            umount /mnt/oemdrv
        else
            echo "WARNING: OEMDRV mount failed in chroot (expected)"
        fi
    else
        echo "WARNING: OEMDRV device not found"
    fi
fi

if [[ ! -d "$TARGET" ]]; then
    echo "WARNING: provisioning repo not available"
    echo "After first boot, clone manually:"
    echo "  git clone git@github.com:sdegroot/provision-laptop.git"
fi

echo "=== Chrooted: repo copy done ==="
exit 0
%end
