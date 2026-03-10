#!/usr/bin/env bash
# containers/plan.sh — Show planned container changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "containers.conf")"
changes_planned=0

if ! has_command podman; then
    log_plan "Would need podman (not available)"
    exit 0
fi

# Check podman socket
if [[ -z "$PROVISION_ROOT" ]]; then
    if ! systemctl --user is-enabled podman.socket &>/dev/null; then
        log_plan "Would enable podman.socket (Docker-compatible API for Testcontainers)"
        changes_planned=1
    fi
fi

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
