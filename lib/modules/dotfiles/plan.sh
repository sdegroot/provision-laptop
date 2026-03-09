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

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No dotfile changes needed"
fi
