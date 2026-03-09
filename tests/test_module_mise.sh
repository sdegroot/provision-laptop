#!/usr/bin/env bash
# test_module_mise.sh — Tests for the mise module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: mise..."

begin_test "mise config file exists in repo"
assert_file_exists "${SCRIPT_DIR}/../mise/mise.toml"

begin_test "mise config contains tool definitions"
setup_test_tmpdir
content="$(cat "${SCRIPT_DIR}/../mise/mise.toml")"
assert_contains "$content" "[tools]"
teardown_test_tmpdir

begin_test "mise apply creates config symlink"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/mise"
mkdir -p "${custom_dir}/mise"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/mise/apply.sh" "${custom_dir}/lib/modules/mise/"
cp "${SCRIPT_DIR}/../mise/mise.toml" "${custom_dir}/mise/"

output="$(
    export PROVISION_ROOT="$TEST_TMPDIR"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/mise/apply.sh"
) 2>&1"

config_path="${TEST_TMPDIR}${HOME}/.config/mise/config.toml"
assert_symlink "$config_path"
teardown_test_tmpdir

print_test_summary "module: mise"
