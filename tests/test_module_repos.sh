#!/usr/bin/env bash
# test_module_repos.sh — Tests for the repos module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: repos..."

# --- State file parsing ---

begin_test "repos.conf is valid and parseable"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "repos.conf")"
output="$(parse_state_file "$STATE_FILE")"

# Should contain repo entries
assert_contains "$output" "rpmfusion-free"
teardown_test_tmpdir

begin_test "repos.conf contains expected repo types"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "repos.conf")"
output="$(parse_state_file "$STATE_FILE")"

# Verify all expected types are present
has_repofile=false
has_free=false
has_nonfree=false
has_copr=false

while IFS= read -r line; do
    read -r repo_type _ <<< "$line"
    case "$repo_type" in
        repofile) has_repofile=true ;;
        rpmfusion-free) has_free=true ;;
        rpmfusion-nonfree) has_nonfree=true ;;
        copr) has_copr=true ;;
    esac
done <<< "$output"

if $has_repofile && $has_free && $has_nonfree && $has_copr; then
    pass_test
else
    fail_test "Missing repo types: repofile=$has_repofile free=$has_free nonfree=$has_nonfree copr=$has_copr"
fi
teardown_test_tmpdir

begin_test "repos.conf has no empty entries after parsing"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "repos.conf")"
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

begin_test "repos check skips gracefully on non-Silverblue"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/repos"
mkdir -p "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/repos/check.sh" "${custom_dir}/lib/modules/repos/"
cp "${SCRIPT_DIR}/../state/repos.conf" "${custom_dir}/state/"

exit_code=0
output="$(
    export PROVISION_ROOT="${TEST_TMPDIR}/fake-root"
    mkdir -p "${PROVISION_ROOT}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/repos/check.sh"
) 2>&1" || exit_code=$?

# Should exit 0 and skip gracefully (not Silverblue)
assert_equals "0" "$exit_code"
teardown_test_tmpdir

begin_test "repos plan skips gracefully on non-Silverblue"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/repos"
mkdir -p "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/repos/plan.sh" "${custom_dir}/lib/modules/repos/"
cp "${SCRIPT_DIR}/../state/repos.conf" "${custom_dir}/state/"

exit_code=0
output="$(
    export PROVISION_ROOT="${TEST_TMPDIR}/fake-root"
    mkdir -p "${PROVISION_ROOT}"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/repos/plan.sh"
) 2>&1" || exit_code=$?

assert_equals "0" "$exit_code"
teardown_test_tmpdir

print_test_summary "module: repos"
