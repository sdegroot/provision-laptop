#!/usr/bin/env bash
# test_ai_sandbox.sh — Tests for bin/ai-sandbox argument parsing and validation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helpers.sh"
PROVISION_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

AI_SANDBOX="${PROVISION_DIR}/bin/ai-sandbox"

# ---------------------------------------------------------------------------
# Argument parsing tests
# ---------------------------------------------------------------------------

begin_test "missing --agent shows error"
output="$("$AI_SANDBOX" --project /tmp --prompt "test" 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "missing --project shows error"
output="$("$AI_SANDBOX" --agent claude --prompt "test" 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "missing --prompt shows error"
output="$("$AI_SANDBOX" --agent claude --project /tmp 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "invalid agent name shows error"
output="$("$AI_SANDBOX" --agent invalid --project /tmp --prompt "test" 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "invalid agent error mentions valid options"
output="$("$AI_SANDBOX" --agent invalid --project /tmp --prompt "test" 2>&1)" || true
assert_contains "$output" "claude" "should mention claude as valid agent"

begin_test "nonexistent project shows error"
output="$("$AI_SANDBOX" --agent claude --project /nonexistent/path --prompt "test" 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "unknown option shows error"
output="$("$AI_SANDBOX" --agent claude --project /tmp --prompt "test" --bogus 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"

begin_test "--help exits 0"
output="$("$AI_SANDBOX" --help 2>&1)" && rc=0 || rc=$?
assert_exit_code "0" "$rc"

begin_test "--help shows usage"
output="$("$AI_SANDBOX" --help 2>&1)"
assert_contains "$output" "Usage:" "should show usage text"

begin_test "--help mentions all agents"
output="$("$AI_SANDBOX" --help 2>&1)"
assert_contains "$output" "claude" "should mention claude"

# ---------------------------------------------------------------------------
# Env file validation tests
# ---------------------------------------------------------------------------

begin_test "missing env file shows error"
setup_test_tmpdir
# Override HOME so the env file path resolves to a nonexistent location
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" --agent claude --project /tmp --prompt "test" 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"
teardown_test_tmpdir

begin_test "missing env file error mentions path"
setup_test_tmpdir
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" --agent claude --project /tmp --prompt "test" 2>&1)" || true
assert_contains "$output" "ai-sandbox/env" "should mention the env file path"
teardown_test_tmpdir

begin_test "env file with wrong permissions shows error"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0644 "${TEST_TMPDIR}/.config/ai-sandbox/env"
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" --agent claude --project /tmp --prompt "test" 2>&1)" && rc=0 || rc=$?
assert_exit_code "1" "$rc"
teardown_test_tmpdir

begin_test "env file permission error mentions 0600"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0644 "${TEST_TMPDIR}/.config/ai-sandbox/env"
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" --agent claude --project /tmp --prompt "test" 2>&1)" || true
assert_contains "$output" "0600" "should mention expected permissions"
teardown_test_tmpdir

# ---------------------------------------------------------------------------
# Dry run tests — validate command construction
# ---------------------------------------------------------------------------

begin_test "dry run with claude agent produces correct command"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0600 "${TEST_TMPDIR}/.config/ai-sandbox/env"
# Create a fake git repo as the project
mkdir -p "${TEST_TMPDIR}/project"
git -C "${TEST_TMPDIR}/project" init -b main --quiet
git -C "${TEST_TMPDIR}/project" commit --allow-empty -m "init" --quiet
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" \
    --agent claude \
    --project "${TEST_TMPDIR}/project" \
    --prompt "test prompt" \
    --no-worktree \
    --dry-run 2>&1)" && rc=0 || rc=$?
assert_exit_code "0" "$rc"
teardown_test_tmpdir

begin_test "dry run includes security flags"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0600 "${TEST_TMPDIR}/.config/ai-sandbox/env"
mkdir -p "${TEST_TMPDIR}/project"
git -C "${TEST_TMPDIR}/project" init -b main --quiet
git -C "${TEST_TMPDIR}/project" commit --allow-empty -m "init" --quiet
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" \
    --agent claude \
    --project "${TEST_TMPDIR}/project" \
    --prompt "test" \
    --no-worktree \
    --dry-run 2>&1)"
assert_contains "$output" "--cap-drop=ALL" "should include cap-drop"
teardown_test_tmpdir

begin_test "dry run includes no-new-privileges"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0600 "${TEST_TMPDIR}/.config/ai-sandbox/env"
mkdir -p "${TEST_TMPDIR}/project"
git -C "${TEST_TMPDIR}/project" init -b main --quiet
git -C "${TEST_TMPDIR}/project" commit --allow-empty -m "init" --quiet
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" \
    --agent claude \
    --project "${TEST_TMPDIR}/project" \
    --prompt "test" \
    --no-worktree \
    --dry-run 2>&1)"
