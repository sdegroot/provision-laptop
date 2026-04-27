#!/usr/bin/env bash
# dock/plan.sh — Show planned Dock changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "dock.txt")"

if [[ ! -f "$STATE_FILE" ]]; then
    log_plan "No dock.txt — would skip"
    exit 0
fi

if ! has_command dockutil; then
    log_plan "Would need to install dockutil first"
    exit 0
fi

desired=()
while IFS= read -r line; do
    desired+=("$line")
done < <(parse_state_file "$STATE_FILE")

current=()
while IFS= read -r label; do
    current+=("$label")
done < <(/usr/libexec/PlistBuddy -c "Print :persistent-apps" \
    "${HOME}/Library/Preferences/com.apple.dock.plist" 2>/dev/null \
    | awk -F' = ' '/file-label/ {print $2}')

# Diff: anything to change?
same=true
if [[ "${#desired[@]}" -ne "${#current[@]}" ]]; then
    same=false
else
    for i in "${!desired[@]}"; do
        if [[ "${desired[$i]}" != "${current[$i]}" ]]; then
            same=false
            break
        fi
    done
fi

if [[ "$same" == "true" ]]; then
    log_ok "No dock changes needed"
    exit 0
fi

log_plan "Would rebuild Dock to match dock.txt:"
for app in "${desired[@]}"; do
    log_plan "  $app"
done
