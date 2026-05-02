#!/usr/bin/env bash
# containers/check.sh — Verify Podman machine and container images on macOS.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "containers.conf")"
drift_found=0

if ! has_command podman; then
    log_warn "podman command not found — skipping"
    exit 0
fi

# Check Podman machine exists
machine_name="$(podman machine list --format '{{.Name}}' 2>/dev/null | head -1)"
if [[ -n "$machine_name" ]]; then
    log_ok "Podman machine exists: ${machine_name}"
else
    log_error "No Podman machine found (run 'podman machine init')"
    drift_found=1
fi

# Check Podman machine is running
machine_running="$(podman machine list --format '{{.Running}}' 2>/dev/null | head -1)"
if [[ "$machine_running" == "true" ]]; then
    log_ok "Podman machine is running"
else
    log_error "Podman machine is not running"
    drift_found=1
fi

# Check Docker Compose v2 plugin
COMPOSE_PLUGIN="${HOME}/.docker/cli-plugins/docker-compose"
if [[ -x "$COMPOSE_PLUGIN" ]]; then
    log_ok "Docker Compose v2 plugin installed"
else
    log_error "Docker Compose v2 plugin not installed"
    drift_found=1
fi

# Legacy ~/.testcontainers.properties should be gone — config lives in shell rc now
TESTCONTAINERS_PROPS="${HOME}/.testcontainers.properties"
if [[ -e "$TESTCONTAINERS_PROPS" || -L "$TESTCONTAINERS_PROPS" ]]; then
    log_error "Legacy ~/.testcontainers.properties exists (run apply to remove)"
    drift_found=1
fi

# Check container images
while IFS= read -r line; do
    IFS=':' read -r name build_ctx description <<< "$line"

    image="localhost/${name}:latest"

    if podman image exists "$image" 2>/dev/null; then
        log_ok "Image exists: ${name}"
    else
        log_error "Missing image: ${name}"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All container images match desired state"
fi

exit $drift_found
