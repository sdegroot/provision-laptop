#!/usr/bin/env bash
# bootstrap/mac.sh — First-run setup for a fresh Mac.
#
# Usage:
#   curl -fsSL <raw-url>/bootstrap/mac.sh | bash
#   — or —
#   git clone <repo> ~/provision-laptop && ~/provision-laptop/bootstrap/mac.sh

set -euo pipefail

echo "=== macOS Provisioning Bootstrap ==="

# 1. Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Press Enter after Xcode CLI tools installation completes."
    read -r
else
    echo "Xcode CLI tools: already installed"
fi

# 2. Homebrew
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to current session
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "Homebrew: already installed"
fi

# 3. Clone repo if not already present
PROVISION_DIR="${HOME}/provision-laptop"
if [[ ! -d "$PROVISION_DIR" ]]; then
    echo "Installing git via Homebrew..."
    brew install git

    echo "Clone the provisioning repo to ${PROVISION_DIR} and re-run this script."
    echo "  git clone <repo-url> ${PROVISION_DIR}"
    echo "  ${PROVISION_DIR}/bootstrap/mac.sh"
    exit 0
fi

# 4. Run provisioning
echo "Running provisioning..."
"${PROVISION_DIR}/bin/apply"

echo ""
echo "=== Bootstrap complete ==="
echo "Manual steps remaining:"
echo "  1. Install and sign into 1Password"
echo "  2. Enable 1Password SSH agent in Settings > Developer"
echo "  3. Set up YubiKey if applicable"
echo "  4. Open a new terminal to pick up shell changes"
