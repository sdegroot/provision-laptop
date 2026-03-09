#!/usr/bin/env bash
# test_flatpaks.sh — Verify Flatpak applications.
set -euo pipefail

echo "Checking Flatpaks..."

# Verify flatpak command exists
if ! command -v flatpak &>/dev/null; then
    echo "FAIL: flatpak not found"
    exit 1
fi
echo "  OK: flatpak command available"

# Verify Flathub remote exists
if ! flatpak remote-list --columns=name 2>/dev/null | grep -q "^flathub$"; then
    echo "WARN: Flathub remote not configured"
else
    echo "  OK: Flathub remote configured"
fi

# Count installed apps
app_count="$(flatpak list --app --columns=application 2>/dev/null | wc -l || echo 0)"
echo "  Installed Flatpak apps: ${app_count}"

echo "Flatpaks check: OK"
