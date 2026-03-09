#!/usr/bin/env bash
# test_engine.sh - Unit tests for lib/engine.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing lib/engine.sh..."

# We need to source engine.sh fresh for each test that needs it,
# so we use subshells.

begin_test "load_module_order returns modules from order.conf"
output="$(
    source "${SCRIPT_DIR}/../lib/engine.sh"
    load_module_order
)"
assert_contains "$output" "directories"

begin_test "run_module fails for invalid mode"
exit_code=0
output="$(
    source "${SCRIPT_DIR}/../lib/engine.sh"
    run_module "directories" "invalid_mode" 2>&1
)" || exit_code=$?
assert_equals "1" "$exit_code"

begin_test "run_module fails for nonexistent module"
exit_code=0
output="$(
    source "${SCRIPT_DIR}/../lib/engine.sh"
    run_module "nonexistent_module" "check" 2>&1
)" || exit_code=$?
assert_equals "1" "$exit_code"

begin_test "parse_engine_args rejects unknown arguments"
exit_code=0
output="$(
    source "${SCRIPT_DIR}/../lib/engine.sh"
    parse_engine_args "check" "--unknown-flag" 2>&1
)" || exit_code=$?
assert_equals "1" "$exit_code"

begin_test "load_module_order handles custom order.conf"
setup_test_tmpdir
# Create a custom PROVISION_DIR with custom order.conf
custom_dir="${TEST_TMPDIR}/provision"
mkdir -p "${custom_dir}/lib/modules"
cat > "${custom_dir}/lib/modules/order.conf" <<'EOF'
# Custom order
module_a
module_b
# comment in middle
module_c
EOF
# Copy common.sh and engine.sh
cp -r "${SCRIPT_DIR}/../lib/common.sh" "${custom_dir}/lib/"
cp -r "${SCRIPT_DIR}/../lib/engine.sh" "${custom_dir}/lib/"

output="$(
    _ENGINE_LOADED=""
    source "${custom_dir}/lib/engine.sh"
    load_module_order
)"
expected="$(printf 'module_a\nmodule_b\nmodule_c')"
assert_equals "$expected" "$output"
teardown_test_tmpdir

print_test_summary "lib/engine.sh"
