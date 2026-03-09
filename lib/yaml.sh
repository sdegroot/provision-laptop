#!/usr/bin/env bash
# yaml.sh — YAML parsing helpers using Python3.
#
# Fedora Silverblue ships Python3 with PyYAML available.

# yaml_get <file> <python_expression>
#   Parse a YAML file and evaluate a Python expression against it.
#   The parsed YAML is available as the variable 'data'.
yaml_get() {
    local file="${1:?yaml_get requires a file path}"
    local expr="${2:?yaml_get requires a Python expression}"

    python3 -c "
import yaml, sys
with open('${file}') as f:
    data = yaml.safe_load(f)
result = ${expr}
if isinstance(result, list):
    for item in result:
        print(item)
elif isinstance(result, dict):
    for key in result:
        print(key)
elif result is not None:
    print(result)
"
}

# yaml_get_list <file> <python_expression>
#   Same as yaml_get but explicitly for lists.
yaml_get_list() {
    yaml_get "$@"
}

# yaml_get_profile_names <file>
#   Get all profile names from a toolbox-profiles.yml file.
yaml_get_profile_names() {
    local file="${1:?requires a file path}"
    yaml_get "$file" "list(data.get('profiles', {}).keys())"
}

# yaml_get_profile_packages <file> <profile_name>
#   Get the package list for a specific profile.
yaml_get_profile_packages() {
    local file="${1:?requires a file path}"
    local profile="${2:?requires a profile name}"
    yaml_get "$file" "data['profiles']['${profile}'].get('packages', [])"
}

# yaml_get_profile_image <file> <profile_name>
#   Get the container image for a specific profile.
yaml_get_profile_image() {
    local file="${1:?requires a file path}"
    local profile="${2:?requires a profile name}"
    yaml_get "$file" "data['profiles']['${profile}'].get('image', '')"
}

# yaml_get_profile_setup_script <file> <profile_name>
#   Get the setup script name for a specific profile.
yaml_get_profile_setup_script() {
    local file="${1:?requires a file path}"
    local profile="${2:?requires a profile name}"
    yaml_get "$file" "data['profiles']['${profile}'].get('setup_script', '')"
}
