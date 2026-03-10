#!/usr/bin/env bash
# test_netbird.sh — Tests for bin/netbird account parsing, validation, and commands.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"
PROVISION_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

NETBIRD="${PROVISION_DIR}/bin/netbird"

# Helper: create a temp accounts file with test data
create_test_accounts() {
    local file="$1"
    cat > "$file" <<'EOF'
# Test accounts
work:op://Work/Netbird Work/credential
home:op://Personal/Netbird Home/credential
EOF
}

# ---------------------------------------------------------------------------
# Help / usage tests
# ---------------------------------------------------------------------------

begin_test "no arguments shows usage and exits 1"
output="$("$NETBIRD" 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "no arguments output contains Usage"
output="$("$NETBIRD" 2>&1)" || true
assert_contains "$output" "Usage:"

begin_test "--help exits 0"
output="$("$NETBIRD" --help 2>&1)" && rc=0 || rc=$?
assert_exit_code "0" "$rc"

begin_test "--help shows commands"
output="$("$NETBIRD" --help 2>&1)"
assert_contains "$output" "up <account>"

begin_test "help command exits 0"
output="$("$NETBIRD" help 2>&1)" && rc=0 || rc=$?
assert_exit_code "0" "$rc"

begin_test "unknown command exits 1"
output="$("$NETBIRD" bogus 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "unknown command mentions the bad command"
output="$("$NETBIRD" bogus 2>&1)" || true
assert_contains "$output" "bogus"

# ---------------------------------------------------------------------------
# Account parsing tests (using NETBIRD_ACCOUNTS_FILE env var)
# ---------------------------------------------------------------------------

begin_test "list shows configured accounts"
setup_test_tmpdir
create_test_accounts "${TEST_TMPDIR}/accounts.conf"
output="$(NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" "$NETBIRD" list 2>&1)"
assert_contains "$output" "work"
teardown_test_tmpdir

begin_test "list shows all accounts"
setup_test_tmpdir
create_test_accounts "${TEST_TMPDIR}/accounts.conf"
output="$(NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" "$NETBIRD" list 2>&1)"
assert_contains "$output" "home"
teardown_test_tmpdir

begin_test "list with empty config warns"
setup_test_tmpdir
cat > "${TEST_TMPDIR}/accounts.conf" <<'EOF'
# Only comments
EOF
output="$(NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" "$NETBIRD" list 2>&1)"
assert_contains "$output" "No accounts configured"
teardown_test_tmpdir

begin_test "list with missing config exits 1"
output="$(NETBIRD_ACCOUNTS_FILE="/nonexistent/file" "$NETBIRD" list 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

# ---------------------------------------------------------------------------
# Command validation tests
# ---------------------------------------------------------------------------

begin_test "up without account name exits 1"
output="$("$NETBIRD" up 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "switch without account name exits 1"
output="$("$NETBIRD" switch 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "up with unknown account exits 1"
setup_test_tmpdir
create_test_accounts "${TEST_TMPDIR}/accounts.conf"
output="$(
    NETBIRD_DRY_RUN=1 \
    NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" up nonexistent 2>&1
)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"
teardown_test_tmpdir

begin_test "up with unknown account shows available accounts"
setup_test_tmpdir
create_test_accounts "${TEST_TMPDIR}/accounts.conf"
output="$(
    NETBIRD_DRY_RUN=1 \
    NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" up nonexistent 2>&1
)" || true
assert_contains "$output" "work"
teardown_test_tmpdir

# ---------------------------------------------------------------------------
# Dry-run tests
# ---------------------------------------------------------------------------

begin_test "dry-run up calls netbird up with setup key"
setup_test_tmpdir
create_test_accounts "${TEST_TMPDIR}/accounts.conf"
mkdir -p "$(dirname "${TEST_TMPDIR}/current-account")"
output="$(
    NETBIRD_DRY_RUN=1 \
    NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" up work 2>&1
)"
assert_contains "$output" "[dry-run] sudo netbird up --setup-key"
teardown_test_tmpdir

