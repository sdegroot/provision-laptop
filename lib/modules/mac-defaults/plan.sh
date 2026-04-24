#!/usr/bin/env bash
# mac-defaults/plan.sh — Show planned macOS defaults changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "mac-defaults.conf")"
changes_planned=0

while IFS= read -r line; do
    read -r domain key dtype value <<< "$line"

    current="$(defaults read "$domain" "$key" 2>/dev/null)" || current=""

    expected="$value"
    if [[ "$dtype" == "-bool" ]]; then
        if [[ "$value" == "true" ]]; then
            expected="1"
        else
            expected="0"
        fi
    fi

    if [[ "$current" != "$expected" ]]; then
        log_plan "Would set: ${domain} ${key} ${dtype} ${value}"
        changes_planned=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No macOS defaults changes needed"
fi
