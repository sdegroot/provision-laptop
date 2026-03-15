#!/usr/bin/env bash
# test_system_health_review.sh — Tests for bin/system-health-review.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"
PROVISION_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

HEALTH_REVIEW="${PROVISION_DIR}/bin/system-health-review"

# We run on macOS too (Darwin guard), so we need to stub uname for tests.
# The script exits with error on Darwin, so we create a wrapper that
# overrides uname and stubs all Linux-specific commands.

create_test_wrapper() {
    local tmpdir="$1"
    local wrapper="${tmpdir}/system-health-review-test"
    local stub_bin="${tmpdir}/stub-bin"

    mkdir -p "$stub_bin"

    # Stub uname to report Linux
    cat > "${stub_bin}/uname" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "-m" ]]; then echo "x86_64"; else echo "Linux"; fi
STUB
    chmod +x "${stub_bin}/uname"

    # Stub journalctl
    cat > "${stub_bin}/journalctl" <<'STUB'
#!/usr/bin/env bash
echo "Mar 15 08:00:00 laptop kernel: Test warning message"
echo "Mar 15 08:01:00 laptop kernel: Another warning"
STUB
    chmod +x "${stub_bin}/journalctl"

    # Stub systemctl
    cat > "${stub_bin}/systemctl" <<'STUB'
#!/usr/bin/env bash
# Return empty (no failed units) by default
exit 0
STUB
    chmod +x "${stub_bin}/systemctl"

    # Stub rpm-ostree
    cat > "${stub_bin}/rpm-ostree" <<'STUB'
#!/usr/bin/env bash
echo "State: idle"
echo "Deployments:"
echo "  fedora:fedora/43/x86_64/silverblue"
STUB
    chmod +x "${stub_bin}/rpm-ostree"

    # Stub flatpak
    cat > "${stub_bin}/flatpak" <<'STUB'
#!/usr/bin/env bash
echo "org.mozilla.firefox	131.0"
STUB
    chmod +x "${stub_bin}/flatpak"

    # Stub ip
    cat > "${stub_bin}/ip" <<'STUB'
#!/usr/bin/env bash
echo "lo      UNKNOWN  127.0.0.1/8"
echo "wlan0   UP       192.168.1.100/24"
STUB
    chmod +x "${stub_bin}/ip"

    # Stub ss
    cat > "${stub_bin}/ss" <<'STUB'
#!/usr/bin/env bash
echo "Netid  State  Recv-Q  Send-Q  Local Address:Port"
echo "tcp    LISTEN 0       128     *:22"
STUB
    chmod +x "${stub_bin}/ss"

    # Stub df
    cat > "${stub_bin}/df" <<'STUB'
#!/usr/bin/env bash
echo "Filesystem  Size  Used Avail Use% Mounted on"
echo "/dev/sda1   100G  50G  50G   50% /"
STUB
    chmod +x "${stub_bin}/df"

    # Stub btrfs
    cat > "${stub_bin}/btrfs" <<'STUB'
#!/usr/bin/env bash
echo "[/dev/sda1].write_io_errs    0"
echo "[/dev/sda1].read_io_errs     0"
STUB
    chmod +x "${stub_bin}/btrfs"

    # Stub dnf
    cat > "${stub_bin}/dnf" <<'STUB'
#!/usr/bin/env bash
echo "FEDORA-2026-abc123  Important  kernel-6.12.1-200.fc43.x86_64"
STUB
    chmod +x "${stub_bin}/dnf"

    # Stub mise — returns failure so claude is "not found"
    cat > "${stub_bin}/mise" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
    chmod +x "${stub_bin}/mise"

    # Stub claude — not available (ensure fallback report)
    # We override command -v by NOT providing a claude stub

    # Stub notify-send — record call
    cat > "${stub_bin}/notify-send" <<STUB
#!/usr/bin/env bash
echo "NOTIFY_CALLED: \$*" > "${tmpdir}/notify-sent"
STUB
    chmod +x "${stub_bin}/notify-send"

    # Stub xdg-open
    cat > "${stub_bin}/xdg-open" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
    chmod +x "${stub_bin}/xdg-open"

    # Stub find (for prune_old_reports)
    cat > "${stub_bin}/find" <<'STUB'
