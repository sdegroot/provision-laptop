#!/usr/bin/env bash
# security/plan.sh — Show planned security changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

changes_planned=0

# Check SSH directory permissions
SSH_DIR="${PROVISION_ROOT}${HOME}/.ssh"
if [[ -d "$SSH_DIR" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        current_mode=$(stat -f '%Lp' "$SSH_DIR" 2>/dev/null || echo "unknown")
    else
        current_mode=$(stat -c '%a' "$SSH_DIR" 2>/dev/null || echo "unknown")
    fi
    if [[ "$current_mode" != "700" ]]; then
        log_plan "Would fix SSH directory permissions: ${current_mode} -> 700"
        changes_planned=1
    fi
fi

# Check default shell
if [[ -z "$PROVISION_ROOT" ]] && has_command zsh; then
    current_shell="$(getent passwd "$(whoami)" | cut -d: -f7)"
    zsh_path="$(command -v zsh)"
    if [[ "$current_shell" != "$zsh_path" ]]; then
        log_plan "Would set default shell to zsh (currently ${current_shell})"
        changes_planned=1
    fi
fi

# Check browser policies
if [[ -z "$PROVISION_ROOT" ]]; then
    BROWSER_POLICIES_DIR="$(state_file_path "browser-policies")"

    firefox_src="${BROWSER_POLICIES_DIR}/firefox/policies.json"
    firefox_dest="/etc/firefox/policies/policies.json"
    if [[ -f "$firefox_src" ]] && ! diff -q "$firefox_src" "$firefox_dest" &>/dev/null; then
        log_plan "Would deploy Firefox browser policies (1Password extension)"
        changes_planned=1
    fi

    brave_src="${BROWSER_POLICIES_DIR}/brave/1password.json"
    brave_dest="/etc/brave/policies/managed/1password.json"
    if [[ -f "$brave_src" ]] && ! diff -q "$brave_src" "$brave_dest" &>/dev/null; then
        log_plan "Would deploy Brave browser policies (1Password extension)"
        changes_planned=1
    fi
fi

# Check authselect features
AUTHSELECT_FILE="$(state_file_path "authselect-features.txt")"
if [[ -z "$PROVISION_ROOT" ]] && [[ -f "$AUTHSELECT_FILE" ]] && has_command authselect; then
    current_features="$(authselect current 2>/dev/null | grep -A100 'Enabled features:' | sed '1d' | sed 's/^- //' || true)"

    while IFS= read -r feature; do
        if ! echo "$current_features" | grep -qx "$feature"; then
            log_plan "Would enable authselect feature: ${feature}"
            changes_planned=1
        fi
    done < <(parse_state_file "$AUTHSELECT_FILE")
fi

# Check firewall
if [[ -z "$PROVISION_ROOT" ]] && is_silverblue; then
    if has_command firewall-cmd; then
        if ! firewall-cmd --state &>/dev/null; then
            log_plan "Would enable firewall"
            changes_planned=1
        fi
    fi
fi

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No security changes needed"
fi
