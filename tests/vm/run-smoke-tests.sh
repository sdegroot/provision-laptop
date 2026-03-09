#!/usr/bin/env bash
# run-smoke-tests.sh — Run smoke tests against a running VM.
#
# Prerequisites: VM must be running and accessible via SSH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VM_SSH_PORT="${VM_SSH_PORT:-2222}"
VM_USER="${VM_USER:-sdegroot}"
VM_PASSWORD="${VM_PASSWORD:-changeme}"

# Disable identity agent to prevent 1Password SSH agent from exhausting auth
# attempts before password auth can be tried.
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o IdentityAgent=none -o IdentitiesOnly=yes"

if command -v sshpass &>/dev/null; then
    SSH_CMD="sshpass -p ${VM_PASSWORD} ssh ${SSH_OPTS} -p ${VM_SSH_PORT} ${VM_USER}@localhost"
else
    echo "WARNING: sshpass not found — SSH may prompt for password (install: brew install sshpass)"
    SSH_CMD="ssh ${SSH_OPTS} -p ${VM_SSH_PORT} ${VM_USER}@localhost"
fi

TESTS_DIR="${SCRIPT_DIR}/../smoke"
pass_count=0
fail_count=0

echo "========================================"
echo "  Smoke Tests — VM at localhost:${VM_SSH_PORT}"
echo "========================================"
echo ""

# Verify SSH connectivity
echo "Checking SSH connectivity..."
if ! $SSH_CMD "echo ok" &>/dev/null; then
    echo "ERROR: Cannot connect to VM via SSH"
    echo "Ensure the VM is running: make vm-start"
    exit 1
fi
echo "SSH connection OK"
echo ""

# Run each smoke test
for test_file in "${TESTS_DIR}"/test_*.sh; do
    [[ -f "$test_file" ]] || continue

    test_name="$(basename "$test_file" .sh)"
    echo "--- Running: ${test_name} ---"

    exit_code=0
    # Copy and run the test on the VM
    $SSH_CMD "bash -s" < "$test_file" 2>&1 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "  PASS: ${test_name}"
        (( pass_count++ ))
    else
        echo "  FAIL: ${test_name} (exit code: ${exit_code})"
        (( fail_count++ ))
    fi
    echo ""
done

echo "========================================"
echo "  Smoke Tests: ${pass_count} passed, ${fail_count} failed"
echo "========================================"

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
