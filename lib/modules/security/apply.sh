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
