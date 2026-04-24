#!/usr/bin/env bash
# taps/plan.sh — Show planned Homebrew tap changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "taps.txt")"

if ! has_command brew; then
    log_plan "Would need to install Homebrew first"
    exit 0
fi

tapped="$(brew tap)"
changes_planned=0

while IFS= read -r tap; do
    if ! echo "$tapped" | grep -q "^${tap}$"; then
        log_plan "Would add tap: ${tap}"
        changes_planned=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No tap changes needed"
fi
