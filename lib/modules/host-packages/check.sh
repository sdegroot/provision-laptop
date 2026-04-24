#!/usr/bin/env bash
# host-packages/check.sh — Verify all desired Homebrew formulae are installed.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "host-packages.txt")"
drift_found=0

if ! has_command brew; then
    log_error "Homebrew is not installed"
    exit 1
fi

installed="$(get_brew_formulae)"

while IFS= read -r pkg; do
    if echo "$installed" | grep -q "^${pkg}$"; then
        log_ok "Installed: ${pkg}"
    else
        log_error "Missing: ${pkg}"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All Homebrew formulae match desired state"
fi

exit $drift_found
