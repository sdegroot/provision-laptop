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

# Check 1Password SSH agent socket (only on real system, not in test)
if [[ -z "$PROVISION_ROOT" ]]; then
    OP_AGENT_SOCK="${HOME}/.1password/agent.sock"
    if [[ -S "$OP_AGENT_SOCK" ]]; then
        log_ok "1Password SSH agent socket present"
    else
        log_warn "1Password SSH agent socket not found (1Password may not be running)"
    fi
fi

# Check firewall (Silverblue only)
if [[ -z "$PROVISION_ROOT" ]] && is_silverblue; then
    if has_command firewall-cmd; then
        if firewall-cmd --state &>/dev/null; then
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
