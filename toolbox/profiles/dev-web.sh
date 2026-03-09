#!/usr/bin/env bash
# dev-web.sh — Setup for the dev-web toolbox.
set -euo pipefail

echo "=== dev-web profile setup ==="

# Global npm packages
npm_packages=(
    typescript
    ts-node
    eslint
    prettier
)

for pkg in "${npm_packages[@]}"; do
    if ! npm list -g "$pkg" &>/dev/null; then
        echo "Installing npm package: ${pkg}"
        sudo npm install -g "$pkg"
    fi
done

echo "=== dev-web setup complete ==="
