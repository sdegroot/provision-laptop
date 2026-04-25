#!/usr/bin/env bash
# usr-tools/apply.sh — Install user-level tools via native installers.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../common.sh"

STATE_FILE="$(state_file_path "usr-tools.conf")"
changes_made=0

if [[ -n "${PROVISION_ROOT:-}" ]]; then
    log_warn "Skipping usr-tools install in test mode"
    exit 0
fi

while IFS= read -r line; do
    name="$(echo "$line" | awk '{print $1}')"
    check_path="$(echo "$line" | awk '{print $2}')"
    install_cmd="$(echo "$line" | cut -d' ' -f3-)"

    # Expand ~ to $HOME
    check_path="${check_path/#\~/$HOME}"

    if [[ -e "$check_path" ]]; then
        continue
    fi

    log_info "Installing ${name}..."
    if eval "$install_cmd"; then
        changes_made=1
    else
        log_error "Failed to install ${name}"
    fi
done < <(parse_state_file "$STATE_FILE")

if [[ $changes_made -eq 0 ]]; then
    log_ok "All user tools already installed"
else
    log_ok "User tools installed"
fi
