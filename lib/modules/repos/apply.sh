#!/usr/bin/env bash
# repos/apply.sh — Configure third-party repos.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "repos.conf")"
changes_made=0

if ! is_silverblue; then
    log_warn "Not running on Silverblue — skipping repos apply"
    exit 0
fi

enabled_repos="$(dnf repolist --enabled 2>/dev/null | tail -n +2 || true)"
fedora_version="$(rpm -E %fedora)"

while IFS= read -r line; do
    read -r repo_type repo_arg <<< "$line"

    case "$repo_type" in
        repofile)
            repo_name="$(basename "$repo_arg" .repo)"
            if ! echo "$enabled_repos" | grep -qi "$repo_name"; then
                log_info "Adding repo from: ${repo_arg}"
                sudo dnf config-manager addrepo --from-repofile="$repo_arg"
                changes_made=1
            fi
            ;;
        rpmfusion-free)
            if ! echo "$enabled_repos" | grep -q "rpmfusion-free"; then
                log_info "Adding RPM Fusion Free"
                sudo rpm-ostree install --idempotent --allow-inactive \
                    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm"
                changes_made=1
            fi
            ;;
        rpmfusion-nonfree)
            if ! echo "$enabled_repos" | grep -q "rpmfusion-nonfree"; then
                log_info "Adding RPM Fusion Non-Free"
                sudo rpm-ostree install --idempotent --allow-inactive \
                    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"
                changes_made=1
            fi
            ;;
        copr)
            copr_owner="$(echo "$repo_arg" | cut -d/ -f1)"
            copr_project="$(echo "$repo_arg" | cut -d/ -f2)"
            if ! echo "$enabled_repos" | grep -q "${copr_owner}.*${copr_project}"; then
                log_info "Enabling COPR: ${repo_arg}"
                sudo dnf copr enable "$repo_arg" -y
                changes_made=1
            fi
            ;;
        *)
            log_error "Unknown repo type: ${repo_type}"
            exit 1
            ;;
    esac
done < <(parse_state_file "$STATE_FILE")

# VA-API freeworld override (swap mesa drivers for freeworld versions)
if ! rpm -q mesa-va-drivers-freeworld &>/dev/null; then
    log_info "Swapping mesa VA-API/VDPAU drivers for freeworld versions"
    rpm-ostree override remove mesa-va-drivers --install mesa-va-drivers-freeworld 2>/dev/null || true
    rpm-ostree override remove mesa-vdpau-drivers --install mesa-vdpau-drivers-freeworld 2>/dev/null || true
    changes_made=1
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "All repos already configured"
else
    log_ok "Repos applied (reboot may be required)"
fi
