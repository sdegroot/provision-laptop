#!/usr/bin/env bash
# mise/plan.sh — Show planned mise changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

changes_planned=0

if ! has_command mise; then
    log_plan "Would install mise"
    changes_planned=1
fi

MISE_CONFIG="${PROVISION_ROOT}${HOME}/.config/mise/config.toml"
EXPECTED_CONFIG="${PROVISION_DIR}/mise/mise.toml"

if [[ -L "$MISE_CONFIG" ]]; then
    link_dest="$(readlink "$MISE_CONFIG")"
    if [[ "$link_dest" != "$EXPECTED_CONFIG" ]]; then
        log_plan "Would fix mise config symlink"
        changes_planned=1
    fi
elif [[ -e "$MISE_CONFIG" ]]; then
    log_plan "Would backup and link mise config"
    changes_planned=1
elif [[ ! -e "$MISE_CONFIG" ]]; then
    log_plan "Would create mise config symlink"
    changes_planned=1
fi

# -------------------------------------------------------------------------
# Check ~/.jdks/ symlinks
# -------------------------------------------------------------------------

JDKS_DIR="${PROVISION_ROOT}${HOME}/.jdks"
MISE_INSTALLS="${HOME}/.local/share/mise/installs"

if [[ -z "$PROVISION_ROOT" ]] && [[ -d "${MISE_INSTALLS}/java" ]]; then
    for java_dir in "${MISE_INSTALLS}/java/"*/; do
        [[ -d "$java_dir" ]] || continue
        version="$(basename "$java_dir")"
        link="${JDKS_DIR}/java-${version}"

        if [[ ! -L "$link" ]] || [[ "$(readlink "$link")" != "$java_dir" ]]; then
            log_plan "Would create JDK symlink: java-${version}"
            changes_planned=1
        fi
    done
fi

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No mise changes needed"
fi
