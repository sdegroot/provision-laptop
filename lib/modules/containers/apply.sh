#!/usr/bin/env bash
# containers/apply.sh — Init Podman machine, install Docker Compose v2, build images on macOS.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "containers.conf")"
DOCKER_COMPOSE_VERSION="2.37.0"
changes_made=0

if ! has_command podman; then
    log_warn "podman command not found — skipping"
    exit 0
fi

# Init Podman machine if none exists
machine_name="$(podman machine list --format '{{.Name}}' 2>/dev/null | head -1)"
if [[ -z "$machine_name" ]]; then
    log_info "Initialising Podman machine..."
    podman machine init
    changes_made=1
fi

# Start Podman machine if not running
machine_running="$(podman machine list --format '{{.Running}}' 2>/dev/null | head -1)"
if [[ "$machine_running" != "true" ]]; then
    log_info "Starting Podman machine..."
    podman machine start
    changes_made=1
fi

# Remove legacy ~/.testcontainers.properties.
# We previously generated this file with docker.host + testcontainers.ryuk.disabled,
# but Testcontainers 2.x no longer reads ryuk.disabled from the properties file
# (only TESTCONTAINERS_RYUK_DISABLED env var). Configuration moved to .zshrc/.bashrc;
# the file is now redundant and could be misleading if left behind.
TESTCONTAINERS_PROPS="${HOME}/.testcontainers.properties"
if [[ -e "$TESTCONTAINERS_PROPS" || -L "$TESTCONTAINERS_PROPS" ]]; then
    log_info "Removing legacy ${TESTCONTAINERS_PROPS} (Testcontainers config moved to shell rc)"
    rm -f "$TESTCONTAINERS_PROPS"
    changes_made=1
fi

# Install Docker Compose v2 standalone plugin.
# podman-compose lacks full Docker Compose v2 compatibility (e.g. --scale).
# Installing the real Docker Compose v2 binary as a CLI plugin takes priority.
COMPOSE_PLUGIN_DIR="${HOME}/.docker/cli-plugins"
COMPOSE_PLUGIN="${COMPOSE_PLUGIN_DIR}/docker-compose"
COMPOSE_ARCH="$(uname -m)"
COMPOSE_URL="https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-darwin-${COMPOSE_ARCH}"

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

# Build container images
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
