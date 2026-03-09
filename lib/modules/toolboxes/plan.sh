#!/usr/bin/env bash
# toolboxes/plan.sh — Show planned toolbox changes (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"
source "${PROVISION_DIR}/lib/yaml.sh"

STATE_FILE="$(state_file_path "toolbox-profiles.yml")"
changes_planned=0

if ! has_command toolbox; then
    log_plan "Would need toolbox command (not available)"
    exit 0
fi

if ! has_command python3; then
    log_plan "Would need python3 for YAML parsing"
    exit 0
fi

existing="$(toolbox list -c 2>/dev/null | tail -n +2 | awk '{print $2}' || true)"

while IFS= read -r profile; do
    if echo "$existing" | grep -q "^${profile}$"; then
        continue
    fi

    image="$(yaml_get_profile_image "$STATE_FILE" "$profile")"
    log_plan "Would create toolbox: ${profile} (image: ${image})"
    changes_planned=1
done < <(yaml_get_profile_names "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No toolbox changes needed"
fi
