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

# Deploy browser policies
BROWSER_POLICIES_DIR="$(state_file_path "browser-policies")"
if [[ -z "$PROVISION_ROOT" ]]; then
    # Firefox (Flatpak): deploy policies via systemconfig extension point
    # Maps to /app/etc/firefox/policies/policies.json inside the sandbox
    firefox_src="${BROWSER_POLICIES_DIR}/firefox/policies.json"
    firefox_dest="/var/lib/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable/policies/policies.json"
    if [[ -f "$firefox_src" ]]; then
        if ! diff -q "$firefox_src" "$firefox_dest" &>/dev/null; then
            log_info "Deploying Firefox browser policies via systemconfig extension"
            sudo mkdir -p "$(dirname "$firefox_dest")"
            sudo cp "$firefox_src" "$firefox_dest"
            sudo chmod 644 "$firefox_dest"
            changes_made=1
        fi
    fi

    # 1Password: deploy custom_allowed_browsers (whitelist flatpak-session-helper)
    onepassword_state_dir="$(state_file_path "1password")"
    cab_src="${onepassword_state_dir}/custom_allowed_browsers"
    cab_dest="/etc/1password/custom_allowed_browsers"
    if [[ -f "$cab_src" ]]; then
        if ! diff -q "$cab_src" "$cab_dest" &>/dev/null; then
            log_info "Deploying 1Password custom_allowed_browsers"
            sudo mkdir -p "$(dirname "$cab_dest")"
            sudo cp "$cab_src" "$cab_dest"
            sudo chmod 644 "$cab_dest"
            changes_made=1
        fi
    fi

    # 1Password: deploy native messaging wrapper + manifest for Flatpak Firefox
    wrapper_src="${onepassword_state_dir}/1password-browser-support-wrapper.sh"
    wrapper_dest="${HOME}/.var/app/org.mozilla.firefox/data/bin/1password-browser-support-wrapper.sh"
    if [[ -f "$wrapper_src" ]]; then
        if ! diff -q "$wrapper_src" "$wrapper_dest" &>/dev/null; then
            log_info "Deploying 1Password BrowserSupport wrapper for Flatpak Firefox"
            mkdir -p "$(dirname "$wrapper_dest")"
            cp "$wrapper_src" "$wrapper_dest"
            chmod +x "$wrapper_dest"
            changes_made=1
        fi
    fi

    manifest_src="${onepassword_state_dir}/com.1password.1password.json"
    manifest_dest="${HOME}/.var/app/org.mozilla.firefox/.mozilla/native-messaging-hosts/com.1password.1password.json"
    if [[ -f "$manifest_src" ]]; then
        # Expand $HOME in the manifest
        expanded_manifest="$(sed "s|\$HOME|${HOME}|g" "$manifest_src")"
        if [[ ! -f "$manifest_dest" ]] || [[ "$expanded_manifest" != "$(cat "$manifest_dest")" ]]; then
            log_info "Deploying 1Password native messaging manifest for Flatpak Firefox"
            mkdir -p "$(dirname "$manifest_dest")"
            echo "$expanded_manifest" > "$manifest_dest"
            changes_made=1
        fi
    fi

    # 1Password: deploy native messaging wrapper + manifest for Flatpak Brave
    brave_wrapper_dest="${HOME}/.var/app/com.brave.Browser/data/bin/1password-browser-support-wrapper.sh"
    if [[ -f "$wrapper_src" ]]; then
        if ! diff -q "$wrapper_src" "$brave_wrapper_dest" &>/dev/null; then
            log_info "Deploying 1Password BrowserSupport wrapper for Flatpak Brave"
            mkdir -p "$(dirname "$brave_wrapper_dest")"
            cp "$wrapper_src" "$brave_wrapper_dest"
            chmod +x "$brave_wrapper_dest"
            changes_made=1
        fi
    fi

    brave_manifest_src="${onepassword_state_dir}/com.1password.1password.brave.json"
    brave_manifest_dest="${HOME}/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.1password.1password.json"
    if [[ -f "$brave_manifest_src" ]]; then
        expanded_brave_manifest="$(sed "s|\$HOME|${HOME}|g" "$brave_manifest_src")"
        if [[ ! -f "$brave_manifest_dest" ]] || [[ "$expanded_brave_manifest" != "$(cat "$brave_manifest_dest")" ]]; then
            log_info "Deploying 1Password native messaging manifest for Flatpak Brave"
            mkdir -p "$(dirname "$brave_manifest_dest")"
            echo "$expanded_brave_manifest" > "$brave_manifest_dest"
            changes_made=1
        fi
    fi

    # Clean up manual debugging artifacts from 1Password native messaging setup
    for stale_path in \
        "${HOME}/.local/lib/1Password" \
        "${HOME}/.var/app/org.mozilla.firefox/.mozilla/native-messaging-hosts/1password-browser-support-wrapper.sh"; do
        if [[ -e "$stale_path" ]]; then
            log_info "Removing stale debugging artifact: ${stale_path}"
            rm -rf "$stale_path"
            changes_made=1
        fi
    done

    # Reset Firefox Flatpak overrides so provisioning can re-apply cleanly
    # (removes any manually-added overrides from debugging)
    ff_override_file="${HOME}/.local/share/flatpak/overrides/org.mozilla.firefox"
    if [[ -f "$ff_override_file" ]]; then
        # Check for stale debugging overrides (socket access, local lib)
        if grep -qE '1Password-BrowserSupport\.sock|\.local/lib/1Password' "$ff_override_file" 2>/dev/null; then
            log_info "Resetting Firefox Flatpak overrides (removing stale debugging entries)"
            flatpak override --user --reset org.mozilla.firefox
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

