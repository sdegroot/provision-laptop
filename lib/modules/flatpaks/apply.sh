#!/usr/bin/env bash
# flatpaks/apply.sh — Install missing Flatpak applications and apply overrides.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "flatpaks.txt")"
OVERRIDES_FILE="$(state_file_path "flatpak-overrides.conf")"
changes_made=0
has_errors=0

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
        has_errors=1
    fi
done < <(parse_state_file "$STATE_FILE")

# Apply Flatpak overrides
if [[ -f "$OVERRIDES_FILE" ]]; then
    while IFS= read -r line; do
        read -r app_id perm_type perm_value <<< "$line"

        case "$perm_type" in
            filesystem)
                # Check if override is already set
                current="$(flatpak override --user --show "$app_id" 2>/dev/null || true)"
                if ! echo "$current" | grep -Fq "$perm_value"; then
                    log_info "Setting Flatpak override: ${app_id} --filesystem=${perm_value}"
                    flatpak override --user --filesystem="$perm_value" "$app_id"
                    changes_made=1
                fi
                ;;
            env)
                # Flatpak does not expand shell variables in --env values.
                # Expand them here: $HOME → real home, $PATH → default sandbox PATH.
                expanded_value="$perm_value"
                expanded_value="${expanded_value//\$HOME/$HOME}"
                expanded_value="${expanded_value//\$PATH//app/bin:/usr/bin}"

                current="$(flatpak override --user --show "$app_id" 2>/dev/null || true)"
                if ! echo "$current" | grep -Fq "$expanded_value"; then
                    log_info "Setting Flatpak override: ${app_id} --env=${expanded_value}"
                    flatpak override --user --env="$expanded_value" "$app_id"
                    changes_made=1
                fi
                ;;
            *)
                log_warn "Unknown override type: ${perm_type} (for ${app_id})"
                ;;
        esac
    done < <(parse_state_file "$OVERRIDES_FILE")
fi

if [[ $has_errors -ne 0 ]]; then
    log_error "Flatpak apply completed with errors"
    exit 1
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "All Flatpak applications already installed"
else
    log_ok "Flatpak applications applied"
fi
