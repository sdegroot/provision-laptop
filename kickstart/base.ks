# base.ks — Common Fedora Silverblue kickstart configuration.
#
# This file is included by environment-specific kickstart files.
# Do NOT use standalone.

# Text-mode install — auto-proceeds when all kickstart directives are present
# (graphical mode uses the Anaconda "hub" which always requires manual clicks)
text

# System language and keyboard
lang en_US.UTF-8
keyboard us
timezone Europe/Amsterdam --utc

# Network
network --bootproto=dhcp --activate --onboot=yes
network --hostname=silverblue-workstation

# Root account (locked — use sudo instead)
rootpw --lock

# User account
user --name=sdegroot --groups=wheel --plaintext --password=changeme

# SELinux enforcing (always)
selinux --enforcing

# Disable initial setup (we handle config via provision-laptop)
firstboot --disable

# Reboot after installation
reboot --eject
