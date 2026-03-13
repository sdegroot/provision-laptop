#!/usr/bin/env bash
# git-projects/common.sh — Shared helpers for the git-projects module.

GIT_PROJECTS_BASE="${HOME}/scm"

# clone_url_to_path <url>
#   Derives the local clone path from a git SSH URL.
#   git@github.com:namespace/repo.git -> ~/scm/namespace/repo
clone_url_to_path() {
    local url="$1"
    # Strip everything up to and including ':'
    local path_part="${url##*:}"
    # Strip .git suffix
    path_part="${path_part%.git}"
    echo "${GIT_PROJECTS_BASE}/${path_part}"
}
