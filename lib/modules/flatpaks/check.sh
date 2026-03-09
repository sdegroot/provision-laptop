#!/usr/bin/env bash
# flatpaks/check.sh — Verify all desired Flatpak apps are installed.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "flatpaks.txt")"
drift_found=0

if ! has_command flatpak; then
    log_error "flatpak command not found"
    exit 1
fi

# Get list of installed Flatpak app IDs
installed="$(flatpak list --app --columns=application 2>/dev/null || true)"

while IFS= read -r app_id; do
    if echo "$installed" | grep -q "^${app_id}$"; then
        log_ok "Installed: ${app_id}"
    else
        log_error "Missing: ${app_id}"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All Flatpak applications match desired state"
fi

exit $drift_found
