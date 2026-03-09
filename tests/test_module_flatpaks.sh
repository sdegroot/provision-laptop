#!/usr/bin/env bash
# test_module_flatpaks.sh — Tests for the flatpaks module.
# These tests verify parsing and logic without actually calling flatpak.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"

export NO_COLOR=1
export PROVISION_ALLOW_NONROOT=1

echo "Testing module: flatpaks..."

# --- State file parsing ---

begin_test "flatpaks state file is valid and parseable"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "flatpaks.txt")"
output="$(parse_state_file "$STATE_FILE")"

# Should contain at least one app ID
assert_contains "$output" "org.mozilla.firefox"
teardown_test_tmpdir

begin_test "flatpaks state file entries look like valid app IDs"
setup_test_tmpdir

source "${SCRIPT_DIR}/../lib/common.sh"
STATE_FILE="$(state_file_path "flatpaks.txt")"
all_valid=true
while IFS= read -r line; do
    # Basic validation: should contain at least two dots (org.something.App)
    dot_count=$(echo "$line" | tr -cd '.' | wc -c | tr -d ' ')
    if [[ "$dot_count" -lt 2 ]]; then
        all_valid=false
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ "$all_valid" == "true" ]]; then
    pass_test
else
    fail_test "Some entries don't look like valid Flatpak app IDs"
fi
teardown_test_tmpdir

print_test_summary "module: flatpaks"
