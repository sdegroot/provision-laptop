#!/usr/bin/env bash
# repos/apply.sh — Configure third-party repos.
#
# Silverblue does not ship dnf — repo management uses:
#   - curl to download .repo files into /etc/yum.repos.d/
#   - rpm-ostree install for RPM Fusion release packages
#   - COPR .repo files via the Fedora COPR API

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "repos.conf")"
changes_made=0

if ! is_silverblue; then
    log_warn "Not running on Silverblue — skipping repos apply"
    exit 0
fi

fedora_version="$(rpm -E %fedora)"

# Check if a repo is already present by looking for .repo files or rpm-ostree packages
repo_exists() {
    local name="$1"
    # Check /etc/yum.repos.d/ for matching .repo files
    ls /etc/yum.repos.d/*"${name}"* &>/dev/null 2>&1 || \
    grep -rql "\[.*${name}.*\]" /etc/yum.repos.d/ &>/dev/null 2>&1
}

while IFS= read -r line; do
    read -r repo_type repo_arg <<< "$line"

    case "$repo_type" in
        repofile)
            repo_name="$(basename "$repo_arg" .repo)"
            if ! repo_exists "$repo_name"; then
                log_info "Adding repo from: ${repo_arg}"
                sudo curl -fsSL -o "/etc/yum.repos.d/${repo_name}.repo" "$repo_arg"
                changes_made=1
            fi
            ;;
        rpmfusion-free)
            if ! repo_exists "rpmfusion-free"; then
                log_info "Adding RPM Fusion Free"
                sudo rpm-ostree install --idempotent --allow-inactive \
                    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm"
                changes_made=1
            fi
            ;;
        rpmfusion-nonfree)
            if ! repo_exists "rpmfusion-nonfree"; then
                log_info "Adding RPM Fusion Non-Free"
                sudo rpm-ostree install --idempotent --allow-inactive \
                    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"
                changes_made=1
            fi
            ;;
        copr)
            copr_owner="$(echo "$repo_arg" | cut -d/ -f1)"
            copr_project="$(echo "$repo_arg" | cut -d/ -f2)"
            if ! repo_exists "${copr_owner}.*${copr_project}" && \
               ! repo_exists "_copr.*${copr_owner}.*${copr_project}"; then
                log_info "Enabling COPR: ${repo_arg}"
                # Download .repo file directly from COPR API (no dnf needed)
                copr_repo_url="https://copr.fedorainfracloud.org/coprs/${copr_owner}/${copr_project}/repo/fedora-${fedora_version}/${copr_owner}-${copr_project}-fedora-${fedora_version}.repo"
                sudo curl -fsSL -o "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${copr_owner}:${copr_project}.repo" "$copr_repo_url"
                changes_made=1
            fi
            ;;
        *)
            log_error "Unknown repo type: ${repo_type}"
            exit 1
            ;;
    esac
done < <(parse_state_file "$STATE_FILE")

# VA-API freeworld override (x86_64 only — needs hardware GPU)
if [[ "$(current_arch)" == "x86_64" ]]; then
    if ! rpm -q mesa-va-drivers-freeworld &>/dev/null; then
        log_info "Swapping mesa VA-API/VDPAU drivers for freeworld versions"
        rpm-ostree override remove mesa-va-drivers --install mesa-va-drivers-freeworld 2>/dev/null || true
        rpm-ostree override remove mesa-vdpau-drivers --install mesa-vdpau-drivers-freeworld 2>/dev/null || true
        changes_made=1
    fi
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "All repos already configured"
else
    log_ok "Repos applied (reboot may be required)"
fi
