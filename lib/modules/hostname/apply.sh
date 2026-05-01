#!/usr/bin/env bash
# hostname/apply.sh — Set the macOS hostname (ComputerName, HostName, LocalHostName).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "hostname.txt")"

desired="$(parse_state_file "$STATE_FILE" | head -n1)"
if [[ -z "$desired" ]]; then
    log_error "No hostname configured in ${STATE_FILE}"
    exit 1
fi

changes_made=0

set_name() {
    local key="$1" current
    current="$(scutil --get "$key" 2>/dev/null || true)"
    if [[ "$current" != "$desired" ]]; then
        log_info "Setting ${key}: '${current}' -> '${desired}'"
        if [[ -z "$PROVISION_ROOT" ]]; then
            sudo scutil --set "$key" "$desired"
        fi
        changes_made=1
    fi
}

set_name ComputerName
set_name HostName
set_name LocalHostName

if [[ $changes_made -eq 1 ]]; then
    log_ok "Hostname set to ${desired}"
else
    log_ok "Hostname already set to ${desired}"
fi
