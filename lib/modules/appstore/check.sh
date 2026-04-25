#!/usr/bin/env bash
# appstore/check.sh — Verify Mac App Store apps are installed.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "appstore.txt")"
drift_found=0

if ! has_command mas; then
    log_warn "mas not installed — skipping App Store check"
    exit 0
fi

installed="$(mas list 2>/dev/null | awk '{print $1}')"

while IFS= read -r line; do
    read -r app_id app_name <<< "$line"

    if echo "$installed" | grep -q "^${app_id}$"; then
        log_ok "Installed: ${app_name} (${app_id})"
    else
        log_error "Missing: ${app_name} (${app_id})"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All App Store apps match desired state"
fi

exit $drift_found