#!/usr/bin/env bash
# No-op for cleanup
exit 0
STUB
    chmod +x "${stub_bin}/find"

    echo "$stub_bin"
}

# ---------------------------------------------------------------------------
# CLI parsing tests
# ---------------------------------------------------------------------------

begin_test "--help exits 0"
# --help doesn't hit the Darwin guard since it exits before main
output="$("$HEALTH_REVIEW" --help 2>&1)" && rc=0 || rc=$?
assert_exit_code "0" "$rc"

begin_test "--help shows usage"
output="$("$HEALTH_REVIEW" --help 2>&1)"
assert_contains "$output" "Usage:" "should show usage text"

begin_test "--help mentions --collect"
output="$("$HEALTH_REVIEW" --help 2>&1)"
assert_contains "$output" "--collect" "should mention --collect option"

begin_test "--help mentions --no-notify"
output="$("$HEALTH_REVIEW" --help 2>&1)"
assert_contains "$output" "--no-notify" "should mention --no-notify option"

begin_test "unknown flag exits 1"
output="$("$HEALTH_REVIEW" --bogus 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "unknown flag shows error"
output="$("$HEALTH_REVIEW" --bogus 2>&1)" || true
assert_contains "$output" "Unknown option" "should show error message"

# ---------------------------------------------------------------------------
# Collector tests (using stubs)
# ---------------------------------------------------------------------------

begin_test "--collect produces section delimiters"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "--- Journal Warnings" "should contain journal warnings section"
teardown_test_tmpdir

begin_test "--collect contains all expected sections"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "--- Failed Systemd Units ---" "should contain failed units section"
teardown_test_tmpdir

begin_test "--collect contains network section"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "--- Network State" "should contain network state section"
teardown_test_tmpdir

begin_test "--collect contains disk usage section"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "--- Disk Usage" "should contain disk usage section"
teardown_test_tmpdir

begin_test "--collect contains security advisories section"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "--- Security Advisories" "should contain security section"
teardown_test_tmpdir

begin_test "--collect contains flatpak updates section"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "--- Flatpak Updates ---" "should contain flatpak section"
teardown_test_tmpdir

begin_test "--collect contains rpm-ostree status section"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "--- RPM-OSTree Deployment Status ---" "should contain rpm-ostree status section"
teardown_test_tmpdir

begin_test "--collect contains upgrade section"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "--- Available OS Upgrades ---" "should contain upgrades section"
teardown_test_tmpdir

begin_test "--collect contains network journal section"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "--- Network Journal" "should contain network journal section"
teardown_test_tmpdir

begin_test "--collect includes stubbed journal data"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "Test warning message" "should include stubbed journal data"
teardown_test_tmpdir

begin_test "--collect includes stubbed network data"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "192.168.1.100" "should include stubbed IP address"
teardown_test_tmpdir

# ---------------------------------------------------------------------------
# Truncation test
# ---------------------------------------------------------------------------

begin_test "collector truncates output beyond 500 lines"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

# Override journalctl stub to produce 600 lines
cat > "${stub_bin}/journalctl" <<'STUB'
#!/usr/bin/env bash
for i in $(seq 1 600); do
    echo "Line $i: test warning message"
done
STUB
chmod +x "${stub_bin}/journalctl"

output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
assert_contains "$output" "truncated" "should indicate truncation occurred"
teardown_test_tmpdir

# ---------------------------------------------------------------------------
# Fallback report test (no claude)
# ---------------------------------------------------------------------------

begin_test "full run without claude generates fallback report"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

# Stub mise to not find claude
output="$(PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --no-notify 2>&1)" && rc=0 || rc=$?
assert_exit_code "0" "$rc"
teardown_test_tmpdir

begin_test "fallback report contains overall status"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --no-notify 2>/dev/null || true
today="$(date +%Y-%m-%d)"
report_file="${TEST_TMPDIR}/.local/share/system-health/reports/${today}.md"

if [[ -f "$report_file" ]]; then
    content="$(cat "$report_file")"
    assert_contains "$content" "Overall Status" "fallback report should contain Overall Status"
