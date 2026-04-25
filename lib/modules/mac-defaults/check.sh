#!/usr/bin/env bash
# mac-defaults/check.sh — Verify macOS defaults match desired state.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "mac-defaults.conf")"
drift_found=0

while IFS= read -r line; do
    # Parse: domain key type value
    read -r domain key dtype value <<< "$line"

    # Read current value
    current="$(defaults read "$domain" "$key" 2>/dev/null)" || {
        log_error "Not set: ${domain} ${key} (expected: ${value})"
        drift_found=1
        continue
    }

    # Normalize boolean comparisons (defaults read prints 0/1)
    expected="$value"
    if [[ "$dtype" == "-bool" ]]; then
        if [[ "$value" == "true" ]]; then
            expected="1"
        else
            expected="0"
        fi
    fi

    if [[ "$current" == "$expected" ]]; then
        log_ok "Match: ${domain} ${key} = ${value}"
    else
        log_error "Drift: ${domain} ${key} = ${current} (expected: ${value})"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

# Check default browser
if has_command defaultbrowser; then
    current_browser="$(defaultbrowser 2>/dev/null | grep '^\*' | awk '{print $2}')"
    if [[ "$current_browser" == "chowser" ]]; then
        log_ok "Default browser: chowser"
    else
        log_error "Default browser is ${current_browser} (expected chowser)"
        drift_found=1
    fi
fi

if [[ $drift_found -eq 0 ]]; then
    log_ok "All macOS defaults match desired state"
fi

exit $drift_found
