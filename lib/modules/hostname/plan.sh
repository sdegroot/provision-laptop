#!/usr/bin/env bash
# hostname/plan.sh — Show planned hostname changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "hostname.txt")"

desired="$(parse_state_file "$STATE_FILE" | head -n1)"
if [[ -z "$desired" ]]; then
    log_error "No hostname configured in ${STATE_FILE}"
    exit 1
fi

changes_planned=0

plan_name() {
    local key="$1" current
    current="$(scutil --get "$key" 2>/dev/null || true)"
    if [[ "$current" != "$desired" ]]; then
        log_plan "Would set ${key}: '${current}' -> '${desired}'"
        changes_planned=1
    fi
}

plan_name ComputerName
plan_name HostName
plan_name LocalHostName

if [[ $changes_planned -eq 0 ]]; then
    log_ok "Hostname already set to ${desired}"
fi
