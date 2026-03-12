#!/usr/bin/env bash
# host-packages/apply.sh — Install missing host packages via rpm-ostree.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "host-packages.txt")"

if ! is_silverblue; then
    log_warn "Not running on Silverblue — skipping host-packages apply"
    exit 0
fi

# Collect packages to install
missing_pkgs=()

layered="$(get_layered_packages)"

while IFS= read -r pkg; do
    if ! echo "$layered" | grep -q "^${pkg}$"; then
        missing_pkgs+=("$pkg")
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
    log_ok "All host packages already layered"
    exit 0
fi

wait_for_rpm_ostree
log_info "Installing ${#missing_pkgs[@]} packages: ${missing_pkgs[*]}"
if ! sudo rpm-ostree install --idempotent --allow-inactive "${missing_pkgs[@]}"; then
    log_error "rpm-ostree install failed for: ${missing_pkgs[*]}"
    exit 1
fi
log_ok "Host packages applied (reboot may be required)"
