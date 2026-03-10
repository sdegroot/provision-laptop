#!/usr/bin/env bash
# containers/check.sh — Verify container images are built.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "containers.conf")"
drift_found=0

if ! has_command podman; then
    log_warn "podman command not found — skipping"
    exit 0
fi

# Check podman socket (Docker-compatible API for Testcontainers, etc.)
if [[ -z "$PROVISION_ROOT" ]]; then
    if systemctl --user is-enabled podman.socket &>/dev/null; then
        log_ok "podman.socket enabled"
    else
        log_error "podman.socket not enabled (needed for Testcontainers)"
        drift_found=1
    fi
fi

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
