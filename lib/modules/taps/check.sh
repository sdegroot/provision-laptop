#!/usr/bin/env bash
# taps/check.sh — Verify all desired Homebrew taps are configured.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "taps.txt")"
drift_found=0

if ! has_command brew; then
    log_error "Homebrew is not installed"
    exit 1
fi

tapped="$(brew tap)"

while IFS= read -r tap; do
    if echo "$tapped" | grep -q "^${tap}$"; then
        log_ok "Tapped: ${tap}"
    else
        log_error "Missing tap: ${tap}"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All Homebrew taps match desired state"
fi

exit $drift_found