# Configure authselect features (PAM stack)
AUTHSELECT_FILE="$(state_file_path "authselect-features.txt")"
if [[ -z "$PROVISION_ROOT" ]] && [[ -f "$AUTHSELECT_FILE" ]] && has_command authselect; then
    current_features="$(authselect current 2>/dev/null | grep -A100 'Enabled features:' | sed '1d' | sed 's/^- //' || true)"

    while IFS= read -r feature; do
        if ! echo "$current_features" | grep -qx "$feature"; then
            # Skip U2F features if pam_u2f.so is not yet installed (pending reboot)
            if [[ "$feature" == *pam-u2f* ]] && [[ ! -f /usr/lib64/security/pam_u2f.so ]]; then
                log_warn "Skipping ${feature} — pam_u2f.so not yet installed (reboot first)"
                continue
            fi
            log_info "Enabling authselect feature: ${feature}"
            sudo authselect enable-feature "$feature" 2>/dev/null || true
            changes_made=1
        fi
    done < <(parse_state_file "$AUTHSELECT_FILE")

    if [[ $changes_made -eq 1 ]]; then
        sudo authselect apply-changes 2>/dev/null || true
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

# Remind about manual steps (only when not yet completed)
if [[ -z "$PROVISION_ROOT" ]]; then
    reminders=()

    if has_command 1password && [[ ! -S "${HOME}/.1password/agent.sock" ]]; then
        reminders+=("")
        reminders+=("1Password — open Settings → Developer:")
        reminders+=("  - Enable 'Use the SSH agent'")
        reminders+=("  - Enable 'Integrate with 1Password CLI'")
        reminders+=("  - Set SSH agent authorization to 'Allow when unlocked'")
    fi

    if has_command pamu2fcfg && [[ ! -f "${HOME}/.config/Yubico/u2f_keys" ]]; then
        reminders+=("")
        reminders+=("YubiKey — enroll for PAM authentication (sudo/login):")
        reminders+=("  pamu2fcfg > ~/.config/Yubico/u2f_keys")
        reminders+=("  # Touch YubiKey when it blinks")
    fi

    # Check if any LUKS partition has FIDO2 enrolled
    has_luks_fido2=0
    while IFS= read -r luks_dev; do
        if sudo cryptsetup luksDump "$luks_dev" 2>/dev/null | grep -q "fido2"; then
            has_luks_fido2=1
            break
        fi
    done < <(lsblk -nrpo NAME,FSTYPE 2>/dev/null | awk '$2=="crypto_LUKS"{print $1}')

    if [[ $has_luks_fido2 -eq 0 ]] && has_command systemd-cryptenroll; then
        luks_devs="$(lsblk -nrpo NAME,FSTYPE 2>/dev/null | awk '$2=="crypto_LUKS"{print $1}')"
        if [[ -n "$luks_devs" ]]; then
            reminders+=("")
            reminders+=("YubiKey — enroll for LUKS disk unlock:")
            while IFS= read -r dev; do
                reminders+=("  sudo systemd-cryptenroll --fido2-device=auto ${dev}")
            done <<< "$luks_devs"
            reminders+=("  # Enter LUKS passphrase, then touch YubiKey")
        fi
    fi

    if [[ ${#reminders[@]} -gt 0 ]]; then
        log_warn "━━━ Manual setup required ━━━"
        for line in "${reminders[@]}"; do
            log_warn "$line"
        done
        log_warn ""
        log_warn "See docs/1password-setup.md and docs/yubikey-setup.md"
    fi
fi
