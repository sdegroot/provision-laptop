#!/usr/bin/env bash
# dev-python.sh — Setup for the dev-python toolbox.
set -euo pipefail

echo "=== dev-python profile setup ==="

# Install pipx for CLI tools
if ! command -v pipx &>/dev/null; then
    pip3 install --user pipx
    pipx ensurepath
fi

# Install common Python CLI tools via pipx
python_tools=(
    black
    ruff
    mypy
    poetry
)

for tool in "${python_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        echo "Installing: ${tool}"
        pipx install "$tool" || true
    fi
done

echo "=== dev-python setup complete ==="
