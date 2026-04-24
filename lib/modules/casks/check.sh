#!/usr/bin/env bash
# casks/check.sh — Verify all desired Homebrew casks are installed.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "casks.txt")"
drift_found=0

if ! has_command brew; then
    log_error "Homebrew is not installed"
    exit 1
fi

installed="$(get_brew_casks)"

while IFS= read -r cask; do
    if echo "$installed" | grep -q "^${cask}$"; then
        log_ok "Installed: ${cask}"
    else
        log_error "Missing: ${cask}"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All Homebrew casks match desired state"
fi

exit $drift_found
