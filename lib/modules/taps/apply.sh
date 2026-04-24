#!/usr/bin/env bash
# taps/apply.sh — Add missing Homebrew taps.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "taps.txt")"

if ! has_command brew; then
    log_error "Homebrew is not installed"
    exit 1
fi

tapped="$(brew tap)"
missing=()

while IFS= read -r tap; do
    if ! echo "$tapped" | grep -q "^${tap}$"; then
        missing+=("$tap")
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ ${#missing[@]} -eq 0 ]]; then
    log_ok "All Homebrew taps already configured"
    exit 0
fi

for tap in "${missing[@]}"; do
    log_info "Adding tap: ${tap}"
    if ! brew tap "$tap"; then
        log_error "Failed to add tap: ${tap}"
        exit 1
    fi
done

log_ok "All taps applied"
