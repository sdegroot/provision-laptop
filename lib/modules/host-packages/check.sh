#!/usr/bin/env bash
# host-packages/check.sh — Verify all desired host packages are layered.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "host-packages.txt")"
drift_found=0

if ! is_silverblue; then
    log_warn "Not running on Silverblue — skipping host-packages check"
    exit 0
fi

# Get list of layered packages from rpm-ostree
layered="$(get_layered_packages)"

while IFS= read -r pkg; do
    if echo "$layered" | grep -q "^${pkg}$"; then
        log_ok "Layered: ${pkg}"
    else
        log_error "Missing: ${pkg}"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All host packages match desired state"
fi

exit $drift_found
