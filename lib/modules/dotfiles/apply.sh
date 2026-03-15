#!/usr/bin/env bash
# dotfiles/apply.sh — Symlink dotfiles into $HOME.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

DOTFILES_DIR="${PROVISION_DIR}/dotfiles"
TARGET_HOME="${PROVISION_ROOT}${HOME}"
BACKUP_DIR="${TARGET_HOME}/.dotfiles-backup"
changes_made=0

if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_warn "No dotfiles directory found: ${DOTFILES_DIR}"
    exit 0
fi

while IFS= read -r src_file; do
    rel_path="${src_file#${DOTFILES_DIR}/}"
    target="${TARGET_HOME}/${rel_path}"
    target_dir="$(dirname "$target")"

    # Skip if already correctly symlinked
    if [[ -L "$target" ]]; then
        link_dest="$(readlink "$target")"
        if [[ "$link_dest" == "$src_file" ]]; then
            continue
        fi
        # Wrong symlink — remove and recreate
        log_info "Fixing symlink: ${rel_path}"
        rm "$target"
    elif [[ -e "$target" ]]; then
        # Back up existing file
        backup_path="${BACKUP_DIR}/${rel_path}"
        backup_parent="$(dirname "$backup_path")"
        mkdir -p "$backup_parent"
        log_info "Backing up existing file: ${rel_path} -> ${backup_path}"
        mv "$target" "$backup_path"
    fi

    # Ensure parent directory exists
    mkdir -p "$target_dir"

    # Create symlink
    log_info "Linking: ${rel_path} -> ${src_file}"
    ln -s "$src_file" "$target"
    changes_made=1
done < <(find "$DOTFILES_DIR" -type f | sort)

# Apply dconf settings
DCONF_FILE="$(state_file_path "dconf-settings.conf")"
if [[ -f "$DCONF_FILE" ]]; then
    while IFS= read -r line; do
        read -r key value <<< "$line"
        current="$(dconf read "$key" 2>/dev/null)"
        if [[ "$current" != "$value" ]]; then
            log_info "Setting dconf: ${key} = ${value}"
            dconf write "$key" "$value"
            changes_made=1
        fi
    done < <(parse_state_file "$DCONF_FILE")
fi

# Install zsh plugins via git clone
ZSH_PLUGINS_FILE="$(state_file_path "zsh-plugins.conf")"
ZSH_PLUGINS_DIR="${TARGET_HOME}/.local/share/zsh-plugins"

if [[ -f "$ZSH_PLUGINS_FILE" ]]; then
    mkdir -p "$ZSH_PLUGINS_DIR"

    while IFS= read -r line; do
        read -r plugin_name plugin_url <<< "$line"
        plugin_dir="${ZSH_PLUGINS_DIR}/${plugin_name}"

        if [[ -d "$plugin_dir/.git" ]]; then
            # Pull latest changes
            if git -C "$plugin_dir" pull --quiet 2>/dev/null; then
                :
            else
                log_warn "Failed to update zsh plugin: ${plugin_name}"
            fi
        else
            log_info "Installing zsh plugin: ${plugin_name}"
            if git clone --quiet "$plugin_url" "$plugin_dir" 2>/dev/null; then
                changes_made=1
            else
                log_error "Failed to clone zsh plugin: ${plugin_name}"
            fi
        fi
    done < <(parse_state_file "$ZSH_PLUGINS_FILE")
fi

# Enable systemd user timers
if [[ -z "${PROVISION_ROOT:-}" ]] && has_command systemctl; then
    for timer in "${DOTFILES_DIR}/.config/systemd/user/"*.timer; do
        [[ -f "$timer" ]] || continue
        systemctl --user daemon-reload 2>/dev/null || true
        timer_name="$(basename "$timer")"
        if ! systemctl --user is-enabled --quiet "$timer_name" 2>/dev/null; then
            log_info "Enabling user timer: ${timer_name}"
            systemctl --user enable --now "$timer_name"
            changes_made=1
        fi
    done
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "All dotfiles already linked"
else
    log_ok "Dotfiles applied"
fi
