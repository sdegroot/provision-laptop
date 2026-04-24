#!/usr/bin/env bash
# dotfiles/plan.sh — Show planned dotfile changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

DOTFILES_DIR="${PROVISION_DIR}/dotfiles"
TARGET_HOME="${PROVISION_ROOT}${HOME}"
changes_planned=0

if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_warn "No dotfiles directory found: ${DOTFILES_DIR}"
    exit 0
fi

# Load seed file list
declare -A SEED_FILES=()
SEED_FILE="$(state_file_path "dotfiles-seed.txt")"
if [[ -f "$SEED_FILE" ]]; then
    while IFS= read -r seed_path; do
        SEED_FILES["$seed_path"]=1
    done < <(parse_state_file "$SEED_FILE")
fi

while IFS= read -r src_file; do
    rel_path="${src_file#${DOTFILES_DIR}/}"
    target="${TARGET_HOME}/${rel_path}"

    # Seed files: only act if missing or still a symlink
    if [[ -n "${SEED_FILES[$rel_path]+x}" ]]; then
        if [[ -L "$target" ]]; then
            log_plan "Would replace symlink with seed copy: ${rel_path}"
            changes_planned=1
        elif [[ ! -e "$target" ]]; then
            log_plan "Would seed: ${rel_path}"
            changes_planned=1
        fi
        continue
    fi

    if [[ -L "$target" ]]; then
        link_dest="$(readlink "$target")"
        if [[ "$link_dest" == "$src_file" ]]; then
            continue
        fi
        log_plan "Would fix symlink: ${rel_path}"
        changes_planned=1
    elif [[ -e "$target" ]]; then
        log_plan "Would backup and link: ${rel_path}"
        changes_planned=1
    else
        log_plan "Would create symlink: ${rel_path}"
        changes_planned=1
    fi
done < <(find "$DOTFILES_DIR" -type f | sort)

# Check zsh plugins
ZSH_PLUGINS_FILE="$(state_file_path "zsh-plugins.conf")"
ZSH_PLUGINS_DIR="${TARGET_HOME}/.local/share/zsh-plugins"

if [[ -f "$ZSH_PLUGINS_FILE" ]]; then
    while IFS= read -r line; do
        read -r plugin_name plugin_url <<< "$line"
        plugin_dir="${ZSH_PLUGINS_DIR}/${plugin_name}"

        if [[ ! -d "$plugin_dir/.git" ]]; then
            log_plan "Would install zsh plugin: ${plugin_name}"
            changes_planned=1
        fi
    done < <(parse_state_file "$ZSH_PLUGINS_FILE")
fi

# Check Brave browser profiles
BRAVE_PROFILES_FILE="$(state_file_path "brave-profiles.conf")"
BRAVE_CONFIG_DIR="${TARGET_HOME}/Library/Application Support/BraveSoftware/Brave-Browser"

if [[ -f "$BRAVE_PROFILES_FILE" ]]; then
    while IFS= read -r line; do
        read -r dir_name display_name hex_color <<< "$line"
        [[ -z "$dir_name" ]] && continue

        prefs_file="${BRAVE_CONFIG_DIR}/${dir_name}/Preferences"
        if [[ ! -f "$prefs_file" ]]; then
            log_plan "Would create Brave profile: ${display_name} (${hex_color})"
            changes_planned=1
        elif ! python3 -c "
import json, sys, ctypes
prefs = json.load(open('$prefs_file'))
r, g, b = int('${hex_color}'[1:3], 16), int('${hex_color}'[3:5], 16), int('${hex_color}'[5:7], 16)
color = ctypes.c_int32((255 << 24) | (r << 16) | (g << 8) | b).value
assert prefs.get('profile', {}).get('name') == '$display_name'
assert prefs.get('browser', {}).get('theme', {}).get('user_color2') == color
" 2>/dev/null; then
            log_plan "Would configure Brave profile: ${display_name} (${hex_color})"
            changes_planned=1
        fi
    done < <(parse_state_file "$BRAVE_PROFILES_FILE")
fi

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No dotfile changes needed"
fi
