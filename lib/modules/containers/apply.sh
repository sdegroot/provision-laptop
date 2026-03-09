#!/usr/bin/env bash
# containers/apply.sh — Build container images.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "containers.conf")"
changes_made=0

if ! has_command podman; then
    log_warn "podman command not found — skipping"
    exit 0
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
