#!/usr/bin/env bash
# test_system_basics.sh — Verify basic system state.
set -euo pipefail

echo "Checking system basics..."

# Verify we're on Silverblue
if [[ ! -x /usr/bin/rpm-ostree ]]; then
    echo "FAIL: Not running on Silverblue"
    exit 1
fi
echo "  OK: Running on Silverblue"

# Verify SELinux is enforcing
selinux_mode="$(getenforce 2>/dev/null || echo "unknown")"
if [[ "$selinux_mode" != "Enforcing" ]]; then
    echo "FAIL: SELinux is ${selinux_mode} (expected Enforcing)"
    exit 1
fi
echo "  OK: SELinux is enforcing"

# Verify firewall is active
if ! systemctl is-active firewalld &>/dev/null; then
    echo "FAIL: Firewall is not active"
    exit 1
fi
echo "  OK: Firewall is active"

# Verify SSH is running
if ! systemctl is-active sshd &>/dev/null; then
    echo "FAIL: SSH is not active"
    exit 1
fi
echo "  OK: SSH is active"

echo "System basics: OK"
