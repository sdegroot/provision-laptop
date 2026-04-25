#!/usr/bin/env bash
# mac-defaults/apply.sh — Apply macOS defaults.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "mac-defaults.conf")"
changes_made=0

while IFS= read -r line; do
    read -r domain key dtype value <<< "$line"

    # Read current value
    current="$(defaults read "$domain" "$key" 2>/dev/null)" || current=""

    # Normalize boolean comparisons
    expected="$value"
    if [[ "$dtype" == "-bool" ]]; then
        if [[ "$value" == "true" ]]; then
            expected="1"
        else
            expected="0"
        fi
    fi

    if [[ "$current" != "$expected" ]]; then
        log_info "Setting: ${domain} ${key} ${dtype} ${value}"
        defaults write "$domain" "$key" "$dtype" "$value"
        changes_made=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_made -eq 1 ]]; then
    log_info "Restarting Dock and Finder to apply changes..."
    killall Dock 2>/dev/null || true
    killall Finder 2>/dev/null || true
fi

# Set default browser to Chowser (browser picker)
if has_command defaultbrowser; then
    current_browser="$(defaultbrowser 2>/dev/null | grep '^\*' | awk '{print $2}')"
    if [[ "$current_browser" != "chowser" ]]; then
        log_info "Setting default browser to Chowser..."
        osascript - <<'APPLESCRIPT' &>/dev/null &
            delay 1
            tell application "System Events"
                try
                    click button 2 of window 1 of application process "CoreServicesUIAgent"
                end try
            end tell
APPLESCRIPT
        defaultbrowser chowser
        wait
        changes_made=1
    fi
fi

if [[ $changes_made -eq 1 ]]; then
    log_ok "macOS defaults applied"
else
    log_ok "All macOS defaults already match desired state"
fi
