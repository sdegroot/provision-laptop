#!/usr/bin/env bash
# common.sh - Core shared library for the provisioning system.
#
# Source this file from any provisioning script:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

set -euo pipefail

# ---------------------------------------------------------------------------
# Directory layout
# ---------------------------------------------------------------------------

# PROVISION_DIR points to the repository root (parent of lib/).
PROVISION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# PROVISION_ROOT can be set externally to redirect all absolute paths into a
# temporary directory. This is primarily useful for testing so that scripts
# never touch the real filesystem.
PROVISION_ROOT="${PROVISION_ROOT:-}"

# Ensure ~/.local/bin is in PATH (not always set in non-interactive shells)
[[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]] && export PATH="${HOME}/.local/bin:${PATH}"

# ---------------------------------------------------------------------------
# Color support
# ---------------------------------------------------------------------------

_setup_colors() {
    if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
        COLOR_RESET=""
        COLOR_RED=""
        COLOR_GREEN=""
        COLOR_YELLOW=""
        COLOR_BLUE=""
        COLOR_CYAN=""
    else
        COLOR_RESET=$'\033[0m'
        COLOR_RED=$'\033[0;31m'
        COLOR_GREEN=$'\033[0;32m'
        COLOR_YELLOW=$'\033[0;33m'
        COLOR_BLUE=$'\033[0;34m'
        COLOR_CYAN=$'\033[0;36m'
    fi
}

_setup_colors

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

log_info() {
    printf '%s[INFO]%s %s\n' "${COLOR_BLUE}" "${COLOR_RESET}" "$*"
}

log_warn() {
    printf '%s[WARN]%s %s\n' "${COLOR_YELLOW}" "${COLOR_RESET}" "$*" >&2
}

log_error() {
    printf '%s[ERROR]%s %s\n' "${COLOR_RED}" "${COLOR_RESET}" "$*" >&2
}

log_ok() {
    printf '%s[OK]%s %s\n' "${COLOR_GREEN}" "${COLOR_RESET}" "$*"
}

log_plan() {
    printf '%s[PLAN]%s %s\n' "${COLOR_CYAN}" "${COLOR_RESET}" "$*"
}

# ---------------------------------------------------------------------------
# State file helpers
# ---------------------------------------------------------------------------

# state_file_path <relative_filename>
#   Returns the absolute path to a state file under $PROVISION_DIR/state/.
state_file_path() {
    local filename="${1:?state_file_path requires a filename argument}"
    printf '%s\n' "${PROVISION_DIR}/state/${filename}"
}

# current_arch
#   Returns the machine architecture (e.g. x86_64, aarch64).
#   Can be overridden via PROVISION_ARCH for testing.
current_arch() {
    printf '%s\n' "${PROVISION_ARCH:-$(uname -m)}"
}

# parse_state_file <path>
#   Reads a state file, strips comment lines (starting with #) and blank
#   lines, filters by architecture tags, and prints the remaining lines
#   to stdout.
#
#   Architecture tags: lines prefixed with [arch] are only included when
#   the current architecture matches. Example:
#     [x86_64] tuxedo-drivers    — only on x86_64
#     vim-enhanced               — on all architectures
parse_state_file() {
    local filepath="${1:?parse_state_file requires a file path argument}"

    if [[ ! -f "$filepath" ]]; then
        log_error "State file not found: ${filepath}"
        return 1
    fi

    local arch
    arch="$(current_arch)"

    # Strip comments, blank lines, and filter by arch tag.
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty / whitespace-only lines.
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Check for [arch] prefix
        if [[ "$line" =~ ^\[([a-zA-Z0-9_]+)\][[:space:]]*(.+)$ ]]; then
            local tag_arch="${BASH_REMATCH[1]}"
            local rest="${BASH_REMATCH[2]}"
            if [[ "$tag_arch" == "$arch" ]]; then
                printf '%s\n' "$rest"
            fi
        else
            printf '%s\n' "$line"
        fi
    done < "$filepath"
}

# ---------------------------------------------------------------------------
# Environment checks
# ---------------------------------------------------------------------------

# require_root
#   Exits with an error unless the script is running as root.
#   Set PROVISION_ALLOW_NONROOT=1 to bypass this check (useful in tests).
require_root() {
    if [[ "${PROVISION_ALLOW_NONROOT:-}" == "1" ]]; then
        return 0
    fi

    if [[ "$(id -u)" -ne 0 ]]; then
        log_error "This script must be run as root."
        exit 1
    fi
}

# is_silverblue
#   Returns 0 if the system appears to be Fedora Silverblue, 1 otherwise.
is_silverblue() {
    [[ -x "${PROVISION_ROOT}/usr/bin/rpm-ostree" ]]
}

# wait_for_rpm_ostree [max_wait_seconds]
#   Blocks until no rpm-ostree transaction is in progress.
#   rpm-ostree can only run one transaction at a time; calling rpm-ostree
#   while another transaction is active causes "transaction in progress"
#   errors. This function polls `rpm-ostree status` for "State: busy" and
#   waits until the daemon becomes idle.
#   Returns 1 if the timeout is reached.
wait_for_rpm_ostree() {
    local max_wait="${1:-300}"
    local waited=0
    while rpm-ostree status 2>&1 | grep -qi "State:.*busy\|transaction in progress"; do
        if [[ $waited -ge $max_wait ]]; then
            log_error "Timed out waiting for rpm-ostree transaction (${max_wait}s)"
            return 1
        fi
        if [[ $waited -eq 0 ]]; then
            log_info "Waiting for rpm-ostree transaction to complete..."
        fi
        sleep 5
        waited=$((waited + 5))
    done
}

# wait_for_kickstart_packages
#   If kickstart-packages.service is still running (first boot), wait for it
#   to finish before proceeding. This avoids rpm-ostree transaction conflicts
#   when the user runs bin/apply before the first-boot package layering completes.
wait_for_kickstart_packages() {
    if systemctl is-active --quiet kickstart-packages.service 2>/dev/null; then
        log_info "Waiting for kickstart-packages.service to finish..."
        local waited=0
        local max_wait=600  # 10 minutes — first-boot layering can be slow
        while systemctl is-active --quiet kickstart-packages.service 2>/dev/null; do
            if [[ $waited -ge $max_wait ]]; then
                log_error "Timed out waiting for kickstart-packages.service (${max_wait}s)"
                return 1
            fi
            sleep 5
            waited=$((waited + 5))
        done
        log_ok "kickstart-packages.service completed"
    fi
}

# has_command <command>
#   Returns 0 if the given command is available on PATH, 1 otherwise.
has_command() {
    local cmd="${1:?has_command requires a command name argument}"
    command -v "$cmd" >/dev/null 2>&1
}

