#!/usr/bin/env bash
# host-packages/apply.sh — Install missing Homebrew formulae.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "host-packages.txt")"

if ! has_command brew; then
    log_error "Homebrew is not installed"
    exit 1
fi

missing_pkgs=()
installed="$(get_brew_formulae)"

while IFS= read -r pkg; do
    if ! echo "$installed" | grep -q "^${pkg}$"; then
        missing_pkgs+=("$pkg")
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
    log_ok "All Homebrew formulae already installed"
    exit 0
fi

has_errors=0
for pkg in "${missing_pkgs[@]}"; do
    log_info "Installing formula: ${pkg}"
    if ! brew install "$pkg"; then
        log_error "Failed to install: ${pkg}"
        has_errors=1
    fi
done

if [[ $has_errors -eq 1 ]]; then
    log_error "Some formulae failed to install"
    exit 1
fi
log_ok "Homebrew formulae applied"
