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
    rpm-ostree install --idempotent \
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

# --- Copy provisioning repo from OEMDRV on first boot ---
#
# Four previous attempts to copy during Anaconda %post all failed:
#   1. Chrooted %post mount: OEMDRV mount fails (no USB device access in chroot)
#   2. Nochroot writing to /mnt/sysroot/home: LUKS data volume not mounted
#   3. Nochroot staging to /var/tmp: ostree symlinks unresolvable, --log path
#      through symlinks may cause Anaconda to skip the section entirely
#   4. Nochroot with readlink + fallback paths: no evidence script ran, no logs
#
# Solution: abandon %post for OEMDRV access entirely. Create a first-boot
# systemd service that runs in the real OS environment where the kernel has
# full device access and all filesystems are properly mounted.
# The USB is still physically connected after reboot --eject (eject only
# unmounts, doesn't physically disconnect). If the user removed the USB,
# the service silently skips and first-boot.sh tells them to git clone.
%post --log=/var/log/kickstart-post-repo.log

cat > /etc/systemd/system/kickstart-repo-copy.service <<'UNIT'
[Unit]
Description=Copy provisioning repo from OEMDRV USB partition
After=local-fs.target
ConditionPathExists=!/var/lib/kickstart-repo-copy.done

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\
    exec > /var/log/kickstart-repo-copy.log 2>&1; \
    set -x; \
    echo "=== kickstart-repo-copy: $(date) ==="; \
    TARGET="/home/sdegroot/provision-laptop"; \
    if [[ -d "$TARGET" ]]; then \
        echo "Repo already exists at $TARGET — nothing to do"; \
        touch /var/lib/kickstart-repo-copy.done; \
        exit 0; \
    fi; \
    OEMDRV_DEV="/dev/disk/by-label/OEMDRV"; \
    echo "--- block devices ---"; \
    ls -la /dev/disk/by-label/ 2>/dev/null || true; \
    if [[ ! -e "$OEMDRV_DEV" ]]; then \
        echo "OEMDRV not found — USB may have been removed"; \
        echo "Clone manually: git clone git@github.com:sdegroot/provision-laptop.git ~/provision-laptop"; \
        touch /var/lib/kickstart-repo-copy.done; \
        exit 0; \
    fi; \
    OEMDRV_MOUNT="/run/oemdrv"; \
    mkdir -p "$OEMDRV_MOUNT"; \
    if ! mount "$OEMDRV_DEV" "$OEMDRV_MOUNT"; then \
        echo "Failed to mount OEMDRV"; \
        touch /var/lib/kickstart-repo-copy.done; \
        exit 0; \
    fi; \
    if [[ ! -d "${OEMDRV_MOUNT}/provision-laptop" ]]; then \
        echo "provision-laptop not found on OEMDRV"; \
        ls -la "$OEMDRV_MOUNT"; \
        umount "$OEMDRV_MOUNT"; \
        touch /var/lib/kickstart-repo-copy.done; \
        exit 0; \
    fi; \
    echo "Copying provisioning repo..."; \
    mkdir -p /home/sdegroot; \
    cp -a "${OEMDRV_MOUNT}/provision-laptop" "$TARGET"; \
    chown -R sdegroot:sdegroot /home/sdegroot; \
    restorecon -R "$TARGET" 2>/dev/null || true; \
    umount "$OEMDRV_MOUNT"; \
    du -sh "$TARGET"; \
    echo "SUCCESS: provisioning repo copied to $TARGET"; \
    touch /var/lib/kickstart-repo-copy.done'
RemainAfterExit=yes
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable kickstart-repo-copy.service

echo "kickstart-repo-copy.service installed and enabled"
%end
