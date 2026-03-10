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
%post --log=/root/kickstart-post.log

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

# Copy provisioning repo from OEMDRV volume (nochroot)
# Runs in the real installer environment with full device access.
# The chrooted %post cannot reliably mount USB partitions — mount fails
# silently inside the /mnt/sysroot chroot.
%post --nochroot --log=/mnt/sysroot/root/kickstart-post-nochroot.log

echo "=== Post-install (nochroot): copying provisioning repo ==="

OEMDRV_DEV="/dev/disk/by-label/OEMDRV"
OEMDRV_MOUNT="/mnt/oemdrv"
TARGET_DIR="/mnt/sysroot/home/sdegroot/provision-laptop"

if [[ ! -e "$OEMDRV_DEV" ]]; then
    echo "ERROR: OEMDRV device not found at $OEMDRV_DEV"
    echo "After first boot, clone manually:"
    echo "  git clone git@github.com:sdegroot/provision-laptop.git"
    exit 1
fi

mkdir -p "$OEMDRV_MOUNT"
if ! mount "$OEMDRV_DEV" "$OEMDRV_MOUNT"; then
    echo "ERROR: Failed to mount $OEMDRV_DEV at $OEMDRV_MOUNT"
    exit 1
fi

if [[ ! -d "${OEMDRV_MOUNT}/provision-laptop" ]]; then
    echo "ERROR: provision-laptop not found on OEMDRV volume"
    echo "Contents of OEMDRV:"
    ls -la "$OEMDRV_MOUNT"
    umount "$OEMDRV_MOUNT"
    exit 1
fi

echo "Copying provisioning repo from OEMDRV..."
cp -a "${OEMDRV_MOUNT}/provision-laptop" "$TARGET_DIR"
# Use numeric UID/GID — passwd is inside the chroot, not accessible here
chown -R 1000:1000 "$TARGET_DIR"
echo "Provisioning repo copied to $TARGET_DIR"

umount "$OEMDRV_MOUNT"
echo "=== Post-install (nochroot) complete ==="
%end
