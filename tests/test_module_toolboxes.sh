#!/usr/bin/env bash
# test_module_toolboxes.sh — Tests for the toolboxes module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: toolboxes..."

# --- YAML parsing ---

begin_test "yaml parser reads profile names"
if ! python3 -c "import yaml" 2>/dev/null; then
    pass_test  # Skip if no PyYAML
else
    source "${SCRIPT_DIR}/../lib/yaml.sh"
    STATE_FILE="${SCRIPT_DIR}/../state/toolbox-profiles.yml"
    output="$(yaml_get_profile_names "$STATE_FILE")"
    assert_contains "$output" "dev-base"
fi

begin_test "yaml parser reads profile packages"
if ! python3 -c "import yaml" 2>/dev/null; then
    pass_test  # Skip if no PyYAML
else
    source "${SCRIPT_DIR}/../lib/yaml.sh"
    STATE_FILE="${SCRIPT_DIR}/../state/toolbox-profiles.yml"
    output="$(yaml_get_profile_packages "$STATE_FILE" "dev-base")"
    assert_contains "$output" "git"
fi

begin_test "yaml parser reads profile image"
if ! python3 -c "import yaml" 2>/dev/null; then
    pass_test  # Skip if no PyYAML
else
    source "${SCRIPT_DIR}/../lib/yaml.sh"
    STATE_FILE="${SCRIPT_DIR}/../state/toolbox-profiles.yml"
    output="$(yaml_get_profile_image "$STATE_FILE" "dev-base")"
    assert_contains "$output" "fedora-toolbox"
fi

begin_test "yaml parser reads setup script name"
if ! python3 -c "import yaml" 2>/dev/null; then
    pass_test  # Skip if no PyYAML
else
    source "${SCRIPT_DIR}/../lib/yaml.sh"
    STATE_FILE="${SCRIPT_DIR}/../state/toolbox-profiles.yml"
    output="$(yaml_get_profile_setup_script "$STATE_FILE" "dev-base")"
    assert_equals "dev-base.sh" "$output"
fi

print_test_summary "module: toolboxes"