assert_contains "$output" "no-new-privileges" "should include no-new-privileges"
teardown_test_tmpdir

begin_test "dry run includes read-only rootfs"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0600 "${TEST_TMPDIR}/.config/ai-sandbox/env"
mkdir -p "${TEST_TMPDIR}/project"
git -C "${TEST_TMPDIR}/project" init -b main --quiet
git -C "${TEST_TMPDIR}/project" commit --allow-empty -m "init" --quiet
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" \
    --agent claude \
    --project "${TEST_TMPDIR}/project" \
    --prompt "test" \
    --no-worktree \
    --dry-run 2>&1)"
assert_contains "$output" "--read-only" "should include read-only flag"
teardown_test_tmpdir

begin_test "dry run includes memory limit"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0600 "${TEST_TMPDIR}/.config/ai-sandbox/env"
mkdir -p "${TEST_TMPDIR}/project"
git -C "${TEST_TMPDIR}/project" init -b main --quiet
git -C "${TEST_TMPDIR}/project" commit --allow-empty -m "init" --quiet
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" \
    --agent claude \
    --project "${TEST_TMPDIR}/project" \
    --prompt "test" \
    --memory 16g \
    --no-worktree \
    --dry-run 2>&1)"
assert_contains "$output" "--memory=16g" "should include configured memory limit"
teardown_test_tmpdir

begin_test "dry run includes claude agent command"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0600 "${TEST_TMPDIR}/.config/ai-sandbox/env"
mkdir -p "${TEST_TMPDIR}/project"
git -C "${TEST_TMPDIR}/project" init -b main --quiet
git -C "${TEST_TMPDIR}/project" commit --allow-empty -m "init" --quiet
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" \
    --agent claude \
    --project "${TEST_TMPDIR}/project" \
    --prompt "do something" \
    --no-worktree \
    --dry-run 2>&1)"
assert_contains "$output" "--dangerously-skip-permissions" "should include claude skip-permissions flag"
teardown_test_tmpdir

begin_test "dry run includes codex agent command"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0600 "${TEST_TMPDIR}/.config/ai-sandbox/env"
mkdir -p "${TEST_TMPDIR}/project"
git -C "${TEST_TMPDIR}/project" init -b main --quiet
git -C "${TEST_TMPDIR}/project" commit --allow-empty -m "init" --quiet
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" \
    --agent codex \
    --project "${TEST_TMPDIR}/project" \
    --prompt "do something" \
    --no-worktree \
    --dry-run 2>&1)"
assert_contains "$output" "full-auto" "should include codex full-auto flag"
teardown_test_tmpdir

begin_test "dry run includes pids-limit"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0600 "${TEST_TMPDIR}/.config/ai-sandbox/env"
mkdir -p "${TEST_TMPDIR}/project"
git -C "${TEST_TMPDIR}/project" init -b main --quiet
git -C "${TEST_TMPDIR}/project" commit --allow-empty -m "init" --quiet
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" \
    --agent claude \
    --project "${TEST_TMPDIR}/project" \
    --prompt "test" \
    --no-worktree \
    --dry-run 2>&1)"
assert_contains "$output" "--pids-limit=256" "should include pids limit"
teardown_test_tmpdir

begin_test "dry run includes git identity env vars"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0600 "${TEST_TMPDIR}/.config/ai-sandbox/env"
mkdir -p "${TEST_TMPDIR}/project"
git -C "${TEST_TMPDIR}/project" init -b main --quiet
git -C "${TEST_TMPDIR}/project" commit --allow-empty -m "init" --quiet
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" \
    --agent claude \
    --project "${TEST_TMPDIR}/project" \
    --prompt "test" \
    --no-worktree \
    --dry-run 2>&1)"
assert_contains "$output" "GIT_AUTHOR_NAME=AI Sandbox (claude)" "should set git author"
teardown_test_tmpdir

begin_test "dry run includes timeout"
setup_test_tmpdir
mkdir -p "${TEST_TMPDIR}/.config/ai-sandbox"
echo "ANTHROPIC_API_KEY=test" > "${TEST_TMPDIR}/.config/ai-sandbox/env"
chmod 0600 "${TEST_TMPDIR}/.config/ai-sandbox/env"
mkdir -p "${TEST_TMPDIR}/project"
git -C "${TEST_TMPDIR}/project" init -b main --quiet
git -C "${TEST_TMPDIR}/project" commit --allow-empty -m "init" --quiet
output="$(HOME="${TEST_TMPDIR}" "$AI_SANDBOX" \
    --agent claude \
    --project "${TEST_TMPDIR}/project" \
    --prompt "test" \
    --timeout 1h \
    --no-worktree \
    --dry-run 2>&1)"
assert_contains "$output" "timeout 1h" "should include configured timeout"
teardown_test_tmpdir

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_test_summary "AI Sandbox"
