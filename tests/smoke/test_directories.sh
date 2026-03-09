#!/usr/bin/env bash
# test_directories.sh — Verify required directories exist.
set -euo pipefail

echo "Checking directories..."

dirs=(
    "${HOME}/.config"
    "${HOME}/.local/bin"
    "${HOME}/.ssh"
)

for dir in "${dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "  OK: ${dir}"
    else
        echo "  MISSING: ${dir}"
    fi
done

echo "Directories check: OK"
