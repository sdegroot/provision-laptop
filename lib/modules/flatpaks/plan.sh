#!/usr/bin/env bash
# flatpaks/plan.sh — Show planned Flatpak changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "flatpaks.txt")"
changes_planned=0

if ! has_command flatpak; then
    log_plan "Would need to install flatpak first"
    exit 0
fi

installed="$(flatpak list --app --columns=application 2>/dev/null || true)"

while IFS= read -r app_id; do
    if echo "$installed" | grep -q "^${app_id}$"; then
        continue
    fi

    log_plan "Would install Flatpak: ${app_id}"
    changes_planned=1
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No Flatpak changes needed"
fi
