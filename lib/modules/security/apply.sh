#!/usr/bin/env bash
# security/apply.sh — Apply security configuration.
#
# Note: Most security config is handled by other modules (dotfiles for
# SSH config, host-packages for tools). This module handles verification
# and any security-specific fixes.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

changes_made=0

# Ensure SSH directory has correct permissions
SSH_DIR="${PROVISION_ROOT}${HOME}/.ssh"
if [[ -d "$SSH_DIR" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        current_mode=$(stat -f '%Lp' "$SSH_DIR" 2>/dev/null || echo "unknown")
    else
        current_mode=$(stat -c '%a' "$SSH_DIR" 2>/dev/null || echo "unknown")
    fi
    if [[ "$current_mode" != "700" ]]; then
        log_info "Fixing SSH directory permissions: ${current_mode} -> 700"
        chmod 700 "$SSH_DIR"
        changes_made=1
    fi
fi

# Set zsh as default shell if available
if [[ -z "$PROVISION_ROOT" ]] && has_command zsh; then
    current_shell="$(getent passwd "$(whoami)" | cut -d: -f7)"
    zsh_path="$(command -v zsh)"
    if [[ "$current_shell" != "$zsh_path" ]]; then
        log_info "Setting default shell to zsh..."
        sudo usermod -s "$zsh_path" "$(whoami)"
        changes_made=1
    fi
fi

# Deploy browser policies for managed extensions (1Password)
BROWSER_POLICIES_DIR="$(state_file_path "browser-policies")"
if [[ -z "$PROVISION_ROOT" ]] && [[ -d "$BROWSER_POLICIES_DIR" ]]; then
    # Firefox: /etc/firefox/policies/policies.json
    firefox_src="${BROWSER_POLICIES_DIR}/firefox/policies.json"
    firefox_dest="/etc/firefox/policies/policies.json"
    if [[ -f "$firefox_src" ]]; then
        if ! diff -q "$firefox_src" "$firefox_dest" &>/dev/null; then
            log_info "Deploying Firefox browser policies"
            sudo mkdir -p /etc/firefox/policies
            sudo cp "$firefox_src" "$firefox_dest"
            changes_made=1
        fi
    fi

    # Brave: /etc/brave/policies/managed/
    brave_src="${BROWSER_POLICIES_DIR}/brave/1password.json"
    brave_dest="/etc/brave/policies/managed/1password.json"
    if [[ -f "$brave_src" ]]; then
        if ! diff -q "$brave_src" "$brave_dest" &>/dev/null; then
            log_info "Deploying Brave browser policies"
            sudo mkdir -p /etc/brave/policies/managed
            sudo cp "$brave_src" "$brave_dest"
            changes_made=1
        fi
    fi
fi

# Ensure firewall is enabled (Silverblue only)
if [[ -z "$PROVISION_ROOT" ]] && is_silverblue; then
    if has_command firewall-cmd; then
        if ! firewall-cmd --state &>/dev/null; then
            log_info "Enabling firewall..."
            systemctl enable --now firewalld
            changes_made=1
        fi
    fi
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "Security configuration already correct"
else
    log_ok "Security configuration applied"
fi
