#!/usr/bin/env bash
# dock/check.sh — Verify Dock persistent-apps match desired state.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "dock.txt")"

if [[ ! -f "$STATE_FILE" ]]; then
    log_warn "No dock.txt found — skipping"
    exit 0
fi

if ! has_command dockutil; then
    log_error "dockutil is not installed (add it to host-packages.txt)"
    exit 1
fi

# Desired list (from state file)
desired=()
while IFS= read -r line; do
    desired+=("$line")
done < <(parse_state_file "$STATE_FILE")

# Current Dock persistent-app labels in order, via dockutil
current=()
while IFS= read -r label; do
    current+=("$label")
done < <(dockutil --list 2>/dev/null | awk -F'\t' '$3 == "persistentApps" {print $1}')

if [[ "${#desired[@]}" -ne "${#current[@]}" ]]; then
    log_error "Dock has ${#current[@]} items, expected ${#desired[@]}"
    exit 1
fi

drift_found=0
for i in "${!desired[@]}"; do
    if [[ "${desired[$i]}" != "${current[$i]}" ]]; then
        log_error "Position $((i + 1)): expected '${desired[$i]}', got '${current[$i]}'"
        drift_found=1
    fi
done

if [[ $drift_found -eq 0 ]]; then
    log_ok "Dock matches desired state (${#desired[@]} items)"
fi

exit $drift_found
