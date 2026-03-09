#!/usr/bin/env bash
# test_module_dotfiles.sh — Functional tests for the dotfiles module.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: dotfiles..."

# --- check detects missing symlinks ---

begin_test "check reports drift when symlinks are missing"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/dotfiles"
mkdir -p "${custom_dir}/dotfiles/.config"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/dotfiles/check.sh" "${custom_dir}/lib/modules/dotfiles/"

echo "test content" > "${custom_dir}/dotfiles/.testrc"

exit_code=0
(
    export PROVISION_ROOT="$TEST_TMPDIR"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/dotfiles/check.sh"
) 2>&1 || exit_code=$?
assert_equals "1" "$exit_code"
teardown_test_tmpdir

# --- apply creates symlinks ---

begin_test "apply creates symlinks for dotfiles"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/dotfiles"
mkdir -p "${custom_dir}/dotfiles"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/dotfiles/apply.sh" "${custom_dir}/lib/modules/dotfiles/"

echo "test content" > "${custom_dir}/dotfiles/.testrc"

(
    export PROVISION_ROOT="$TEST_TMPDIR"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/dotfiles/apply.sh"
) 2>&1

target="${TEST_TMPDIR}${HOME}/.testrc"
assert_symlink "$target"
teardown_test_tmpdir

# --- apply backs up existing files ---

begin_test "apply backs up existing non-symlink files"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/dotfiles"
mkdir -p "${custom_dir}/dotfiles"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/dotfiles/apply.sh" "${custom_dir}/lib/modules/dotfiles/"

echo "new content" > "${custom_dir}/dotfiles/.testrc"

# Create an existing file at the target
target_dir="${TEST_TMPDIR}${HOME}"
mkdir -p "$target_dir"
echo "old content" > "${target_dir}/.testrc"

(
    export PROVISION_ROOT="$TEST_TMPDIR"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/dotfiles/apply.sh"
) 2>&1

# Should have created a backup
backup="${TEST_TMPDIR}${HOME}/.dotfiles-backup/.testrc"
assert_file_exists "$backup"
teardown_test_tmpdir

# --- check passes when symlinks are correct ---

begin_test "check passes when symlinks are correct"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/dotfiles"
mkdir -p "${custom_dir}/dotfiles"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/dotfiles/check.sh" "${custom_dir}/lib/modules/dotfiles/"
cp "${SCRIPT_DIR}/../lib/modules/dotfiles/apply.sh" "${custom_dir}/lib/modules/dotfiles/"

echo "content" > "${custom_dir}/dotfiles/.testrc"

# Apply first
(
    export PROVISION_ROOT="$TEST_TMPDIR"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/dotfiles/apply.sh"
) 2>&1

# Then check
exit_code=0
(
    export PROVISION_ROOT="$TEST_TMPDIR"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/dotfiles/check.sh"
) 2>&1 || exit_code=$?
assert_equals "0" "$exit_code"
teardown_test_tmpdir

# --- plan shows what would be done ---

begin_test "plan reports planned changes"
setup_test_tmpdir

custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules/dotfiles"
mkdir -p "${custom_dir}/dotfiles"

cp "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp "${SCRIPT_DIR}/../lib/modules/dotfiles/plan.sh" "${custom_dir}/lib/modules/dotfiles/"

echo "content" > "${custom_dir}/dotfiles/.testrc"

output="$(
    export PROVISION_ROOT="$TEST_TMPDIR"
    source "${custom_dir}/lib/common.sh"
    source "${custom_dir}/lib/modules/dotfiles/plan.sh"
) 2>&1"
assert_contains "$output" "Would create symlink"
teardown_test_tmpdir

print_test_summary "module: dotfiles"
