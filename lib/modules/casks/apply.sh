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

has_errors=0
for cask in "${missing_casks[@]}"; do
    log_info "Installing cask: ${cask}"
    if ! brew install --cask "$cask" 2>&1; then
        # If the app already exists (installed outside Homebrew), adopt it
        if brew install --cask --adopt "$cask" 2>&1; then
            log_info "Adopted existing app: ${cask}"
        else
            log_error "Failed to install cask: ${cask}"
            has_errors=1
        fi
    fi
done

if [[ $has_errors -eq 1 ]]; then
    log_error "Some casks failed to install"
    exit 1
fi
log_ok "Homebrew casks applied"
