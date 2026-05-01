#!/usr/bin/env bash
# hostname/check.sh — Verify macOS hostname matches desired state.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "hostname.txt")"

desired="$(parse_state_file "$STATE_FILE" | head -n1)"
if [[ -z "$desired" ]]; then
    log_error "No hostname configured in ${STATE_FILE}"
    exit 1
fi

drift_found=0

check_name() {
    local key="$1" current
    current="$(scutil --get "$key" 2>/dev/null || true)"
    if [[ "$current" == "$desired" ]]; then
        log_ok "${key} = ${desired}"
    else
        log_error "Drift: ${key} = '${current}' (expected: '${desired}')"
        drift_found=1
    fi
}

check_name ComputerName
check_name HostName
check_name LocalHostName

exit $drift_found
