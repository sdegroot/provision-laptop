#!/usr/bin/env bash
# mise/check.sh — Verify mise is installed, configured, and JDK symlinks exist.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

drift_found=0

# Check mise is installed
if ! has_command mise; then
    log_error "mise is not installed"
    exit 1
fi

# Check global config is linked
MISE_CONFIG_DIR="${PROVISION_ROOT}${HOME}/.config/mise"
MISE_CONFIG="${MISE_CONFIG_DIR}/config.toml"
EXPECTED_CONFIG="${PROVISION_DIR}/mise/mise.toml"

if [[ -L "$MISE_CONFIG" ]]; then
    link_dest="$(readlink "$MISE_CONFIG")"
    if [[ "$link_dest" != "$EXPECTED_CONFIG" ]]; then
        log_error "Mise config symlink points to wrong target: ${link_dest}"
        drift_found=1
    else
        log_ok "Mise global config linked correctly"
    fi
elif [[ -f "$MISE_CONFIG" ]]; then
    log_error "Mise config exists but is not a symlink to repo"
    drift_found=1
else
    log_error "Mise global config missing: ${MISE_CONFIG}"
    drift_found=1
fi

# -------------------------------------------------------------------------
# Check ~/.jdks/ symlinks for IntelliJ auto-discovery
# -------------------------------------------------------------------------

JDKS_DIR="${PROVISION_ROOT}${HOME}/.jdks"
MISE_INSTALLS="${HOME}/.local/share/mise/installs"

if [[ -z "$PROVISION_ROOT" ]] && [[ -d "${MISE_INSTALLS}/java" ]]; then
    for java_dir in "${MISE_INSTALLS}/java/"*/; do
        [[ -d "$java_dir" ]] || continue
        version="$(basename "$java_dir")"
        link="${JDKS_DIR}/java-${version}"

        if [[ -L "$link" ]]; then
            current_target="$(readlink "$link")"
            if [[ "$current_target" == "$java_dir" ]]; then
                log_ok "JDK symlink: java-${version}"
            else
                log_error "JDK symlink points to wrong target: java-${version}"
                drift_found=1
            fi
        else
            log_error "Missing JDK symlink: java-${version}"
            drift_found=1
        fi
    done
fi

if [[ $drift_found -eq 0 ]]; then
    log_ok "Mise configuration matches desired state"
fi

exit $drift_found
