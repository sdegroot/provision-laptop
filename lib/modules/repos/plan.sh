#!/usr/bin/env bash
# repos/plan.sh — Show planned repo changes (dry-run).
#
# Checks /etc/yum.repos.d/ for repo presence (works on Silverblue without dnf).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "repos.conf")"
changes_planned=0

if ! is_silverblue; then
    log_warn "Not running on Silverblue — skipping repos plan"
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
            if ! repo_exists "$repo_name"; then
                log_plan "Would add repo: ${repo_name} (from ${repo_arg})"
                changes_planned=1
            fi
            ;;
        rpmfusion-free)
            if ! repo_exists "rpmfusion-free"; then
                log_plan "Would add RPM Fusion Free"
                changes_planned=1
            fi
            ;;
        rpmfusion-nonfree)
            if ! repo_exists "rpmfusion-nonfree"; then
                log_plan "Would add RPM Fusion Non-Free"
                changes_planned=1
            fi
            ;;
        copr)
            copr_owner="$(echo "$repo_arg" | cut -d/ -f1)"
            copr_project="$(echo "$repo_arg" | cut -d/ -f2)"
            if ! repo_exists "${copr_owner}.*${copr_project}" && \
               ! repo_exists "_copr.*${copr_owner}.*${copr_project}"; then
                log_plan "Would enable COPR: ${repo_arg}"
                changes_planned=1
            fi
            ;;
    esac
done < <(parse_state_file "$STATE_FILE")

if ! rpm -q mesa-va-drivers-freeworld &>/dev/null 2>&1; then
    log_plan "Would swap mesa VA-API/VDPAU drivers for freeworld versions"
    changes_planned=1
fi

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No repo changes needed"
fi
