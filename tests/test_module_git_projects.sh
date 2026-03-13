#!/usr/bin/env bash
# test_module_git_projects.sh — Tests for the git-projects module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: git-projects..."

# --- clone_url_to_path ---

begin_test "clone_url_to_path derives correct path from GitHub SSH URL"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/modules/git-projects/common.sh"
result="$(clone_url_to_path "git@github.com:sdegroot/provision-laptop.git")"
assert_contains "$result" "scm/sdegroot/provision-laptop"
teardown_test_tmpdir

begin_test "clone_url_to_path derives correct path from GitLab SSH URL"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/modules/git-projects/common.sh"
result="$(clone_url_to_path "git@gitlab.com:epistola/backend.git")"
assert_contains "$result" "scm/epistola/backend"
teardown_test_tmpdir

begin_test "clone_url_to_path handles URL without .git suffix"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/modules/git-projects/common.sh"
result="$(clone_url_to_path "git@github.com:org/repo")"
assert_contains "$result" "scm/org/repo"
teardown_test_tmpdir

# --- State file ---

begin_test "git-projects.conf is valid and parseable"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "git-projects.conf")"
output="$(parse_state_file "$STATE_FILE")"

# Should have at least one entry
if [[ -n "$output" ]]; then
    pass_test
else
    fail_test "State file is empty after parsing"
fi
teardown_test_tmpdir

# --- Check detects missing repos ---

begin_test "check detects missing git projects"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/git-projects" "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/git-projects/"*.sh "${custom_dir}/lib/modules/git-projects/"

cat > "${custom_dir}/state/git-projects.conf" <<'CONF'
git@github.com:testorg/testrepo.git
CONF

exit_code=0
output="$(
    export HOME="${TEST_TMPDIR}/home"
    mkdir -p "$HOME"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/git-projects/check.sh" 2>&1
)" || exit_code=$?

assert_equals "1" "$exit_code"
assert_contains "$output" "Missing"
teardown_test_tmpdir

# --- Check passes when repos exist ---

begin_test "check passes when git projects are cloned"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/git-projects" "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/git-projects/"*.sh "${custom_dir}/lib/modules/git-projects/"

cat > "${custom_dir}/state/git-projects.conf" <<'CONF'
git@github.com:testorg/testrepo.git
CONF

# Simulate a cloned repo
mkdir -p "${TEST_TMPDIR}/home/scm/testorg/testrepo/.git"

exit_code=0
output="$(
    export HOME="${TEST_TMPDIR}/home"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/git-projects/check.sh" 2>&1
)" || exit_code=$?

assert_equals "0" "$exit_code"
assert_contains "$output" "Cloned"
teardown_test_tmpdir

# --- Plan reports repos to clone ---

begin_test "plan reports repos to clone"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/git-projects" "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/git-projects/"*.sh "${custom_dir}/lib/modules/git-projects/"

cat > "${custom_dir}/state/git-projects.conf" <<'CONF'
git@github.com:testorg/testrepo.git
CONF

output="$(
    export HOME="${TEST_TMPDIR}/home"
    mkdir -p "$HOME"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/git-projects/plan.sh"
) 2>&1"

assert_contains "$output" "Would clone"
teardown_test_tmpdir

begin_test "plan reports no changes when repos exist"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/git-projects" "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/git-projects/"*.sh "${custom_dir}/lib/modules/git-projects/"

cat > "${custom_dir}/state/git-projects.conf" <<'CONF'
git@github.com:testorg/testrepo.git
CONF

mkdir -p "${TEST_TMPDIR}/home/scm/testorg/testrepo/.git"

output="$(
    export HOME="${TEST_TMPDIR}/home"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/git-projects/plan.sh"
) 2>&1"

assert_contains "$output" "No git project changes needed"
teardown_test_tmpdir

print_test_summary "module: git-projects"
