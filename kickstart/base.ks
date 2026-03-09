# base.ks — Common Fedora Silverblue kickstart configuration.
#
# This file is included by environment-specific kickstart files.
# Do NOT use standalone.

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
user --name=admin --groups=wheel --plaintext --password=changeme

# SELinux and firewall
selinux --enforcing
firewall --enabled --ssh

# Services
services --enabled=sshd,NetworkManager

# Disable initial setup (we handle config via provision-laptop)
firstboot --disable

# Reboot after installation
reboot --eject
