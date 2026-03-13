#!/usr/bin/env bash
# git-projects/common.sh — Shared helpers for the git-projects module.

GIT_PROJECTS_BASE="${HOME}/scm"

# repo_name_from_url <url>
#   Extracts the repo name from a clone URL.
#   git@github.com:epistola-app/epistola.git -> epistola
repo_name_from_url() {
    local url="$1"
    local base="${url##*/}"
    echo "${base%.git}"
}
