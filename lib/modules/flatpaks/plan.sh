#!/usr/bin/env bash
# flatpaks/plan.sh — Show planned Flatpak changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "flatpaks.txt")"
OVERRIDES_FILE="$(state_file_path "flatpak-overrides.conf")"
changes_planned=0

if ! has_command flatpak; then
    log_plan "Would need to install flatpak first"
    exit 0
fi

installed="$(flatpak list --app --columns=application 2>/dev/null || true)"

while IFS= read -r app_id; do
    if echo "$installed" | grep -q "^${app_id}$"; then
        continue
    fi

    log_plan "Would install Flatpak: ${app_id}"
    changes_planned=1
done < <(parse_state_file "$STATE_FILE")

# Check Flatpak overrides
if [[ -f "$OVERRIDES_FILE" ]]; then
    while IFS= read -r line; do
        read -r app_id perm_type perm_value <<< "$line"

        current="$(flatpak override --user --show "$app_id" 2>/dev/null || true)"
        case "$perm_type" in
            filesystem|env)
                if ! echo "$current" | grep -Fq "$perm_value"; then
                    log_plan "Would set override: ${app_id} ${perm_type}=${perm_value}"
                    changes_planned=1
                fi
                ;;
        esac
    done < <(parse_state_file "$OVERRIDES_FILE")
fi

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No Flatpak changes needed"
fi
