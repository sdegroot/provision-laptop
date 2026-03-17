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

# Check browser extensions
if [[ -z "$PROVISION_ROOT" ]]; then
    # Firefox (Flatpak): check policies via systemconfig extension point
    BROWSER_POLICIES_DIR="$(state_file_path "browser-policies")"
    firefox_src="${BROWSER_POLICIES_DIR}/firefox/policies.json"
    firefox_dest="/var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/policies/policies.json"
    if [[ -f "$firefox_src" ]] && ! diff -q "$firefox_src" "$firefox_dest" &>/dev/null; then
        log_plan "Would deploy Firefox browser policies via systemconfig extension"
        changes_planned=1
    fi

    # 1Password: check custom_allowed_browsers
    onepassword_state_dir="$(state_file_path "1password")"
    cab_src="${onepassword_state_dir}/custom_allowed_browsers"
    cab_dest="/etc/1password/custom_allowed_browsers"
    if [[ -f "$cab_src" ]] && ! diff -q "$cab_src" "$cab_dest" &>/dev/null; then
        log_plan "Would deploy 1Password custom_allowed_browsers"
        changes_planned=1
    fi

    # 1Password: check native messaging wrapper
    wrapper_src="${onepassword_state_dir}/1password-browser-support-wrapper.sh"
    wrapper_dest="${HOME}/.var/app/org.mozilla.firefox/data/bin/1password-browser-support-wrapper.sh"
    if [[ -f "$wrapper_src" ]] && ! diff -q "$wrapper_src" "$wrapper_dest" &>/dev/null; then
        log_plan "Would deploy 1Password BrowserSupport wrapper for Flatpak Firefox"
        changes_planned=1
    fi

    # 1Password: check native messaging manifest
    manifest_src="${onepassword_state_dir}/com.1password.1password.json"
    manifest_dest="${HOME}/.var/app/org.mozilla.firefox/.mozilla/native-messaging-hosts/com.1password.1password.json"
    if [[ -f "$manifest_src" ]]; then
        expanded_manifest="$(sed "s|\$HOME|${HOME}|g" "$manifest_src")"
        if [[ ! -f "$manifest_dest" ]] || [[ "$expanded_manifest" != "$(cat "$manifest_dest")" ]]; then
            log_plan "Would deploy 1Password native messaging manifest for Flatpak Firefox"
            changes_planned=1
        fi
    fi

    # 1Password: check Brave native messaging wrapper
    brave_wrapper_dest="${HOME}/.var/app/com.brave.Browser/data/bin/1password-browser-support-wrapper.sh"
    if [[ -f "$wrapper_src" ]] && ! diff -q "$wrapper_src" "$brave_wrapper_dest" &>/dev/null; then
        log_plan "Would deploy 1Password BrowserSupport wrapper for Flatpak Brave"
        changes_planned=1
    fi

    # 1Password: check Brave native messaging manifest
    brave_manifest_src="${onepassword_state_dir}/com.1password.1password.brave.json"
    brave_manifest_dest="${HOME}/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.1password.1password.json"
    if [[ -f "$brave_manifest_src" ]]; then
        expanded_brave_manifest="$(sed "s|\$HOME|${HOME}|g" "$brave_manifest_src")"
        if [[ ! -f "$brave_manifest_dest" ]] || [[ "$expanded_brave_manifest" != "$(cat "$brave_manifest_dest")" ]]; then
            log_plan "Would deploy 1Password native messaging manifest for Flatpak Brave"
            changes_planned=1
        fi
    fi

    # Brave: check browser policies
    BROWSER_POLICIES_DIR="$(state_file_path "browser-policies")"
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
