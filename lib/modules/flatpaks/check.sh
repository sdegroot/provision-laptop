#!/usr/bin/env bash
# flatpaks/check.sh — Verify all desired Flatpak apps are installed and overrides are set.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "flatpaks.txt")"
OVERRIDES_FILE="$(state_file_path "flatpak-overrides.conf")"
drift_found=0

if ! has_command flatpak; then
    log_error "flatpak command not found"
    exit 1
fi

# Get list of installed Flatpak app IDs
installed="$(flatpak list --app --columns=application 2>/dev/null || true)"

while IFS= read -r app_id; do
    if echo "$installed" | grep -q "^${app_id}$"; then
        log_ok "Installed: ${app_id}"
    else
        log_error "Missing: ${app_id}"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

# Check Flatpak overrides
if [[ -f "$OVERRIDES_FILE" ]]; then
    while IFS= read -r line; do
        read -r app_id perm_type perm_value <<< "$line"

        current="$(flatpak override --user --show "$app_id" 2>/dev/null || true)"
        case "$perm_type" in
            filesystem|env)
                if echo "$current" | grep -q "$perm_value"; then
                    log_ok "Override: ${app_id} ${perm_type}=${perm_value}"
                else
                    log_error "Missing override: ${app_id} ${perm_type}=${perm_value}"
                    drift_found=1
                fi
                ;;
        esac
    done < <(parse_state_file "$OVERRIDES_FILE")
fi

if [[ $drift_found -eq 0 ]]; then
    log_ok "All Flatpak applications match desired state"
fi

exit $drift_found
