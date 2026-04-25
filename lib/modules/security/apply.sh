#!/usr/bin/env bash
# security/apply.sh — Apply security configuration (macOS).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

changes_made=0

# Ensure SSH directory has correct permissions
SSH_DIR="${PROVISION_ROOT}${HOME}/.ssh"
if [[ -d "$SSH_DIR" ]]; then
    current_mode=$(stat -f '%Lp' "$SSH_DIR" 2>/dev/null || echo "unknown")
    if [[ "$current_mode" != "700" ]]; then
        log_info "Fixing SSH directory permissions: ${current_mode} -> 700"
        chmod 700 "$SSH_DIR"
        changes_made=1
    fi
fi

# Set zsh as default shell if available
if [[ -z "$PROVISION_ROOT" ]] && has_command zsh; then
    current_shell="$(dscl . -read /Users/$(whoami) UserShell 2>/dev/null | awk '{print $2}')"
    zsh_path="$(command -v zsh)"
    if [[ "$current_shell" != "$zsh_path" ]]; then
        log_info "Setting default shell to zsh..."
        chsh -s "$zsh_path"
        changes_made=1
    fi
fi

# Deploy 1Password custom_allowed_browsers
if [[ -z "$PROVISION_ROOT" ]]; then
    onepassword_state_dir="$(state_file_path "1password")"
    cab_src="${onepassword_state_dir}/custom_allowed_browsers"
    cab_dest="/Library/Application Support/1Password/custom_allowed_browsers"
    if [[ -f "$cab_src" ]]; then
        if ! diff -q "$cab_src" "$cab_dest" &>/dev/null; then
            log_info "Deploying 1Password custom_allowed_browsers"
            sudo mkdir -p "$(dirname "$cab_dest")"
            sudo cp "$cab_src" "$cab_dest"
            sudo chmod 644 "$cab_dest"
            changes_made=1
        fi
    fi
fi

# Install and start Netbird service
if [[ -z "$PROVISION_ROOT" ]] && has_command netbird; then
    if ! sudo netbird service status &>/dev/null; then
        log_info "Installing and starting Netbird service..."
        sudo netbird service install 2>/dev/null || true
        sudo netbird service start
        changes_made=1
    fi
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "Security configuration already correct"
else
    log_ok "Security configuration applied"
fi

# Remind about manual steps (only when not yet completed)
if [[ -z "$PROVISION_ROOT" ]]; then
    reminders=()

    if [[ ! -S "${HOME}/.1password/agent.sock" ]]; then
        reminders+=("")
        reminders+=("1Password SSH agent is not running. To set up:")
        reminders+=("  1. Open 1Password and sign in")
        reminders+=("  2. Go to Settings > Developer")
        reminders+=("  3. Enable 'Use the SSH agent'")
        reminders+=("  4. Enable 'Integrate with 1Password CLI'")
        reminders+=("  5. Set SSH agent authorization to 'Allow when unlocked'")
        reminders+=("  6. Re-run: bin/apply")
        reminders+=("")
        reminders+=("  Without this, git-projects module will be skipped.")
    fi

    # Check if Chowser needs browser setup
    if [[ -e "${HOME}/Applications/Chowser.app" ]] || [[ -e "/Applications/Chowser.app" ]]; then
        browser_count="$(defaults read in.sreerams.Chowser configuredBrowsers 2>/dev/null | grep -c bundleId || echo 0)"
        if [[ "$browser_count" -lt 2 ]]; then
            reminders+=("")
            reminders+=("Chowser — add your browsers:")
            reminders+=("  1. Click the Chowser menu bar icon")
            reminders+=("  2. Open Settings > Browsers")
            reminders+=("  3. Click 'Add Browser' for Brave, Firefox, etc.")
        fi
    fi

    if [[ ${#reminders[@]} -gt 0 ]]; then
        log_warn "--- Manual setup required ---"
        for line in "${reminders[@]}"; do
            log_warn "$line"
        done
    fi
fi
