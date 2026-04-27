#!/usr/bin/env bash
# dock/apply.sh — Make the Dock match dock.txt (replaces persistent-apps).

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

# Idempotency check
if [[ "${#desired[@]}" -eq "${#current[@]}" ]]; then
    same=true
    for i in "${!desired[@]}"; do
        if [[ "${desired[$i]}" != "${current[$i]}" ]]; then
            same=false
            break
        fi
    done
    if [[ "$same" == "true" ]]; then
        log_ok "Dock already matches desired state"
        exit 0
    fi
fi

log_info "Rebuilding Dock (${#desired[@]} items)"
dockutil --remove all --no-restart >/dev/null

has_errors=0
for app in "${desired[@]}"; do
    # Resolve plain names to /Applications/<name>.app when possible
    if [[ "$app" != /* ]] && [[ -d "/Applications/${app}.app" ]]; then
        target="/Applications/${app}.app"
    else
        target="$app"
    fi

    if dockutil --add "$target" --no-restart >/dev/null 2>&1; then
        log_info "  Added: ${app}"
    else
        log_error "  Failed to add: ${app}"
        has_errors=1
    fi
done

killall Dock 2>/dev/null || true

if [[ $has_errors -ne 0 ]]; then
    log_error "Some Dock entries failed — see above"
    exit 1
fi

log_ok "Dock applied"
