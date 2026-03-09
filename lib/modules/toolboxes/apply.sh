#!/usr/bin/env bash
# toolboxes/apply.sh — Create and configure toolbox containers.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"
source "${PROVISION_DIR}/lib/yaml.sh"

STATE_FILE="$(state_file_path "toolbox-profiles.yml")"
PROFILES_DIR="${PROVISION_DIR}/toolbox/profiles"
BASE_SETUP="${PROVISION_DIR}/toolbox/base-setup.sh"
changes_made=0

if ! has_command toolbox; then
    log_warn "toolbox command not found — skipping"
    exit 0
fi

if ! has_command python3; then
    log_error "python3 required for YAML parsing"
    exit 1
fi

existing="$(toolbox list -c 2>/dev/null | tail -n +2 | awk '{print $2}' || true)"

while IFS= read -r profile; do
    if echo "$existing" | grep -q "^${profile}$"; then
        continue
    fi

    image="$(yaml_get_profile_image "$STATE_FILE" "$profile")"
    packages="$(yaml_get_profile_packages "$STATE_FILE" "$profile" | tr '\n' ' ')"
    setup_script="$(yaml_get_profile_setup_script "$STATE_FILE" "$profile")"

    log_info "Creating toolbox: ${profile} (image: ${image})"

    # Create the toolbox
    # Redirect stdin to /dev/null to prevent toolbox/podman from consuming
    # the while-read loop's input (classic stdin consumption bug).
    toolbox create --assumeyes --image "$image" "$profile" </dev/null

    # Run base setup with packages
    if [[ -n "$packages" ]]; then
        log_info "Installing packages in ${profile}: ${packages}"
        # shellcheck disable=SC2086
        toolbox run -c "$profile" bash "$BASE_SETUP" $packages </dev/null
    fi

    # Run profile-specific setup script
    if [[ -n "$setup_script" && -f "${PROFILES_DIR}/${setup_script}" ]]; then
        log_info "Running setup script for ${profile}: ${setup_script}"
        toolbox run -c "$profile" bash "${PROFILES_DIR}/${setup_script}" </dev/null
    fi

    changes_made=1
    log_ok "Created toolbox: ${profile}"
done < <(yaml_get_profile_names "$STATE_FILE")

if [[ $changes_made -eq 0 ]]; then
    log_ok "All toolbox containers already exist"
else
    log_ok "Toolbox containers applied"
fi
