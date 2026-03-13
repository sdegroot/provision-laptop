#!/usr/bin/env bash
# test_module_git_projects.sh — Tests for the git-projects module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: git-projects..."

# --- repo_name_from_url ---

begin_test "repo_name_from_url extracts repo from GitHub SSH URL"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/modules/git-projects/common.sh"
result="$(repo_name_from_url "git@github.com:epistola-app/epistola.git")"
assert_equals "epistola" "$result"
teardown_test_tmpdir

begin_test "repo_name_from_url extracts repo from GitLab nested URL"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/modules/git-projects/common.sh"
result="$(repo_name_from_url "git@gitlab.com:gemeenteutrecht/devops/commutr-reporting.git")"
assert_equals "commutr-reporting" "$result"
teardown_test_tmpdir

begin_test "repo_name_from_url handles URL without .git suffix"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/modules/git-projects/common.sh"
result="$(repo_name_from_url "git@github.com:org/repo")"
assert_equals "repo" "$result"
teardown_test_tmpdir

begin_test "repo_name_from_url handles HTTPS URL"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/modules/git-projects/common.sh"
result="$(repo_name_from_url "https://gitlab.com/commonground/fsc/try-me.git")"
assert_equals "try-me" "$result"
teardown_test_tmpdir

# --- State file ---

begin_test "git-projects.conf is valid and parseable"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "git-projects.conf")"
output="$(parse_state_file "$STATE_FILE")"

if [[ -n "$output" ]]; then
    pass_test
else
    fail_test "State file is empty after parsing"
fi
teardown_test_tmpdir

begin_test "git-projects.conf entries have two fields"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "git-projects.conf")"
has_bad=false
while IFS= read -r line; do
    fields=$(echo "$line" | wc -w | tr -d ' ')
    if [[ "$fields" -ne 2 ]]; then
        has_bad=true
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ "$has_bad" == "false" ]]; then
    pass_test
else
    fail_test "Some entries don't have exactly 2 fields (url + namespace)"
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
git@github.com:testorg/testrepo.git myns
CONF

exit_code=0
output="$(
    export HOME="${TEST_TMPDIR}/home"
    mkdir -p "$HOME"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/git-projects/check.sh" 2>&1
)" || exit_code=$?

assert_equals "1" "$exit_code"
assert_contains "$output" "Missing: myns/testrepo"
teardown_test_tmpdir

# --- Check passes when repos exist ---

begin_test "check passes when git projects are cloned"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/git-projects" "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/git-projects/"*.sh "${custom_dir}/lib/modules/git-projects/"

cat > "${custom_dir}/state/git-projects.conf" <<'CONF'
git@github.com:testorg/testrepo.git myns
CONF

mkdir -p "${TEST_TMPDIR}/home/scm/myns/testrepo/.git"

exit_code=0
output="$(
    export HOME="${TEST_TMPDIR}/home"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/git-projects/check.sh" 2>&1
)" || exit_code=$?

assert_equals "0" "$exit_code"
assert_contains "$output" "Cloned: myns/testrepo"
teardown_test_tmpdir

# --- Plan ---

begin_test "plan reports repos to clone"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/git-projects" "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/git-projects/"*.sh "${custom_dir}/lib/modules/git-projects/"

cat > "${custom_dir}/state/git-projects.conf" <<'CONF'
git@github.com:testorg/testrepo.git myns
CONF

output="$(
    export HOME="${TEST_TMPDIR}/home"
    mkdir -p "$HOME"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/git-projects/plan.sh" 2>&1
)"

assert_contains "$output" "Would clone"
teardown_test_tmpdir

begin_test "plan reports no changes when repos exist"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/git-projects" "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/git-projects/"*.sh "${custom_dir}/lib/modules/git-projects/"

cat > "${custom_dir}/state/git-projects.conf" <<'CONF'
git@github.com:testorg/testrepo.git myns
CONF

mkdir -p "${TEST_TMPDIR}/home/scm/myns/testrepo/.git"

output="$(
    export HOME="${TEST_TMPDIR}/home"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/git-projects/plan.sh" 2>&1
)"

assert_contains "$output" "No git project changes needed"
teardown_test_tmpdir

print_test_summary "module: git-projects"
