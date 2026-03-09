#!/usr/bin/env bash
# base-setup.sh — Common setup applied to all toolbox containers.
set -euo pipefail

echo "=== Toolbox Base Setup ==="

# Update package cache
sudo dnf update -y --refresh

# Install base packages if any are specified
if [[ $# -gt 0 ]]; then
    echo "Installing packages: $*"
    sudo dnf install -y "$@"
fi

echo "=== Base setup complete ==="
