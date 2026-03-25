#!/usr/bin/env bash
# dotfiles/check.sh — Verify all dotfiles are symlinked correctly.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

DOTFILES_DIR="${PROVISION_DIR}/dotfiles"
TARGET_HOME="${PROVISION_ROOT}${HOME}"
drift_found=0

if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_warn "No dotfiles directory found: ${DOTFILES_DIR}"
    exit 0
fi

while IFS= read -r src_file; do
    # Get the relative path from dotfiles/
    rel_path="${src_file#${DOTFILES_DIR}/}"
    target="${TARGET_HOME}/${rel_path}"

    if [[ -L "$target" ]]; then
        link_dest="$(readlink "$target")"
        if [[ "$link_dest" == "$src_file" ]]; then
            log_ok "Linked: ${rel_path}"
        else
            log_error "Wrong symlink target for ${rel_path}: ${link_dest} (expected ${src_file})"
            drift_found=1
        fi
    elif [[ -e "$target" ]]; then
        log_error "Not a symlink (regular file exists): ${rel_path}"
        drift_found=1
    else
        log_error "Missing symlink: ${rel_path}"
        drift_found=1
    fi
done < <(find "$DOTFILES_DIR" -type f | sort)

# Check dconf settings
DCONF_FILE="$(state_file_path "dconf-settings.conf")"
if [[ -f "$DCONF_FILE" ]]; then
    while IFS= read -r line; do
        read -r key value <<< "$line"
        current="$(dconf read "$key" 2>/dev/null)"
        if [[ "$current" == "$value" ]]; then
            log_ok "dconf: ${key}"
        else
            log_error "dconf drift: ${key} is '${current}', expected '${value}'"
            drift_found=1
        fi
    done < <(parse_state_file "$DCONF_FILE")
fi

# Check zsh plugins
ZSH_PLUGINS_FILE="$(state_file_path "zsh-plugins.conf")"
ZSH_PLUGINS_DIR="${TARGET_HOME}/.local/share/zsh-plugins"

if [[ -f "$ZSH_PLUGINS_FILE" ]]; then
    while IFS= read -r line; do
        read -r plugin_name plugin_url <<< "$line"
        plugin_dir="${ZSH_PLUGINS_DIR}/${plugin_name}"

        if [[ -d "$plugin_dir/.git" ]]; then
            log_ok "Zsh plugin: ${plugin_name}"
        else
            log_error "Missing zsh plugin: ${plugin_name}"
            drift_found=1
        fi
    done < <(parse_state_file "$ZSH_PLUGINS_FILE")
fi

# Check Brave browser profiles
BRAVE_PROFILES_FILE="$(state_file_path "brave-profiles.conf")"
BRAVE_CONFIG_DIR="${TARGET_HOME}/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"

if [[ -f "$BRAVE_PROFILES_FILE" ]] && [[ -d "$BRAVE_CONFIG_DIR" ]]; then
    while IFS= read -r line; do
        read -r dir_name display_name hex_color <<< "$line"
        [[ -z "$dir_name" ]] && continue

        prefs_file="${BRAVE_CONFIG_DIR}/${dir_name}/Preferences"
        if [[ ! -f "$prefs_file" ]]; then
            log_error "Missing Brave profile: ${display_name}"
            drift_found=1
        elif ! python3 -c "
import json, sys, ctypes
prefs = json.load(open('$prefs_file'))
r, g, b = int('${hex_color}'[1:3], 16), int('${hex_color}'[3:5], 16), int('${hex_color}'[5:7], 16)
color = ctypes.c_int32((255 << 24) | (r << 16) | (g << 8) | b).value
assert prefs.get('profile', {}).get('name') == '$display_name', 'name mismatch'
assert prefs.get('browser', {}).get('theme', {}).get('user_color2') == color, 'color mismatch'
" 2>/dev/null; then
            log_error "Brave profile drift: ${display_name}"
            drift_found=1
        else
            log_ok "Brave profile: ${display_name}"
        fi
    done < <(parse_state_file "$BRAVE_PROFILES_FILE")
fi

if [[ $drift_found -eq 0 ]]; then
    log_ok "All dotfiles match desired state"
fi

exit $drift_found