begin_test "dry-run up writes current-account file"
setup_test_tmpdir
create_test_accounts "${TEST_TMPDIR}/accounts.conf"
NETBIRD_DRY_RUN=1 \
NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
"$NETBIRD" up work >/dev/null 2>&1
if [[ -f "${TEST_TMPDIR}/current-account" ]]; then
    content="$(cat "${TEST_TMPDIR}/current-account")"
    assert_equals "work" "$content"
else
    fail_test "current-account file was not created"
fi
teardown_test_tmpdir

begin_test "dry-run up shows Connected message"
setup_test_tmpdir
create_test_accounts "${TEST_TMPDIR}/accounts.conf"
output="$(
    NETBIRD_DRY_RUN=1 \
    NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" up work 2>&1
)"
assert_contains "$output" "Connected to 'work'"
teardown_test_tmpdir

begin_test "dry-run down calls netbird down"
setup_test_tmpdir
output="$(
    NETBIRD_DRY_RUN=1 \
    NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" down 2>&1
)"
assert_contains "$output" "[dry-run] sudo netbird down"
teardown_test_tmpdir

begin_test "dry-run down removes current-account file"
setup_test_tmpdir
echo "work" > "${TEST_TMPDIR}/current-account"
NETBIRD_DRY_RUN=1 \
NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
"$NETBIRD" down >/dev/null 2>&1
if [[ -f "${TEST_TMPDIR}/current-account" ]]; then
    fail_test "current-account file should have been removed"
else
    pass_test
fi
teardown_test_tmpdir

begin_test "dry-run status shows no active account when file missing"
setup_test_tmpdir
output="$(
    NETBIRD_DRY_RUN=1 \
    NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" status 2>&1
)"
assert_contains "$output" "No account currently active"
teardown_test_tmpdir

begin_test "dry-run status shows current account when file exists"
setup_test_tmpdir
echo "home" > "${TEST_TMPDIR}/current-account"
output="$(
    NETBIRD_DRY_RUN=1 \
    NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" status 2>&1
)"
assert_contains "$output" "Current account: home"
teardown_test_tmpdir

begin_test "dry-run switch calls down then up"
setup_test_tmpdir
create_test_accounts "${TEST_TMPDIR}/accounts.conf"
output="$(
    NETBIRD_DRY_RUN=1 \
    NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" switch home 2>&1
)"
assert_contains "$output" "[dry-run] sudo netbird down"
teardown_test_tmpdir

begin_test "dry-run switch connects to new account"
setup_test_tmpdir
create_test_accounts "${TEST_TMPDIR}/accounts.conf"
output="$(
    NETBIRD_DRY_RUN=1 \
    NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" switch home 2>&1
)"
assert_contains "$output" "Connected to 'home'"
teardown_test_tmpdir

begin_test "dry-run switch with unknown account exits 1 without disconnecting"
setup_test_tmpdir
create_test_accounts "${TEST_TMPDIR}/accounts.conf"
output="$(
    NETBIRD_DRY_RUN=1 \
    NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" switch nonexistent 2>&1
)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"
teardown_test_tmpdir

# ---------------------------------------------------------------------------
# op:// reference parsing (colons in value)
# ---------------------------------------------------------------------------

begin_test "account ref with colons in op:// path is preserved"
setup_test_tmpdir
cat > "${TEST_TMPDIR}/accounts.conf" <<'EOF'
complex:op://Vault/Item Name/section:field
EOF
output="$(NETBIRD_ACCOUNTS_FILE="${TEST_TMPDIR}/accounts.conf" \
    NETBIRD_DRY_RUN=1 \
    NETBIRD_CURRENT_FILE="${TEST_TMPDIR}/current-account" \
    "$NETBIRD" up complex 2>&1)"
assert_contains "$output" "[dry-run] sudo netbird up --setup-key"
teardown_test_tmpdir

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_test_summary "Netbird"
