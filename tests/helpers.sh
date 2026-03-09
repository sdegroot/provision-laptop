#!/usr/bin/env bash
# helpers.sh - Test assertion functions and utilities.

set -euo pipefail

# Test counters
_TESTS_RUN=0
_TESTS_PASSED=0
_TESTS_FAILED=0
_CURRENT_TEST=""

# Create a temp dir for test isolation
TEST_TMPDIR=""
setup_test_tmpdir() {
    TEST_TMPDIR="$(mktemp -d)"
    export PROVISION_ROOT="$TEST_TMPDIR"
    export PROVISION_ALLOW_NONROOT=1
    export NO_COLOR=1
}

teardown_test_tmpdir() {
    if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

# Test lifecycle
begin_test() {
    _CURRENT_TEST="$1"
    (( _TESTS_RUN++ )) || true
}

pass_test() {
    (( _TESTS_PASSED++ )) || true
    printf "  PASS: %s\n" "$_CURRENT_TEST"
}

fail_test() {
    local msg="${1:-}"
    (( _TESTS_FAILED++ )) || true
    printf "  FAIL: %s" "$_CURRENT_TEST"
    if [[ -n "$msg" ]]; then
        printf " - %s" "$msg"
    fi
    printf "\n"
}

# Assertions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-expected '$expected' but got '$actual'}"
    if [[ "$expected" == "$actual" ]]; then
        pass_test
    else
        fail_test "$msg"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-expected output to contain '$needle'}"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass_test
    else
        fail_test "$msg"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="${3:-expected output NOT to contain '$needle'}"
    if [[ "$haystack" != *"$needle"* ]]; then
        pass_test
    else
        fail_test "$msg"
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-expected exit code $expected but got $actual}"
    assert_equals "$expected" "$actual" "$msg"
}

assert_dir_exists() {
    local path="$1"
    if [[ -d "$path" ]]; then
        pass_test
    else
        fail_test "directory does not exist: $path"
    fi
}

assert_file_exists() {
    local path="$1"
    if [[ -f "$path" ]]; then
        pass_test
    else
        fail_test "file does not exist: $path"
    fi
}

assert_symlink() {
    local path="$1"
    if [[ -L "$path" ]]; then
        pass_test
    else
        fail_test "not a symlink: $path"
    fi
}

# Summary
print_test_summary() {
    local suite_name="${1:-Tests}"
    echo ""
    echo "=== ${suite_name} ==="
    echo "  Total:  ${_TESTS_RUN}"
    echo "  Passed: ${_TESTS_PASSED}"
    echo "  Failed: ${_TESTS_FAILED}"
    echo ""
    if [[ $_TESTS_FAILED -gt 0 ]]; then
        return 1
    fi
    return 0
}
