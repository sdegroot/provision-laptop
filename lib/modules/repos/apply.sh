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
has_errors=0

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

# Check if a local repofile needs updating (content differs from system copy)
repo_needs_update() {
    local local_path="$1"
    local system_path="$2"
    if [[ ! -f "$system_path" ]]; then
        return 0  # needs update (missing)
    fi
    if ! diff -q "$local_path" "$system_path" &>/dev/null; then
        return 0  # needs update (content differs)
    fi
    return 1  # up to date
}

while IFS= read -r line; do
    read -r repo_type repo_arg <<< "$line"

    case "$repo_type" in
        repofile)
            repo_name="$(basename "$repo_arg" .repo)"
            system_path="/etc/yum.repos.d/${repo_name}.repo"

            if [[ "$repo_arg" == http://* || "$repo_arg" == https://* ]]; then
                if ! repo_exists "$repo_name"; then
                    log_info "Adding repo from: ${repo_arg}"
                    if sudo curl -fsSL -o "$system_path" "$repo_arg"; then
                        changes_made=1
                    else
                        log_error "Failed to download repo: ${repo_arg}"
                        has_errors=1
                    fi
                fi
            else
                # Local path relative to state directory
                local_path="$(dirname "$STATE_FILE")/${repo_arg}"
                if ! repo_exists "$repo_name" || repo_needs_update "$local_path" "$system_path"; then
                    log_info "Deploying repo file: ${repo_arg}"
                    if sudo cp "$local_path" "$system_path"; then
                        changes_made=1
                    else
                        log_error "Failed to copy repo file: ${local_path}"
                        has_errors=1
                    fi
                fi
            fi
            ;;
        rpmfusion-free)
            if ! repo_exists "rpmfusion-free"; then
                log_info "Adding RPM Fusion Free"
                if ! sudo rpm-ostree install --idempotent --allow-inactive \
                    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm"; then
                    log_error "Failed to install RPM Fusion Free"
                    has_errors=1
                else
                    changes_made=1
                fi
            fi
            ;;
        rpmfusion-nonfree)
            if ! repo_exists "rpmfusion-nonfree"; then
                log_info "Adding RPM Fusion Non-Free"
                if ! sudo rpm-ostree install --idempotent --allow-inactive \
                    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"; then
                    log_error "Failed to install RPM Fusion Non-Free"
                    has_errors=1
                else
                    changes_made=1
                fi
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
                if ! sudo curl -fsSL -o "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${copr_owner}:${copr_project}.repo" "$copr_repo_url"; then
                    log_error "Failed to download COPR repo: ${repo_arg}"
                    has_errors=1
                else
                    changes_made=1
                fi
            fi
            ;;
        *)
            log_error "Unknown repo type: ${repo_type}"
            has_errors=1
            ;;
    esac
done < <(parse_state_file "$STATE_FILE")

# VA-API freeworld override (x86_64 only — needs hardware GPU)
if [[ "$(current_arch)" == "x86_64" ]]; then
    # Check installed packages AND pending deployments for freeworld drivers
    freeworld_present=false
    if rpm -q mesa-va-drivers-freeworld &>/dev/null; then
        freeworld_present=true
    elif rpm-ostree status --json 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
for dep in data.get("deployments", []):
    pkgs = dep.get("requested-packages", [])
    removals = [r if isinstance(r, str) else r.get("name","") for r in dep.get("base-removals", [])]
    if "mesa-va-drivers-freeworld" in pkgs or "mesa-va-drivers" in removals:
        sys.exit(0)
sys.exit(1)
' 2>/dev/null; then
        freeworld_present=true
    fi

    if ! $freeworld_present; then
        log_info "Swapping mesa VA-API/VDPAU drivers for freeworld versions"
        if ! sudo rpm-ostree override remove mesa-va-drivers mesa-vdpau-drivers \
                --install mesa-va-drivers-freeworld --install mesa-vdpau-drivers-freeworld; then
            log_error "Failed to override mesa drivers with freeworld versions"
            has_errors=1
        else
            changes_made=1
        fi
    fi
fi

if [[ $has_errors -ne 0 ]]; then
    log_error "Repos apply completed with errors"
    exit 1
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "All repos already configured"
else
    log_ok "Repos applied (reboot may be required)"
fi
