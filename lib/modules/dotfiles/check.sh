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

if [[ $drift_found -eq 0 ]]; then
    log_ok "All dotfiles match desired state"
fi

exit $drift_found
