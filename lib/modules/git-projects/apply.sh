#!/usr/bin/env bash
# git-projects/apply.sh — Clone git repositories.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

STATE_FILE="$(state_file_path "git-projects.conf")"
changes_made=0
has_errors=0

if [[ ! -f "$STATE_FILE" ]]; then
    log_warn "No git-projects.conf found — skipping"
    exit 0
fi

while IFS= read -r url; do
    target="$(clone_url_to_path "$url")"

    if [[ -d "$target/.git" ]]; then
        continue
    fi

    log_info "Cloning: ${url} -> ${target}"
    mkdir -p "$(dirname "$target")"
    if git clone "$url" "$target" 2>&1; then
        changes_made=1
    else
        log_error "Failed to clone: ${url}"
        has_errors=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $has_errors -ne 0 ]]; then
    log_error "Git projects apply completed with errors"
    exit 1
fi

if [[ $changes_made -eq 0 ]]; then
    log_ok "All git projects already cloned"
else
    log_ok "Git projects applied"
fi
