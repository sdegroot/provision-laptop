#!/usr/bin/env bash
# toolboxes/check.sh — Verify toolbox containers match desired profiles.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"
source "${PROVISION_DIR}/lib/yaml.sh"

STATE_FILE="$(state_file_path "toolbox-profiles.yml")"
drift_found=0

if ! has_command toolbox; then
    log_warn "toolbox command not found — skipping"
    exit 0
fi

if ! has_command python3; then
    log_error "python3 required for YAML parsing"
    exit 1
fi

# Get existing toolbox containers
existing="$(toolbox list -c 2>/dev/null | tail -n +2 | awk '{print $2}' || true)"

# Check each profile
while IFS= read -r profile; do
    if echo "$existing" | grep -q "^${profile}$"; then
        log_ok "Toolbox exists: ${profile}"
    else
        log_error "Missing toolbox: ${profile}"
        drift_found=1
    fi
done < <(yaml_get_profile_names "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All toolbox containers match desired state"
fi

exit $drift_found
