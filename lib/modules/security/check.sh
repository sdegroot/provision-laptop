#!/usr/bin/env bash
# security/check.sh — Verify security configuration (macOS).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

drift_found=0

# Check SSH config symlink
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
    ssh_mode=$(stat -f '%Lp' "$SSH_DIR" 2>/dev/null || echo "unknown")
    if [[ "$ssh_mode" != "700" ]]; then
        log_error "SSH directory has wrong permissions: ${ssh_mode} (expected 700)"
        drift_found=1
    else
        log_ok "SSH directory permissions correct"
    fi
fi

# Check default shell
if [[ -z "$PROVISION_ROOT" ]] && has_command zsh; then
    current_shell="$(dscl . -read /Users/$(whoami) UserShell 2>/dev/null | awk '{print $2}')"
    zsh_path="$(command -v zsh)"
    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_ok "Default shell is zsh"
    else
        log_error "Default shell is ${current_shell} (expected ${zsh_path})"
        drift_found=1
    fi
fi

# Check 1Password SSH agent socket
if [[ -z "$PROVISION_ROOT" ]]; then
    OP_AGENT_SOCK="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    if [[ -S "$OP_AGENT_SOCK" ]]; then
        log_ok "1Password SSH agent socket present"
    else
        log_warn "1Password SSH agent socket not found (1Password may not be running)"
    fi
fi

# Check Netbird service
if [[ -z "$PROVISION_ROOT" ]] && has_command netbird; then
    if sudo netbird service status &>/dev/null; then
        log_ok "Netbird service running"
    else
        log_error "Netbird service not running"
        drift_found=1
    fi
fi

if [[ $drift_found -eq 0 ]]; then
    log_ok "Security configuration matches desired state"
fi

exit $drift_found
