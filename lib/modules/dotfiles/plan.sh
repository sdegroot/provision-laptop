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

while IFS= read -r src_file; do
    rel_path="${src_file#${DOTFILES_DIR}/}"
    target="${TARGET_HOME}/${rel_path}"

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

# Check dconf settings
DCONF_FILE="$(state_file_path "dconf-settings.conf")"
if [[ -f "$DCONF_FILE" ]]; then
    while IFS= read -r line; do
        read -r key value <<< "$line"
        current="$(dconf read "$key" 2>/dev/null)"
        if [[ "$current" != "$value" ]]; then
            log_plan "Would set dconf: ${key} = ${value}"
            changes_planned=1
        fi
    done < <(parse_state_file "$DCONF_FILE")
fi

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No dotfile changes needed"
fi
