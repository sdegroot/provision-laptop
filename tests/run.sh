#!/usr/bin/env bash
# run.sh - Test runner for all unit/integration tests.
#
# Usage: tests/run.sh [test_file...]
#   If no arguments, runs all test_*.sh files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  Provision Laptop - Test Suite"
echo "========================================"
echo ""

total_exit=0

if [[ $# -gt 0 ]]; then
    test_files=("$@")
else
    test_files=()
    for f in "${SCRIPT_DIR}"/test_*.sh; do
        [[ -f "$f" ]] && test_files+=("$f")
    done
fi

if [[ ${#test_files[@]} -eq 0 ]]; then
    echo "No test files found."
    exit 1
fi

for test_file in "${test_files[@]}"; do
    echo "--- Running: $(basename "$test_file") ---"
    exit_code=0
    bash "$test_file" || exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        total_exit=1
    fi
done

echo "========================================"
if [[ $total_exit -eq 0 ]]; then
    echo "  All test suites passed!"
else
    echo "  Some tests failed!"
fi
echo "========================================"

exit $total_exit
