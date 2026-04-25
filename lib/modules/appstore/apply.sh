#!/usr/bin/env bash
# appstore/apply.sh — Install missing Mac App Store apps.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "appstore.txt")"

if ! has_command mas; then
    log_warn "mas not installed — skipping App Store install"
    exit 0
fi

installed="$(mas list 2>/dev/null | awk '{print $1}')"
has_errors=0
changes_made=0

while IFS= read -r line; do
    read -r app_id app_name <<< "$line"

    if echo "$installed" | grep -q "^${app_id}$"; then
        continue
    fi

    log_info "Installing from App Store: ${app_name} (${app_id})"
    if mas install "$app_id"; then
        changes_made=1
    else
        log_error "Failed to install: ${app_name} (${app_id}) — you may need to install it from the App Store first"
        has_errors=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $has_errors -eq 1 ]]; then
    log_error "Some App Store apps failed to install"
    exit 1
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "All App Store apps already installed"
else
    log_ok "App Store apps applied"
fi
