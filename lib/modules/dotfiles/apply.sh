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

# Load seed file list (files copied once, then left for the application to manage)
SEED_FILES=""
SEED_FILE="$(state_file_path "dotfiles-seed.txt")"
if [[ -f "$SEED_FILE" ]]; then
    SEED_FILES="$(parse_state_file "$SEED_FILE")"
fi

# is_seed_file <rel_path>
#   Returns 0 if the path is in the seed file list.
is_seed_file() {
    echo "$SEED_FILES" | grep -qxF "$1"
}

while IFS= read -r src_file; do
    rel_path="${src_file#${DOTFILES_DIR}/}"
    target="${TARGET_HOME}/${rel_path}"
    target_dir="$(dirname "$target")"

    # Seed files: copy once if missing (or upgrade from symlink), then leave alone
    if is_seed_file "$rel_path"; then
        if [[ -L "$target" ]]; then
            # Upgrade: replace symlink with a regular copy
            log_info "Seeding (replacing symlink): ${rel_path}"
            rm "$target"
            mkdir -p "$target_dir"
            cp "$src_file" "$target"
            changes_made=1
        elif [[ ! -e "$target" ]]; then
            log_info "Seeding: ${rel_path}"
            mkdir -p "$target_dir"
            cp "$src_file" "$target"
            changes_made=1
        fi
        continue
    fi

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

# Configure Brave browser profiles (names + theme colors)
BRAVE_PROFILES_FILE="$(state_file_path "brave-profiles.conf")"
BRAVE_CONFIG_DIR="${TARGET_HOME}/Library/Application Support/BraveSoftware/Brave-Browser"

if [[ -f "$BRAVE_PROFILES_FILE" ]]; then
    mkdir -p "$BRAVE_CONFIG_DIR"
    while IFS= read -r line; do
        read -r dir_name display_name hex_color <<< "$line"
        [[ -z "$dir_name" ]] && continue

        profile_dir="${BRAVE_CONFIG_DIR}/${dir_name}"
        prefs_file="${profile_dir}/Preferences"

        # Create profile directory and minimal Preferences if missing
        if [[ ! -f "$prefs_file" ]]; then
            mkdir -p "$profile_dir"
            echo '{}' > "$prefs_file"
            log_info "Created Brave profile: ${display_name}"
            changes_made=1
        fi

        # Set name and color via Python (JSON manipulation)
        if python3 - "$prefs_file" "$display_name" "$hex_color" << 'PYTHON'; then
import json, sys, ctypes

prefs_file, display_name, hex_color = sys.argv[1], sys.argv[2], sys.argv[3]
prefs = json.load(open(prefs_file))

r, g, b = int(hex_color[1:3], 16), int(hex_color[3:5], 16), int(hex_color[5:7], 16)
color = ctypes.c_int32((255 << 24) | (r << 16) | (g << 8) | b).value

changed = False
if prefs.get('profile', {}).get('name') != display_name:
    prefs.setdefault('profile', {})['name'] = display_name
    changed = True
if prefs.get('browser', {}).get('theme', {}).get('user_color2') != color:
    prefs.setdefault('browser', {}).setdefault('theme', {})['user_color2'] = color
    prefs['browser']['theme']['color_variant2'] = 1
    prefs.setdefault('extensions', {})['theme'] = {'id': 'user_color_theme_id'}
    changed = True

if changed:
    json.dump(prefs, open(prefs_file, 'w'), indent=2)
    sys.exit(0)
sys.exit(2)  # no changes needed
PYTHON
            log_info "Configured Brave profile: ${display_name} (${hex_color})"
            changes_made=1
        fi
    done < <(parse_state_file "$BRAVE_PROFILES_FILE")

    # Register profiles in Local State
    python3 - "$BRAVE_CONFIG_DIR" "$BRAVE_PROFILES_FILE" << 'PYTHON'
import json, sys

brave_dir, profiles_file = sys.argv[1], sys.argv[2]
ls_path = f"{brave_dir}/Local State"

try:
    state = json.load(open(ls_path))
except (FileNotFoundError, json.JSONDecodeError):
    state = {}

state.setdefault('profile', {}).setdefault('info_cache', {})
cache = state['profile']['info_cache']

# Read desired profiles from state file
desired = []
with open(profiles_file) as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split()
        if len(parts) >= 2:
            desired.append((parts[0], parts[1]))

changed = False
for dir_name, display_name in desired:
    if dir_name not in cache:
        cache[dir_name] = {}
        changed = True
    if cache[dir_name].get('name') != display_name:
        cache[dir_name]['name'] = display_name
        changed = True

if not state['profile'].get('profiles_order'):
    state['profile']['profiles_order'] = [d for d, _ in desired]
    changed = True

if changed:
    json.dump(state, open(ls_path, 'w'), indent=2)
PYTHON
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "All dotfiles already linked"
else
    log_ok "Dotfiles applied"
fi
