#!/usr/bin/env bash
# test_module_dock.sh — Tests for the dock module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: dock..."

begin_test "dock.txt is parseable"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "dock.txt")"
output="$(parse_state_file "$STATE_FILE")"

if [[ -n "$output" ]]; then
    pass_test
else
    fail_test "State file is empty after parsing"
fi
teardown_test_tmpdir

begin_test "dock.txt has no empty entries"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "dock.txt")"
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

begin_test "check skips gracefully when dock.txt missing"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/dock" "${custom_dir}/state"
cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/dock/check.sh" "${custom_dir}/lib/modules/dock/"

exit_code=0
output="$(
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/dock/check.sh" 2>&1
)" || exit_code=$?

assert_equals "0" "$exit_code"
assert_contains "$output" "skipping"
teardown_test_tmpdir

print_test_summary "module: dock"
