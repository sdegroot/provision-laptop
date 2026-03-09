#!/usr/bin/env bash
# dev-python.sh — Setup for the dev-python toolbox.
set -euo pipefail

echo "=== dev-python profile setup ==="

# Install pipx via dnf (avoids PATH issues with pip install --user)
if ! command -v pipx &>/dev/null; then
    echo "Installing pipx via dnf..."
    sudo dnf install -y pipx
fi

# Install common Python CLI tools via pipx
python_tools=(
    black
    ruff
    mypy
    poetry
)

for tool in "${python_tools[@]}"; do
    if ! pipx list 2>/dev/null | grep -q "package ${tool}"; then
        echo "Installing: ${tool}"
        pipx install "$tool" || true
    fi
done

echo "=== dev-python setup complete ==="
