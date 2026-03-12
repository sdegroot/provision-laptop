#!/usr/bin/env bash
# repos/check.sh — Verify all third-party repos are configured.
#
# Checks /etc/yum.repos.d/ for repo presence (works on Silverblue without dnf).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

STATE_FILE="$(state_file_path "repos.conf")"
drift_found=0

if ! is_silverblue; then
    log_warn "Not running on Silverblue — skipping repos check"
    exit 0
fi

while IFS= read -r line; do
    read -r repo_type repo_arg <<< "$line"

    case "$repo_type" in
        repofile)
            repo_name="$(basename "$repo_arg" .repo)"
            if repo_exists "$repo_name"; then
                log_ok "Repo present: ${repo_name}"
            else
                log_error "Missing repo: ${repo_name} (from ${repo_arg})"
                drift_found=1
            fi
            ;;
        copr)
            copr_owner="$(echo "$repo_arg" | cut -d/ -f1)"
            copr_project="$(echo "$repo_arg" | cut -d/ -f2)"
            if repo_exists "${copr_owner}.*${copr_project}" || \
               repo_exists "_copr.*${copr_owner}.*${copr_project}"; then
                log_ok "COPR present: ${repo_arg}"
            else
                log_error "Missing COPR: ${repo_arg}"
                drift_found=1
            fi
            ;;
        *)
            log_error "Unknown repo type: ${repo_type}"
            drift_found=1
            ;;
    esac
done < <(parse_state_file "$STATE_FILE")

# Check VA-API freeworld override (x86_64 only — needs hardware GPU)
if [[ "$(current_arch)" == "x86_64" ]]; then
    if check_freeworld_present; then
        log_ok "VA-API freeworld drivers installed"
    else
        log_error "Missing VA-API freeworld drivers (mesa override needed)"
        drift_found=1
    fi
fi

# Check base-image package removals
BASE_REMOVALS_FILE="$(state_file_path "base-removals.txt")"
if [[ -f "$BASE_REMOVALS_FILE" ]]; then
    current_removals="$(rpm-ostree status --json 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
for dep in data.get("deployments", []):
    for r in dep.get("base-removals", []):
        print(r if isinstance(r, str) else r.get("name",""))
' 2>/dev/null)"

    while IFS= read -r pkg; do
        if echo "$current_removals" | grep -qx "$pkg"; then
            log_ok "Base package removed: ${pkg}"
        elif ! rpm -q "$pkg" &>/dev/null; then
            log_ok "Base package removed: ${pkg}"
        else
            log_error "Base package should be removed: ${pkg}"
            drift_found=1
        fi
    done < <(parse_state_file "$BASE_REMOVALS_FILE")
fi

if [[ $drift_found -eq 0 ]]; then
    log_ok "All repos match desired state"
fi

exit $drift_found
