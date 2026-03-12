#!/usr/bin/env bash
# repos/common.sh — Shared helpers for the repos module.
#
# Sourced by apply.sh, check.sh, and plan.sh. Assumes lib/common.sh is
# already loaded (provides PROVISION_ROOT, logging, etc.).

# repo_exists <name>
#   Check if a repo is present by scanning /etc/yum.repos.d/ for matching
#   .repo files or section headers.
repo_exists() {
    local name="$1"
    local repo_dir="${PROVISION_ROOT:-}/etc/yum.repos.d"
    ls "${repo_dir}"/*"${name}"* &>/dev/null 2>&1 || \
    grep -rql "\[.*${name}.*\]" "${repo_dir}/" &>/dev/null 2>&1
}

# check_freeworld_present
#   Returns 0 if mesa-va-drivers-freeworld is installed or pending in a
#   staged rpm-ostree deployment, 1 otherwise.
check_freeworld_present() {
    rpm -q mesa-va-drivers-freeworld &>/dev/null && return 0
    rpm-ostree status --json 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
for dep in data.get("deployments", []):
    pkgs = dep.get("requested-packages", [])
    removals = [r if isinstance(r, str) else r.get("name","") for r in dep.get("base-removals", [])]
    if "mesa-va-drivers-freeworld" in pkgs or "mesa-va-drivers" in removals:
        sys.exit(0)
sys.exit(1)
' 2>/dev/null
}
