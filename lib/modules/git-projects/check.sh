#!/usr/bin/env bash
# git-projects/check.sh — Verify git repositories are cloned.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

STATE_FILE="$(state_file_path "git-projects.conf")"
drift_found=0

if [[ ! -f "$STATE_FILE" ]]; then
    log_warn "No git-projects.conf found — skipping"
    exit 0
fi

while IFS= read -r url; do
    target="$(clone_url_to_path "$url")"

    if [[ -d "$target/.git" ]]; then
        log_ok "Cloned: ${target}"
    else
        log_error "Missing: ${target} (from ${url})"
        drift_found=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $drift_found -eq 0 ]]; then
    log_ok "All git projects match desired state"
fi

exit $drift_found
