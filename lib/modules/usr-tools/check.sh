#!/usr/bin/env bash
# usr-tools/check.sh — Verify user-level tools are installed.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "usr-tools.conf")"
drift_found=0

while IFS= read -r line; do
    name="$(echo "$line" | awk '{print $1}')"
    check_path="$(echo "$line" | awk '{print $2}')"

    check_path="${check_path/#\~/$HOME}"

    if [[ -x "$check_path" ]]; then
        log_ok "${name} installed"
    else
        log_error "${name} not found at ${check_path}"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All user tools present"
fi

exit $drift_found