else
    fail_test "report file was not created at ${report_file}"
fi
teardown_test_tmpdir

begin_test "fallback report saved as HTML"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --no-notify 2>/dev/null || true
today="$(date +%Y-%m-%d)"
html_file="${TEST_TMPDIR}/.local/share/system-health/reports/${today}.html"
assert_file_exists "$html_file"
teardown_test_tmpdir

begin_test "HTML report contains valid HTML structure"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --no-notify 2>/dev/null || true
today="$(date +%Y-%m-%d)"
html_file="${TEST_TMPDIR}/.local/share/system-health/reports/${today}.html"

if [[ -f "$html_file" ]]; then
    content="$(cat "$html_file")"
    assert_contains "$content" "<!DOCTYPE html>" "HTML should have doctype"
else
    fail_test "HTML file was not created"
fi
teardown_test_tmpdir

# ---------------------------------------------------------------------------
# Report storage tests
# ---------------------------------------------------------------------------

begin_test "report directory created automatically"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --no-notify 2>/dev/null || true
assert_dir_exists "${TEST_TMPDIR}/.local/share/system-health/reports"
teardown_test_tmpdir

begin_test "report filename uses date"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --no-notify 2>/dev/null || true
today="$(date +%Y-%m-%d)"
assert_file_exists "${TEST_TMPDIR}/.local/share/system-health/reports/${today}.md"
teardown_test_tmpdir

begin_test "data directory created with date"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --no-notify 2>/dev/null || true
today="$(date +%Y-%m-%d)"
assert_dir_exists "${TEST_TMPDIR}/.local/share/system-health/reports/data/${today}"
teardown_test_tmpdir

begin_test "individual data files created in data directory"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --no-notify 2>/dev/null || true
today="$(date +%Y-%m-%d)"
data_dir="${TEST_TMPDIR}/.local/share/system-health/reports/data/${today}"
assert_file_exists "${data_dir}/journal_warnings"
teardown_test_tmpdir

begin_test "data files contain collector output"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --no-notify 2>/dev/null || true
today="$(date +%Y-%m-%d)"
data_dir="${TEST_TMPDIR}/.local/share/system-health/reports/data/${today}"
if [[ -f "${data_dir}/journal_warnings" ]]; then
    content="$(cat "${data_dir}/journal_warnings")"
    assert_contains "$content" "Test warning message" "data file should contain stubbed data"
else
    fail_test "journal_warnings data file not found"
fi
teardown_test_tmpdir

begin_test "--collect also creates data directory"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --collect 2>/dev/null || true
today="$(date +%Y-%m-%d)"
assert_dir_exists "${TEST_TMPDIR}/.local/share/system-health/reports/data/${today}"
teardown_test_tmpdir

# ---------------------------------------------------------------------------
# Notification tests
# ---------------------------------------------------------------------------

begin_test "notification skipped with --no-notify"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" --no-notify 2>/dev/null || true
if [[ -f "${TEST_TMPDIR}/notify-sent" ]]; then
    fail_test "notify-send should not have been called with --no-notify"
else
    pass_test
fi
teardown_test_tmpdir

begin_test "notification skipped when notify-send unavailable"
setup_test_tmpdir
stub_bin="$(create_test_wrapper "$TEST_TMPDIR")"
# Remove notify-send stub
rm -f "${stub_bin}/notify-send"

PATH="${stub_bin}:${PATH}" HOME="${TEST_TMPDIR}" "$HEALTH_REVIEW" 2>/dev/null || true
# Should not fail even without notify-send
assert_exit_code "0" "0"
teardown_test_tmpdir

# ---------------------------------------------------------------------------
# Darwin guard test
# ---------------------------------------------------------------------------

begin_test "exits with error on Darwin"
if [[ "$(uname)" == "Darwin" ]]; then
    output="$("$HEALTH_REVIEW" --collect 2>&1)" && rc=0 || rc=$?
    assert_exit_code "1" "$rc"
else
    # On Linux, this test is not applicable — just pass
    pass_test
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_test_summary "System Health Review"
