#!/usr/bin/env bash
# directories/plan.sh - Show planned directory changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "directories.txt")"
changes_planned=0

while IFS= read -r line; do
    IFS=':' read -r dir_path dir_owner dir_mode <<< "$line"

    dir_path="${dir_path/#\~/$HOME}"
    dir_owner="${dir_owner:-$USER}"
    dir_owner="${dir_owner/\$\{USER\}/$USER}"
    dir_mode="${dir_mode:-0755}"

    effective_path="${PROVISION_ROOT}${dir_path}"

    if [[ ! -d "$effective_path" ]]; then
        log_plan "Would create directory: ${dir_path} (mode: ${dir_mode})"
        changes_planned=1
        continue
    fi

    if [[ "$(uname)" == "Darwin" ]]; then
        current_mode=$(stat -f '%Lp' "$effective_path" 2>/dev/null || echo "unknown")
    else
        current_mode=$(stat -c '%a' "$effective_path" 2>/dev/null || echo "unknown")
    fi

    expected_mode="${dir_mode#0}"

    if [[ "$current_mode" != "$expected_mode" ]]; then
        log_plan "Would fix mode on ${dir_path}: ${current_mode} -> ${dir_mode}"
        changes_planned=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No directory changes needed"
fi
