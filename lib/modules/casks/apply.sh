#!/usr/bin/env bash
# casks/apply.sh — Install missing Homebrew casks.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "casks.txt")"

if ! has_command brew; then
    log_error "Homebrew is not installed"
    exit 1
fi

missing_casks=()
installed="$(get_brew_casks)"

while IFS= read -r cask; do
    if ! echo "$installed" | grep -q "^${cask}$"; then
        missing_casks+=("$cask")
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ ${#missing_casks[@]} -eq 0 ]]; then
    log_ok "All Homebrew casks already installed"
    exit 0
fi

log_info "Installing ${#missing_casks[@]} casks: ${missing_casks[*]}"
for cask in "${missing_casks[@]}"; do
    if ! brew install --cask "$cask"; then
        log_error "Failed to install cask: ${cask}"
        exit 1
    fi
done
log_ok "Homebrew casks applied"
