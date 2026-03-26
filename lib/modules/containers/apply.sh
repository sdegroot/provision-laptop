#!/usr/bin/env bash
# containers/apply.sh — Build container images and install Docker Compose v2 plugin.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "containers.conf")"
DOCKER_COMPOSE_VERSION="2.37.0"
changes_made=0

if ! has_command podman; then
    log_warn "podman command not found — skipping"
    exit 0
fi

# Enable podman socket (Docker-compatible API for Testcontainers, etc.)
if [[ -z "$PROVISION_ROOT" ]]; then
    if ! systemctl --user is-enabled podman.socket &>/dev/null; then
        log_info "Enabling podman.socket (Docker-compatible API)..."
        systemctl --user enable --now podman.socket
        changes_made=1
    fi
fi

# Install Docker Compose v2 standalone plugin.
# podman-docker shims `docker compose` to podman-compose, which lacks full
# Docker Compose v2 compatibility (e.g. --scale). Installing the real
# Docker Compose v2 binary as a CLI plugin takes priority over podman-compose.
if [[ -z "$PROVISION_ROOT" ]]; then
    COMPOSE_PLUGIN_DIR="${HOME}/.docker/cli-plugins"
    COMPOSE_PLUGIN="${COMPOSE_PLUGIN_DIR}/docker-compose"
    COMPOSE_ARCH="$(uname -m)"
    # Docker releases use x86_64 and aarch64
    COMPOSE_URL="https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}"

    install_compose=0
    if [[ ! -x "$COMPOSE_PLUGIN" ]]; then
        install_compose=1
    elif ! "${COMPOSE_PLUGIN}" version 2>/dev/null | grep -q "${DOCKER_COMPOSE_VERSION}"; then
        install_compose=1
    fi

    if [[ $install_compose -eq 1 ]]; then
        log_info "Installing Docker Compose v${DOCKER_COMPOSE_VERSION} plugin..."
        mkdir -p "$COMPOSE_PLUGIN_DIR"
        if curl -fsSL "$COMPOSE_URL" -o "$COMPOSE_PLUGIN" && chmod +x "$COMPOSE_PLUGIN"; then
            log_ok "Docker Compose v${DOCKER_COMPOSE_VERSION} installed"
            changes_made=1
        else
            log_error "Failed to download Docker Compose v${DOCKER_COMPOSE_VERSION}"
        fi
    fi
fi

while IFS= read -r line; do
    IFS=':' read -r name build_ctx description <<< "$line"

    image="localhost/${name}:latest"
    build_dir="${PROVISION_DIR}/${build_ctx}"

    if podman image exists "$image" 2>/dev/null; then
        continue
    fi

    if [[ ! -d "$build_dir" ]]; then
        log_error "Build context not found: ${build_dir}"
        continue
    fi

    log_info "Building container image: ${name} (${description})"
    if podman build -t "$image" "$build_dir"; then
        log_ok "Built: ${name}"
        changes_made=1
    else
        log_error "Failed to build: ${name}"
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_made -eq 0 ]]; then
    log_ok "All container images already built"
else
    log_ok "Container images applied"
fi
