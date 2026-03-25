#!/usr/bin/env bash
# usr-tools/plan.sh — Show planned user-level tool installs.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "usr-tools.conf")"
changes_planned=0

while IFS= read -r line; do
    name="$(echo "$line" | awk '{print $1}')"
    check_path="$(echo "$line" | awk '{print $2}')"

    check_path="${check_path/#\~/$HOME}"

    if [[ ! -x "$check_path" ]]; then
        log_plan "Would install ${name}"
        changes_planned=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No user tool changes needed"
fi
