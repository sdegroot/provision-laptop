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

# require_ssh_agent <state_file>
#   If the state file contains any SSH URLs (git@...), checks that the
#   1Password SSH agent socket exists. Returns 1 with a helpful message
#   if the socket is missing. HTTPS-only configs pass without the check.
require_ssh_agent() {
    local state_file="$1"
    local sock="${OP_AGENT_SOCK:-${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock}"

    if ! parse_state_file "$state_file" | grep -q '^git@'; then
        return 0
    fi

    if [[ ! -S "$sock" ]]; then
        log_error "SSH repos found in config but 1Password SSH agent is not available"
        log_error "Socket missing: $sock"
        log_error "Set up 1Password first — see docs/1password-setup.md"
        log_error "Then re-run: bin/apply"
        return 1
    fi
}
