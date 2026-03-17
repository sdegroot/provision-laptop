#!/usr/bin/env bash
# security/check.sh — Verify security configuration.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

drift_found=0

# Check SSH config
TARGET_SSH_CONFIG="${PROVISION_ROOT}${HOME}/.ssh/config"
EXPECTED_SSH_CONFIG="${PROVISION_DIR}/dotfiles/.ssh/config"

if [[ -L "$TARGET_SSH_CONFIG" ]]; then
    link_dest="$(readlink "$TARGET_SSH_CONFIG")"
    if [[ "$link_dest" != "$EXPECTED_SSH_CONFIG" ]]; then
        log_error "SSH config symlink points to wrong target: ${link_dest}"
        drift_found=1
    else
        log_ok "SSH config linked correctly"
    fi
elif [[ -f "$TARGET_SSH_CONFIG" ]]; then
    log_warn "SSH config exists but is not a symlink (managed by dotfiles module)"
    drift_found=1
else
    log_error "SSH config missing: ${TARGET_SSH_CONFIG}"
    drift_found=1
fi

# Check SSH directory permissions
SSH_DIR="${PROVISION_ROOT}${HOME}/.ssh"
if [[ -d "$SSH_DIR" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        ssh_mode=$(stat -f '%Lp' "$SSH_DIR" 2>/dev/null || echo "unknown")
    else
        ssh_mode=$(stat -c '%a' "$SSH_DIR" 2>/dev/null || echo "unknown")
    fi
    if [[ "$ssh_mode" != "700" ]]; then
        log_error "SSH directory has wrong permissions: ${ssh_mode} (expected 700)"
        drift_found=1
    else
        log_ok "SSH directory permissions correct"
    fi
fi

# Check default shell
if [[ -z "$PROVISION_ROOT" ]] && has_command zsh; then
    current_shell="$(getent passwd "$(whoami)" | cut -d: -f7)"
    zsh_path="$(command -v zsh)"
    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_ok "Default shell is zsh"
    else
        log_error "Default shell is ${current_shell} (expected ${zsh_path})"
        drift_found=1
    fi
fi

# Check 1Password SSH agent socket (only on real system, not in test)
if [[ -z "$PROVISION_ROOT" ]]; then
    OP_AGENT_SOCK="${HOME}/.1password/agent.sock"
    if [[ -S "$OP_AGENT_SOCK" ]]; then
        log_ok "1Password SSH agent socket present"
    else
        log_warn "1Password SSH agent socket not found (1Password may not be running)"
    fi
fi

# Check browser extensions
if [[ -z "$PROVISION_ROOT" ]]; then
    # Firefox (Flatpak): check policies via systemconfig extension point
    BROWSER_POLICIES_DIR="$(state_file_path "browser-policies")"
    firefox_src="${BROWSER_POLICIES_DIR}/firefox/policies.json"
    firefox_dest="/var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/policies/policies.json"
    if [[ -f "$firefox_src" ]]; then
        if diff -q "$firefox_src" "$firefox_dest" &>/dev/null; then
            log_ok "Firefox browser policies deployed via systemconfig"
        else
            log_error "Firefox browser policies missing or outdated"
            drift_found=1
        fi
    fi

    # 1Password: check custom_allowed_browsers
    onepassword_state_dir="$(state_file_path "1password")"
    cab_src="${onepassword_state_dir}/custom_allowed_browsers"
    cab_dest="/etc/1password/custom_allowed_browsers"
    if [[ -f "$cab_src" ]]; then
        if diff -q "$cab_src" "$cab_dest" &>/dev/null; then
            log_ok "1Password custom_allowed_browsers deployed"
        else
            log_error "1Password custom_allowed_browsers missing or outdated"
            drift_found=1
        fi
    fi

    # 1Password: check native messaging wrapper
    wrapper_src="${onepassword_state_dir}/1password-browser-support-wrapper.sh"
    wrapper_dest="${HOME}/.var/app/org.mozilla.firefox/data/bin/1password-browser-support-wrapper.sh"
    if [[ -f "$wrapper_src" ]]; then
        if diff -q "$wrapper_src" "$wrapper_dest" &>/dev/null; then
            log_ok "1Password BrowserSupport wrapper deployed"
        else
            log_error "1Password BrowserSupport wrapper missing or outdated"
            drift_found=1
        fi
    fi

    # 1Password: check native messaging manifest
    manifest_src="${onepassword_state_dir}/com.1password.1password.json"
    manifest_dest="${HOME}/.var/app/org.mozilla.firefox/.mozilla/native-messaging-hosts/com.1password.1password.json"
    if [[ -f "$manifest_src" ]]; then
        expanded_manifest="$(sed "s|\$HOME|${HOME}|g" "$manifest_src")"
        if [[ -f "$manifest_dest" ]] && [[ "$expanded_manifest" == "$(cat "$manifest_dest")" ]]; then
            log_ok "1Password native messaging manifest deployed"
        else
            log_error "1Password native messaging manifest missing or outdated"
            drift_found=1
        fi
    fi

    # Brave: check browser policies
    BROWSER_POLICIES_DIR="$(state_file_path "browser-policies")"
    brave_src="${BROWSER_POLICIES_DIR}/brave/1password.json"
    brave_dest="/etc/brave/policies/managed/1password.json"
    if [[ -f "$brave_src" ]]; then
        if diff -q "$brave_src" "$brave_dest" &>/dev/null; then
            log_ok "Brave browser policies deployed"
        else
            log_error "Brave browser policies missing or outdated"
            drift_found=1
        fi
    fi
fi

# Check authselect features
AUTHSELECT_FILE="$(state_file_path "authselect-features.txt")"
if [[ -z "$PROVISION_ROOT" ]] && [[ -f "$AUTHSELECT_FILE" ]] && has_command authselect; then
    current_features="$(authselect current 2>/dev/null | grep -A100 'Enabled features:' | sed '1d' | sed 's/^- //' || true)"

    while IFS= read -r feature; do
        if echo "$current_features" | grep -qx "$feature"; then
            log_ok "Authselect feature: ${feature}"
        else
            log_error "Missing authselect feature: ${feature}"
            drift_found=1
        fi
    done < <(parse_state_file "$AUTHSELECT_FILE")
fi

# Check YubiKey U2F enrollment
if [[ -z "$PROVISION_ROOT" ]]; then
    if [[ -f "${HOME}/.config/Yubico/u2f_keys" ]]; then
        log_ok "YubiKey U2F enrolled for PAM"
    else
        log_warn "YubiKey U2F not enrolled — run: pamu2fcfg > ~/.config/Yubico/u2f_keys"
    fi
fi

# Check firewall (Silverblue only)
if [[ -z "$PROVISION_ROOT" ]] && is_silverblue; then
    if has_command firewall-cmd; then
        if sudo firewall-cmd --state &>/dev/null; then
            log_ok "Firewall is active"
        else
            log_error "Firewall is not active"
            drift_found=1
        fi
    fi
fi

if [[ $drift_found -eq 0 ]]; then
    log_ok "Security configuration matches desired state"
fi

exit $drift_found
