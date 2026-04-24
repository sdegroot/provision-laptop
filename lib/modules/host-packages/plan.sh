#!/usr/bin/env bash
# host-packages/plan.sh — Show planned Homebrew formulae changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "host-packages.txt")"

if ! has_command brew; then
    log_plan "Would need to install Homebrew first"
    exit 0
fi

changes_planned=0
installed="$(get_brew_formulae)"

while IFS= read -r pkg; do
    if ! echo "$installed" | grep -q "^${pkg}$"; then
        log_plan "Would install formula: ${pkg}"
        changes_planned=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No formula changes needed"
fi
