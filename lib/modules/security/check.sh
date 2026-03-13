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

# Check browser policies for managed extensions
if [[ -z "$PROVISION_ROOT" ]]; then
    BROWSER_POLICIES_DIR="$(state_file_path "browser-policies")"

    firefox_src="${BROWSER_POLICIES_DIR}/firefox/policies.json"
    firefox_dest="/etc/firefox/policies/policies.json"
    if [[ -f "$firefox_src" ]]; then
        if diff -q "$firefox_src" "$firefox_dest" &>/dev/null; then
            log_ok "Firefox browser policies deployed"
        else
            log_error "Firefox browser policies missing or outdated"
            drift_found=1
        fi
    fi

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
