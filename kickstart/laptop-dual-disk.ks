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

# Passwordless sudo for provisioning (remove after setup if desired)
echo "sdegroot ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sdegroot
chmod 0440 /etc/sudoers.d/sdegroot

# --- Layer essential packages via rpm-ostree ---
# These are needed before bin/apply can run

# YubiKey support (for LUKS FIDO2 enrollment + authentication)
# libfido2: FIDO2 library (used by systemd-cryptenroll)
# yubikey-manager: CLI tool for YubiKey management (ykman)
# pam-u2f: PAM module for U2F/FIDO2 auth (sudo, login)
rpm-ostree install \
    libfido2 \
    yubikey-manager \
    pam-u2f \
    --allow-inactive

# Git (for pulling repo updates after first boot)
rpm-ostree install git --allow-inactive

# --- Copy provisioning repo from OEMDRV volume ---
# The USB installer bundles the repo on the OEMDRV partition.
# We copy it to the user's home directory for immediate use.

OEMDRV_MOUNT=""
for dev in /dev/disk/by-label/OEMDRV; do
    if [[ -e "$dev" ]]; then
        OEMDRV_MOUNT="/mnt/oemdrv"
        mkdir -p "$OEMDRV_MOUNT"
        mount "$dev" "$OEMDRV_MOUNT" || true
        break
    fi
done

if [[ -d "${OEMDRV_MOUNT}/provision-laptop" ]]; then
    echo "Copying provisioning repo from OEMDRV..."
    cp -a "${OEMDRV_MOUNT}/provision-laptop" /home/sdegroot/provision-laptop
    chown -R sdegroot:sdegroot /home/sdegroot/provision-laptop
    echo "Provisioning repo copied to /home/sdegroot/provision-laptop"
else
    echo "WARNING: provision-laptop not found on OEMDRV volume"
    echo "After first boot, clone manually:"
    echo "  git clone git@github.com:sdegroot/provision-laptop.git"
fi

if [[ -n "$OEMDRV_MOUNT" ]]; then
    umount "$OEMDRV_MOUNT" 2>/dev/null || true
fi

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
