#!/usr/bin/env bash
# first-boot.sh — First boot provisioning script.
#
# This can be run manually or via the systemd service.
# It clones the provisioning repo and runs bin/install.

set -euo pipefail

REPO_URL="${PROVISION_REPO_URL:-https://github.com/sdegroot/provision-laptop.git}"
PROVISION_PATH="${PROVISION_PATH:-${HOME}/provision-laptop}"

echo "=== First Boot Setup ==="

# Clone or update
if [[ -d "${PROVISION_PATH}" ]]; then
    echo "Updating provisioning repo..."
    cd "$PROVISION_PATH"
    git pull --ff-only
else
    echo "Cloning provisioning repo..."
    git clone "$REPO_URL" "$PROVISION_PATH"
fi

# Run install
echo "Running provisioning..."
cd "$PROVISION_PATH"
bin/install

echo "=== First Boot Complete ==="
echo ""
echo "Next steps:"
echo "  1. Change your password: passwd"
echo "  2. Set up 1Password: see docs/1password-setup.md"
echo "  3. Enroll YubiKey: see docs/yubikey-setup.md"
echo "  4. Remove passwordless sudo: sudo rm /etc/sudoers.d/admin"
