#!/usr/bin/env bash
# post-install.sh — Reference for kickstart %post logic.
#
# This file documents the post-install steps. The actual %post scripts
# are inlined in vm-single-disk.ks and laptop-dual-disk.ks because
# kickstart %post sections cannot source external scripts.
#
# VM post-install:
#   - Passwordless sudo for sdegroot
#   - Enable SSH password auth
#   - Install git via rpm-ostree
#
# Laptop post-install:
#   - Passwordless sudo for sdegroot
#   - Layer YubiKey packages (libfido2, yubikey-manager, pam-u2f)
#   - Layer git
#   - Copy provision-laptop repo from OEMDRV volume
#   - Configure dracut for FIDO2 LUKS unlock
#   - NO SSH enabled
#
# After first boot (laptop):
#   1. Enroll YubiKey for LUKS:
#        sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p3
#        sudo systemd-cryptenroll --fido2-device=auto /dev/nvme1n1p1
#   2. Install 1Password from Flathub, sign in, enable SSH agent
#   3. cd ~/provision-laptop && git remote set-url origin git@github.com:sdegroot/provision-laptop.git
#   4. git pull && bin/apply
