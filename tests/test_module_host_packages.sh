#!/usr/bin/env bash
# test_module_host_packages.sh — Tests for the host-packages module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: host-packages..."

begin_test "host-packages state file is valid and parseable"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "host-packages.txt")"
output="$(parse_state_file "$STATE_FILE")"

# Should contain at least one package
assert_contains "$output" "git"
teardown_test_tmpdir

begin_test "host-packages state file has no empty entries"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "host-packages.txt")"
has_empty=false
while IFS= read -r line; do
    if [[ -z "${line// /}" ]]; then
        has_empty=true
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ "$has_empty" == "false" ]]; then
    pass_test
else
    fail_test "State file contains empty entries after parsing"
fi
teardown_test_tmpdir

begin_test "host-packages check skips gracefully on non-Silverblue"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/host-packages"
mkdir -p "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/host-packages/check.sh" "${custom_dir}/lib/modules/host-packages/"
cp "${SCRIPT_DIR}/../state/host-packages.txt" "${custom_dir}/state/"

exit_code=0
output="$(
    export PROVISION_ROOT="${TEST_TMPDIR}/fake-root"
    mkdir -p "${PROVISION_ROOT}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/host-packages/check.sh"
) 2>&1" || exit_code=$?

# Should exit 0 and skip gracefully (not Silverblue)
assert_equals "0" "$exit_code"
teardown_test_tmpdir

print_test_summary "module: host-packages"
