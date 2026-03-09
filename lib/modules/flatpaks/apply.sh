#!/usr/bin/env bash
# flatpaks/apply.sh — Install missing Flatpak applications.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "flatpaks.txt")"
changes_made=0

if ! has_command flatpak; then
    log_error "flatpak command not found"
    exit 1
fi

# Ensure Flathub remote is configured
if ! flatpak remote-list --columns=name 2>/dev/null | grep -q "^flathub$"; then
    log_info "Adding Flathub remote..."
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

installed="$(flatpak list --app --columns=application 2>/dev/null || true)"

while IFS= read -r app_id; do
    if echo "$installed" | grep -q "^${app_id}$"; then
        continue
    fi

    log_info "Installing Flatpak: ${app_id}"
    if sudo flatpak install -y --noninteractive flathub "$app_id"; then
        log_ok "Installed: ${app_id}"
        changes_made=1
    else
        log_error "Failed to install: ${app_id}"
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_made -eq 0 ]]; then
    log_ok "All Flatpak applications already installed"
else
    log_ok "Flatpak applications applied"
fi
