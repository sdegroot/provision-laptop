#!/usr/bin/env bash
# git-projects/plan.sh — Show planned git clone operations (dry-run).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

STATE_FILE="$(state_file_path "git-projects.conf")"
changes_planned=0

if [[ ! -f "$STATE_FILE" ]]; then
    log_warn "No git-projects.conf found — skipping"
    exit 0
fi

while IFS= read -r line; do
    read -r url namespace <<< "$line"
    repo="$(repo_name_from_url "$url")"
    target="${GIT_PROJECTS_BASE}/${namespace}/${repo}"

    if [[ ! -d "$target/.git" ]]; then
        log_plan "Would clone: ${url} -> ${target}"
        changes_planned=1
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_planned -eq 0 ]]; then
    log_ok "No git project changes needed"
fi
