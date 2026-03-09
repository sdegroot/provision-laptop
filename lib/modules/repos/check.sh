#!/usr/bin/env bash
# repos/check.sh — Verify all third-party repos are configured.
#
# Checks /etc/yum.repos.d/ for repo presence (works on Silverblue without dnf).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "repos.conf")"
drift_found=0

if ! is_silverblue; then
    log_warn "Not running on Silverblue — skipping repos check"
    exit 0
fi

# Check if a repo is present by scanning /etc/yum.repos.d/
repo_exists() {
    local name="$1"
    local repo_dir="${PROVISION_ROOT}/etc/yum.repos.d"
    ls "${repo_dir}"/*"${name}"* &>/dev/null 2>&1 || \
    grep -rql "\[.*${name}.*\]" "${repo_dir}/" &>/dev/null 2>&1
}

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
        rpmfusion-free)
            if repo_exists "rpmfusion-free"; then
                log_ok "Repo present: rpmfusion-free"
            else
                log_error "Missing repo: rpmfusion-free"
                drift_found=1
            fi
            ;;
        rpmfusion-nonfree)
            if repo_exists "rpmfusion-nonfree"; then
                log_ok "Repo present: rpmfusion-nonfree"
            else
                log_error "Missing repo: rpmfusion-nonfree"
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

# Check VA-API freeworld override
if rpm -q mesa-va-drivers-freeworld &>/dev/null; then
    log_ok "VA-API freeworld drivers installed"
else
    log_error "Missing VA-API freeworld drivers (mesa override needed)"
    drift_found=1
fi

if [[ $drift_found -eq 0 ]]; then
    log_ok "All repos match desired state"
fi

exit $drift_found
