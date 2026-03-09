#!/usr/bin/env bash
# test_module_directories.sh - Functional tests for the directories module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: directories..."

# --- check detects missing directories ---

begin_test "check reports drift when directories are missing"
setup_test_tmpdir

# Create a custom provision setup in tmpdir
custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/directories"
mkdir -p "${custom_dir}/state"

# Copy lib files
cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/directories/check.sh" "${custom_dir}/lib/modules/directories/"

# Create a test state file with a directory that doesn't exist
cat > "${custom_dir}/state/directories.txt" <<EOF
${TEST_TMPDIR}/testdir1::0755
${TEST_TMPDIR}/testdir2::0700
EOF

exit_code=0
(
    export PROVISION_ROOT=""
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/directories/check.sh"
) 2>&1 || exit_code=$?
assert_equals "1" "$exit_code"
teardown_test_tmpdir

# --- apply creates directories ---

begin_test "apply creates missing directories"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/directories"
mkdir -p "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/directories/apply.sh" "${custom_dir}/lib/modules/directories/"

cat > "${custom_dir}/state/directories.txt" <<EOF
${TEST_TMPDIR}/newdir1::0755
${TEST_TMPDIR}/newdir2::0700
EOF

(
    export PROVISION_ROOT=""
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/directories/apply.sh"
) 2>&1

# Verify directories were created
assert_dir_exists "${TEST_TMPDIR}/newdir1"

begin_test "apply creates directories with correct permissions"
if [[ "$(uname)" == "Darwin" ]]; then
    actual_mode=$(stat -f '%Lp' "${TEST_TMPDIR}/newdir2")
else
    actual_mode=$(stat -c '%a' "${TEST_TMPDIR}/newdir2")
fi
assert_equals "700" "$actual_mode"
teardown_test_tmpdir

# --- check passes when directories exist ---

begin_test "check passes when all directories exist with correct mode"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/directories"
mkdir -p "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/directories/check.sh" "${custom_dir}/lib/modules/directories/"

mkdir -p "${TEST_TMPDIR}/existingdir"
chmod 755 "${TEST_TMPDIR}/existingdir"

cat > "${custom_dir}/state/directories.txt" <<EOF
${TEST_TMPDIR}/existingdir::0755
EOF

exit_code=0
(
    export PROVISION_ROOT=""
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/directories/check.sh"
) 2>&1 || exit_code=$?
assert_equals "0" "$exit_code"
teardown_test_tmpdir

# --- plan shows what would be done ---

begin_test "plan reports planned changes for missing directories"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/directories"
mkdir -p "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/directories/plan.sh" "${custom_dir}/lib/modules/directories/"

cat > "${custom_dir}/state/directories.txt" <<EOF
${TEST_TMPDIR}/planned_dir::0755
EOF

output="$(
    export PROVISION_ROOT=""
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/directories/plan.sh"
) 2>&1"
assert_contains "$output" "Would create"
teardown_test_tmpdir

# --- plan is a no-op when directories exist ---

begin_test "plan reports no changes when state matches"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/directories"
mkdir -p "${custom_dir}/state"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/directories/plan.sh" "${custom_dir}/lib/modules/directories/"

mkdir -p "${TEST_TMPDIR}/already_exists"
chmod 755 "${TEST_TMPDIR}/already_exists"

cat > "${custom_dir}/state/directories.txt" <<EOF
${TEST_TMPDIR}/already_exists::0755
EOF

output="$(
    export PROVISION_ROOT=""
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/directories/plan.sh"
) 2>&1"
assert_contains "$output" "No directory changes needed"
teardown_test_tmpdir

print_test_summary "module: directories"
