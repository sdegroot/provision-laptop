# laptop-dual-disk.ks — Fedora Silverblue kickstart for laptop hardware.
#
# WARNING: This will erase ALL data on both NVMe drives.
# Adjust device names in includes/partitioning-laptop.ks for your hardware.

# Include common configuration
%include /run/install/repo/base.ks

# Include laptop partitioning
%include /run/install/repo/includes/partitioning-laptop.ks

# Select Silverblue environment
ostreesetup --osname=fedora --url=file:///ostree/repo --ref=fedora/41/x86_64/silverblue --nogpg

# Post-install script
%post --log=/root/kickstart-post.log

# Passwordless sudo for provisioning (remove after setup)
echo "admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/admin
chmod 0440 /etc/sudoers.d/admin

# Install git
rpm-ostree install git --allow-inactive

echo "Kickstart post-install complete."
echo "After reboot, clone the provisioning repo and run bin/install."
%end
