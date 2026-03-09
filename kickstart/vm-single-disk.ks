# vm-single-disk.ks — Fedora Silverblue kickstart for VM testing.
#
# This file uses %include with relative paths that only work when served
# from the ISO or when flattened by tests/vm/kickstart-install.sh.
# For automated VM installs, the flatten script inlines all includes.

# Include common configuration
%include base.ks

# Include VM partitioning
%include includes/partitioning-vm.ks

# Select Silverblue environment (aarch64 for Apple Silicon VM)
ostreesetup --osname=fedora --url=file:///ostree/repo --ref=fedora/41/aarch64/silverblue --nogpg

# Post-install script
%post --log=/root/kickstart-post.log

# Set up passwordless sudo for provisioning user
echo "sdegroot ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sdegroot
chmod 0440 /etc/sudoers.d/sdegroot

# Enable password authentication for SSH (needed for initial VM access)
cat > /etc/ssh/sshd_config.d/99-allow-password.conf <<SSHEOF
PasswordAuthentication yes
SSHEOF

# Install git for repo cloning (will be available after reboot)
rpm-ostree install git --allow-inactive

echo "Kickstart post-install complete."
%end
