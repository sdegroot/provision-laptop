# vm-single-disk.ks — Fedora Silverblue kickstart for VM testing.
#
# Flattened by tests/vm/kickstart-install.sh before use.

# Include common configuration
%include base.ks

# VM-specific: enable SSH and allow it through firewall
firewall --enabled --ssh
services --enabled=sshd,NetworkManager

# Include VM partitioning (no LUKS — for automated testing)
%include includes/partitioning-vm.ks

# Select Silverblue environment (aarch64 for Apple Silicon VM)
ostreesetup --osname=fedora --url=file:///ostree/repo --ref=fedora/43/aarch64/silverblue --nogpg

# Post-install script
%post --log=/root/kickstart-post.log

# Set up passwordless sudo for provisioning user
echo "sdegroot ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sdegroot
chmod 0440 /etc/sudoers.d/sdegroot

# Enable password authentication for SSH (needed for VM access from host)
cat > /etc/ssh/sshd_config.d/99-allow-password.conf <<SSHEOF
PasswordAuthentication yes
SSHEOF

# Install git for repo cloning (will be available after reboot)
rpm-ostree install git --allow-inactive

echo "Kickstart post-install complete."
%end
