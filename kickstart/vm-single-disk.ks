# vm-single-disk.ks — Fedora Silverblue kickstart for VM testing.
#
# Usage: Boot ISO with inst.ks=<url-to-this-file>

# Include common configuration
%include /run/install/repo/base.ks

# Include VM partitioning
%include /run/install/repo/includes/partitioning-vm.ks

# Select Silverblue environment
ostreesetup --osname=fedora --url=file:///ostree/repo --ref=fedora/41/aarch64/silverblue --nogpg

# Post-install script
%post --log=/root/kickstart-post.log

# Ensure admin user has passwordless sudo (for provisioning)
echo "admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/admin
chmod 0440 /etc/sudoers.d/admin

# Install git for repo cloning (will be available after reboot)
rpm-ostree install git --allow-inactive

# Clone the provisioning repository
if command -v git &>/dev/null; then
    git clone https://github.com/sdegroot/provision-laptop.git /home/admin/provision-laptop || true
    chown -R admin:admin /home/admin/provision-laptop
fi

echo "Kickstart post-install complete."
%end
