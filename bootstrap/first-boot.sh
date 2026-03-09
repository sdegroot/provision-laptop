#!/usr/bin/env bash
# first-boot.sh — Optional first boot provisioning helper.
#
# This script can be run manually after first boot to apply provisioning.
# It assumes the repo was already copied to ~/provision-laptop by kickstart.
#
# Prerequisites (must be done manually first):
#   1. YubiKey enrolled for LUKS (systemd-cryptenroll)
#   2. 1Password installed, signed in, SSH agent enabled
#
# Usage: ~/provision-laptop/bootstrap/first-boot.sh

set -euo pipefail

PROVISION_PATH="${PROVISION_PATH:-${HOME}/provision-laptop}"

echo "=== Laptop Provisioning ==="

if [[ ! -d "${PROVISION_PATH}" ]]; then
    echo "ERROR: Provisioning repo not found at ${PROVISION_PATH}"
    echo "Clone it first: git clone git@github.com:sdegroot/provision-laptop.git"
    exit 1
fi

# Update to latest if we have SSH access
cd "$PROVISION_PATH"
if git remote get-url origin | grep -q 'git@'; then
    echo "Pulling latest changes..."
    git pull --ff-only || echo "WARNING: git pull failed, using bundled version"
fi

# Run full provisioning
echo "Running bin/apply..."
bin/apply

echo ""
echo "=== Provisioning Complete ==="
echo ""
echo "Next steps:"
echo "  1. Change your password: passwd"
echo "  2. Review: bin/check"
echo "  3. Optionally remove passwordless sudo:"
echo "     sudo rm /etc/sudoers.d/sdegroot"
