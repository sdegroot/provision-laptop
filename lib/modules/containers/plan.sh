#!/usr/bin/env bash
# containers/plan.sh — Show planned container changes on macOS (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "containers.conf")"
changes_planned=0

if ! has_command podman; then
    log_plan "Would need podman (not available)"
    exit 0
fi

# Check Podman machine exists
machine_name="$(podman machine list --format '{{.Name}}' 2>/dev/null | head -1)"
if [[ -z "$machine_name" ]]; then
    log_plan "Would initialise Podman machine (podman machine init)"
    changes_planned=1
fi

# Check Podman machine is running
machine_running="$(podman machine list --format '{{.Running}}' 2>/dev/null | head -1)"
if [[ "$machine_running" != "true" ]]; then
    log_plan "Would start Podman machine (podman machine start)"
    changes_planned=1
fi

# Check Docker Compose v2 plugin
COMPOSE_PLUGIN="${HOME}/.docker/cli-plugins/docker-compose"
if [[ ! -x "$COMPOSE_PLUGIN" ]]; then
    log_plan "Would install Docker Compose v2 plugin"
    changes_planned=1
fi

# Legacy ~/.testcontainers.properties cleanup
TESTCONTAINERS_PROPS="${HOME}/.testcontainers.properties"
if [[ -e "$TESTCONTAINERS_PROPS" || -L "$TESTCONTAINERS_PROPS" ]]; then
    log_plan "Would remove legacy ~/.testcontainers.properties"
    changes_planned=1
fi

# Check container images
while IFS= read -r line; do
    IFS=':' read -r name build_ctx description <<< "$line"

    image="localhost/${name}:latest"

    if podman image exists "$image" 2>/dev/null; then
        continue
    fi

    log_plan "Would build container image: ${name} (${description})"
    changes_planned=1
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No container changes needed"
fi
