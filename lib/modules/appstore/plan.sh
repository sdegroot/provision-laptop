#!/usr/bin/env bash
# appstore/plan.sh — Show planned App Store app changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "appstore.txt")"

if ! has_command mas; then
    log_plan "Would need mas installed first (brew install mas)"
    exit 0
fi

installed="$(mas list 2>/dev/null | awk '{print $1}')"
changes_planned=0

while IFS= read -r line; do
    read -r app_id app_name <<< "$line"

    if ! echo "$installed" | grep -q "^${app_id}$"; then
        log_plan "Would install from App Store: ${app_name} (${app_id})"
        changes_planned=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No App Store changes needed"
fi
