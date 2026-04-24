#!/usr/bin/env bash
# casks/plan.sh — Show planned Homebrew cask changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "casks.txt")"

if ! has_command brew; then
    log_plan "Would need to install Homebrew first"
    exit 0
fi

changes_planned=0
installed="$(get_brew_casks)"

while IFS= read -r cask; do
    if ! echo "$installed" | grep -q "^${cask}$"; then
        log_plan "Would install cask: ${cask}"
        changes_planned=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No cask changes needed"
fi
