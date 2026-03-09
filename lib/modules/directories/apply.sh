#!/usr/bin/env bash
# directories/apply.sh - Create required directories.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "directories.txt")"
changes_made=0

while IFS= read -r line; do
    IFS=':' read -r dir_path dir_owner dir_mode <<< "$line"

    dir_path="${dir_path/#\~/$HOME}"
    dir_owner="${dir_owner:-$USER}"
    dir_owner="${dir_owner/\$\{USER\}/$USER}"
    dir_mode="${dir_mode:-0755}"

    effective_path="${PROVISION_ROOT}${dir_path}"

    if [[ ! -d "$effective_path" ]]; then
        log_info "Creating directory: ${dir_path} (mode: ${dir_mode})"
        mkdir -p "$effective_path"
        chmod "$dir_mode" "$effective_path"
        changes_made=1
    else
        # Fix permissions if needed
        if [[ "$(uname)" == "Darwin" ]]; then
            current_mode=$(stat -f '%Lp' "$effective_path" 2>/dev/null || echo "unknown")
        else
            current_mode=$(stat -c '%a' "$effective_path" 2>/dev/null || echo "unknown")
        fi

        expected_mode="${dir_mode#0}"

        if [[ "$current_mode" != "$expected_mode" ]]; then
            log_info "Fixing mode on ${dir_path}: ${current_mode} -> ${dir_mode}"
            chmod "$dir_mode" "$effective_path"
            changes_made=1
        fi
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_made -eq 0 ]]; then
    log_ok "All directories already correct"
else
    log_ok "Directories applied"
fi
