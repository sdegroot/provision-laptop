#!/usr/bin/env bash
# security/plan.sh — Show planned security changes (macOS, dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

changes_planned=0

# Check SSH directory permissions
SSH_DIR="${PROVISION_ROOT}${HOME}/.ssh"
if [[ -d "$SSH_DIR" ]]; then
    current_mode=$(stat -f '%Lp' "$SSH_DIR" 2>/dev/null || echo "unknown")
    if [[ "$current_mode" != "700" ]]; then
        log_plan "Would fix SSH directory permissions: ${current_mode} -> 700"
        changes_planned=1
    fi
fi

# Check default shell
if [[ -z "$PROVISION_ROOT" ]] && has_command zsh; then
    current_shell="$(dscl . -read /Users/$(whoami) UserShell 2>/dev/null | awk '{print $2}')"
    zsh_path="$(command -v zsh)"
    if [[ "$current_shell" != "$zsh_path" ]]; then
        log_plan "Would set default shell to zsh (currently ${current_shell})"
        changes_planned=1
    fi
fi

# Check Netbird service
if [[ -z "$PROVISION_ROOT" ]] && has_command netbird; then
    if ! sudo netbird service status &>/dev/null; then
        log_plan "Would install and start Netbird service"
        changes_planned=1
    fi
fi

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No security changes needed"
fi
