#!/usr/bin/env bash
# engine.sh - Reconciliation engine framework.
#
# Provides module loading and execution for bin/apply, bin/check, and bin/plan.
# Source this file after common.sh has been loaded, or it will source common.sh
# itself if not already loaded.

# Guard against double-sourcing.
[[ -n "${_ENGINE_LOADED:-}" ]] && return 0
_ENGINE_LOADED=1

# Source common.sh if not already loaded (PROVISION_DIR would be set).
if [[ -z "${PROVISION_DIR:-}" ]]; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
fi

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

readonly MODULES_DIR="${PROVISION_DIR}/lib/modules"
readonly ORDER_CONF="${MODULES_DIR}/order.conf"

# ---------------------------------------------------------------------------
# Module loading
# ---------------------------------------------------------------------------

# load_module_order
#   Reads lib/modules/order.conf, strips comments and blank lines,
#   and prints module names (one per line) to stdout.
load_module_order() {
    if [[ ! -f "$ORDER_CONF" ]]; then
        log_error "Module order file not found: ${ORDER_CONF}"
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip inline comments and trim whitespace.
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip empty lines.
        [[ -z "$line" ]] && continue

        printf '%s\n' "$line"
    done < "$ORDER_CONF"
}

# ---------------------------------------------------------------------------
# Module execution
# ---------------------------------------------------------------------------

# run_module <module_name> <mode>
#   Runs lib/modules/<module_name>/<mode>.sh where mode is check, apply, or plan.
#   Returns the exit code of the module script.
run_module() {
    local module_name="${1:?run_module requires a module name}"
    local mode="${2:?run_module requires a mode (check, apply, plan)}"

    local module_dir="${MODULES_DIR}/${module_name}"
    local module_script="${module_dir}/${mode}.sh"

    # Validate mode.
    case "$mode" in
        check|apply|plan) ;;
        *)
            log_error "Invalid mode '${mode}'. Must be one of: check, apply, plan"
            return 1
            ;;
    esac

    # Check module directory exists.
    if [[ ! -d "$module_dir" ]]; then
        log_error "Module not found: ${module_name} (expected directory: ${module_dir})"
        return 1
    fi

    # Check mode script exists.
    if [[ ! -f "$module_script" ]]; then
        log_error "Module script not found: ${module_script}"
        return 1
    fi

    log_info "Running module '${module_name}' in ${mode} mode..."

    # Run the module script in a subshell to isolate side effects.
    local exit_code=0
    (
        source "$module_script"
    ) || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_ok "Module '${module_name}' (${mode}): passed"
    else
        log_error "Module '${module_name}' (${mode}): failed (exit code ${exit_code})"
    fi

    return "$exit_code"
}

# ---------------------------------------------------------------------------
# Batch execution
# ---------------------------------------------------------------------------

# run_all_modules <mode>
#   Iterates through order.conf and runs each module in the given mode.
#   Prints a summary at the end.
#   Exit behaviour:
#     - check mode: exit 1 if any module fails
#     - apply mode: exit 1 if any module fails
#     - plan mode:  always exit 0 (informational)
run_all_modules() {
    local mode="${1:?run_all_modules requires a mode (check, apply, plan)}"
    local pass_count=0
    local fail_count=0
    local module_name

    while IFS= read -r module_name; do
        if run_module "$module_name" "$mode"; then
            (( pass_count++ )) || true
        else
            (( fail_count++ )) || true
        fi
    done < <(load_module_order)

    # Print summary.
    echo ""
    log_info "${pass_count} modules passed, ${fail_count} modules failed"

    if [[ "$mode" == "plan" ]]; then
        return 0
    fi

    if [[ $fail_count -gt 0 ]]; then
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Single module execution
# ---------------------------------------------------------------------------

# run_single_module <module_name> <mode>
#   Runs just one module by name (for targeted operations).
run_single_module() {
    local module_name="${1:?run_single_module requires a module name}"
    local mode="${2:?run_single_module requires a mode (check, apply, plan)}"

    run_module "$module_name" "$mode"
}

# ---------------------------------------------------------------------------
# CLI argument parsing
# ---------------------------------------------------------------------------

# parse_engine_args <mode> [args...]
#   Parses --module flag and dispatches to run_single_module or run_all_modules.
#   Usage from bin scripts:
#     source lib/engine.sh
#     parse_engine_args "check" "$@"
parse_engine_args() {
    local mode="${1:?parse_engine_args requires a mode}"
    shift

    local target_module=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --module)
                if [[ -z "${2:-}" ]]; then
                    log_error "--module requires a module name argument"
                    exit 1
                fi
                target_module="$2"
                shift 2
                ;;
            --module=*)
                target_module="${1#--module=}"
                if [[ -z "$target_module" ]]; then
                    log_error "--module requires a module name argument"
                    exit 1
                fi
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                exit 1
                ;;
        esac
    done

    if [[ -n "$target_module" ]]; then
        run_single_module "$target_module" "$mode"
    else
        run_all_modules "$mode"
    fi
}
