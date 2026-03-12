#!/usr/bin/env bash
# test_common.sh - Unit tests for lib/common.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

# Source the module under test
export NO_COLOR=1
source "${SCRIPT_DIR}/../lib/common.sh"

echo "Testing lib/common.sh..."

# --- parse_state_file ---

begin_test "parse_state_file strips comments and blank lines"
setup_test_tmpdir
cat > "${TEST_TMPDIR}/test_state.txt" <<'EOF'
# This is a comment
first_line

# Another comment
second_line

third_line
EOF
output="$(parse_state_file "${TEST_TMPDIR}/test_state.txt")"
expected="$(printf 'first_line\nsecond_line\nthird_line')"
assert_equals "$expected" "$output"
teardown_test_tmpdir

begin_test "parse_state_file returns error for missing file"
setup_test_tmpdir
exit_code=0
parse_state_file "${TEST_TMPDIR}/nonexistent.txt" >/dev/null 2>&1 || exit_code=$?
assert_equals "1" "$exit_code"
teardown_test_tmpdir

begin_test "parse_state_file handles file with only comments"
setup_test_tmpdir
cat > "${TEST_TMPDIR}/comments_only.txt" <<'EOF'
# Just comments
# Nothing else
EOF
output="$(parse_state_file "${TEST_TMPDIR}/comments_only.txt")"
assert_equals "" "$output"
teardown_test_tmpdir

# --- parse_state_file with arch tags ---

begin_test "parse_state_file includes lines matching current arch"
setup_test_tmpdir
cat > "${TEST_TMPDIR}/arch_state.txt" <<'EOF'
universal-package
[x86_64] x86-only-package
[aarch64] arm-only-package
EOF
output="$(PROVISION_ARCH=x86_64 parse_state_file "${TEST_TMPDIR}/arch_state.txt")"
expected="$(printf 'universal-package\nx86-only-package')"
assert_equals "$expected" "$output"
teardown_test_tmpdir

begin_test "parse_state_file excludes lines not matching current arch"
setup_test_tmpdir
cat > "${TEST_TMPDIR}/arch_state.txt" <<'EOF'
universal-package
[x86_64] x86-only-package
[aarch64] arm-only-package
EOF
output="$(PROVISION_ARCH=aarch64 parse_state_file "${TEST_TMPDIR}/arch_state.txt")"
expected="$(printf 'universal-package\narm-only-package')"
assert_equals "$expected" "$output"
teardown_test_tmpdir

begin_test "parse_state_file handles arch tags with multi-word values"
setup_test_tmpdir
cat > "${TEST_TMPDIR}/arch_state.txt" <<'EOF'
[x86_64] repofile https://example.com/repo.repo
rpmfusion-free
EOF
output="$(PROVISION_ARCH=x86_64 parse_state_file "${TEST_TMPDIR}/arch_state.txt")"
expected="$(printf 'repofile https://example.com/repo.repo\nrpmfusion-free')"
assert_equals "$expected" "$output"
teardown_test_tmpdir

# --- state_file_path ---

begin_test "state_file_path returns correct path"
result="$(state_file_path "test.txt")"
expected="${PROVISION_DIR}/state/test.txt"
assert_equals "$expected" "$result"

# --- has_command ---

begin_test "has_command finds bash"
exit_code=0
has_command bash || exit_code=$?
assert_equals "0" "$exit_code"

begin_test "has_command rejects nonexistent command"
exit_code=0
has_command this_command_surely_does_not_exist_xyz || exit_code=$?
assert_equals "1" "$exit_code"

# --- is_silverblue ---

begin_test "is_silverblue returns false without rpm-ostree"
setup_test_tmpdir
exit_code=0
is_silverblue || exit_code=$?
assert_equals "1" "$exit_code"
teardown_test_tmpdir

begin_test "is_silverblue returns true with rpm-ostree present"
setup_test_tmpdir
mkdir -p "${PROVISION_ROOT}/usr/bin"
touch "${PROVISION_ROOT}/usr/bin/rpm-ostree"
chmod +x "${PROVISION_ROOT}/usr/bin/rpm-ostree"
exit_code=0
is_silverblue || exit_code=$?
assert_equals "0" "$exit_code"
teardown_test_tmpdir

# --- require_root ---

begin_test "require_root succeeds with PROVISION_ALLOW_NONROOT"
export PROVISION_ALLOW_NONROOT=1
exit_code=0
require_root || exit_code=$?
assert_equals "0" "$exit_code"

# --- logging ---

begin_test "log_info outputs INFO tag"
output="$(log_info "test message" 2>&1)"
assert_contains "$output" "[INFO]"

begin_test "log_error outputs ERROR tag"
output="$(log_error "test error" 2>&1)"
assert_contains "$output" "[ERROR]"

begin_test "log_ok outputs OK tag"
output="$(log_ok "test ok" 2>&1)"
assert_contains "$output" "[OK]"

begin_test "log_warn outputs WARN tag"
output="$(log_warn "test warning" 2>&1)"
assert_contains "$output" "[WARN]"

begin_test "log_plan outputs PLAN tag"
output="$(log_plan "test plan" 2>&1)"
assert_contains "$output" "[PLAN]"

# --- wait_for_rpm_ostree ---

begin_test "wait_for_rpm_ostree returns immediately when no transaction active"
# Stub rpm-ostree to return idle status
rpm-ostree() { echo "State: idle"; }
export -f rpm-ostree
exit_code=0
wait_for_rpm_ostree 5 || exit_code=$?
unset -f rpm-ostree
assert_equals "0" "$exit_code"

begin_test "wait_for_rpm_ostree times out when transaction stays busy"
rpm-ostree() { echo "State: busy"; }
sleep() { :; }  # stub sleep for fast tests
export -f rpm-ostree sleep
exit_code=0
output="$(wait_for_rpm_ostree 1 2>&1)" || exit_code=$?
unset -f rpm-ostree sleep
assert_equals "1" "$exit_code"

begin_test "wait_for_rpm_ostree detects 'transaction in progress' text"
rpm-ostree() { echo "error: Transaction in progress"; }
sleep() { :; }
export -f rpm-ostree sleep
exit_code=0
output="$(wait_for_rpm_ostree 1 2>&1)" || exit_code=$?
unset -f rpm-ostree sleep
assert_equals "1" "$exit_code"

begin_test "wait_for_rpm_ostree logs info on first wait iteration"
# Use a temp file as counter since subshells can't modify parent vars
_counter_file="$(mktemp)"
echo "0" > "$_counter_file"
rpm-ostree() {
    local c; c="$(cat "$_counter_file")"
    echo $((c + 1)) > "$_counter_file"
    if [[ $c -lt 1 ]]; then echo "State: busy"; else echo "State: idle"; fi
}
sleep() { :; }
export -f rpm-ostree sleep
export _counter_file
output="$(wait_for_rpm_ostree 10 2>&1)"
unset -f rpm-ostree sleep
rm -f "$_counter_file"
unset _counter_file
assert_contains "$output" "Waiting for rpm-ostree transaction"

# --- wait_for_kickstart_packages ---

begin_test "wait_for_kickstart_packages returns immediately when service not active"
# Stub systemctl to return non-active
systemctl() { return 1; }
export -f systemctl
exit_code=0
wait_for_kickstart_packages || exit_code=$?
unset -f systemctl
assert_equals "0" "$exit_code"

print_test_summary "lib/common.sh"
