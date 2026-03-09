#!/usr/bin/env bash
# dev-base.sh — Setup for the dev-base toolbox.
set -euo pipefail

echo "=== dev-base profile setup ==="

# Install starship prompt
if ! command -v starship &>/dev/null; then
    echo "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
fi

echo "=== dev-base setup complete ==="
