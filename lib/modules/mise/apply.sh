#!/usr/bin/env bash
# mise/apply.sh — Install and configure mise, create SDK symlinks.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

changes_made=0

# Install mise if not present
if ! has_command mise; then
    log_info "Installing mise..."
    curl https://mise.run | sh
    changes_made=1
fi

# Link global config
MISE_CONFIG_DIR="${PROVISION_ROOT}${HOME}/.config/mise"
MISE_CONFIG="${MISE_CONFIG_DIR}/config.toml"
EXPECTED_CONFIG="${PROVISION_DIR}/mise/mise.toml"

mkdir -p "$MISE_CONFIG_DIR"

if [[ -L "$MISE_CONFIG" ]]; then
    link_dest="$(readlink "$MISE_CONFIG")"
    if [[ "$link_dest" != "$EXPECTED_CONFIG" ]]; then
        log_info "Fixing mise config symlink"
        rm "$MISE_CONFIG"
        ln -s "$EXPECTED_CONFIG" "$MISE_CONFIG"
        changes_made=1
    fi
elif [[ -e "$MISE_CONFIG" ]]; then
    # Back up existing config
    backup="${MISE_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
    log_info "Backing up existing mise config to ${backup}"
    mv "$MISE_CONFIG" "$backup"
    ln -s "$EXPECTED_CONFIG" "$MISE_CONFIG"
    changes_made=1
else
    log_info "Linking mise global config"
    ln -s "$EXPECTED_CONFIG" "$MISE_CONFIG"
    changes_made=1
fi

# Install configured tools
if has_command mise && [[ -z "$PROVISION_ROOT" ]]; then
    log_info "Installing mise tools..."
    mise install --yes 2>&1 || log_warn "Some mise tools may have failed to install"
fi

# -------------------------------------------------------------------------
# Create ~/.jdks/ symlinks for IntelliJ auto-discovery
# -------------------------------------------------------------------------
# IntelliJ scans ~/.jdks/ for JDKs automatically. We create symlinks
# pointing to mise-managed Java installs so IntelliJ finds them
# without manual SDK configuration.

JDKS_DIR="${PROVISION_ROOT}${HOME}/.jdks"
MISE_INSTALLS="${HOME}/.local/share/mise/installs"

if [[ -z "$PROVISION_ROOT" ]] && [[ -d "${MISE_INSTALLS}/java" ]]; then
    mkdir -p "$JDKS_DIR"

    for java_dir in "${MISE_INSTALLS}/java/"*/; do
        [[ -d "$java_dir" ]] || continue
        version="$(basename "$java_dir")"
        link="${JDKS_DIR}/java-${version}"

        if [[ -L "$link" ]]; then
            current_target="$(readlink "$link")"
            if [[ "$current_target" != "$java_dir" ]]; then
                log_info "Fixing JDK symlink: java-${version}"
                rm "$link"
                ln -s "$java_dir" "$link"
                changes_made=1
            fi
        elif [[ ! -e "$link" ]]; then
            log_info "Creating JDK symlink: java-${version} -> ${java_dir}"
            ln -s "$java_dir" "$link"
            changes_made=1
        fi
    done

    # Clean up stale symlinks (JDK versions removed from mise)
    for link in "${JDKS_DIR}"/java-*; do
        [[ -L "$link" ]] || continue
        if [[ ! -e "$link" ]]; then
            log_info "Removing stale JDK symlink: $(basename "$link")"
            rm "$link"
            changes_made=1
        fi
    done
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "Mise already configured"
else
    log_ok "Mise configuration applied"
fi
