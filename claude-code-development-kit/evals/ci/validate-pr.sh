#!/bin/bash
# validate-pr.sh - Diff-aware PR validation for marketplace plugins
# Only validates plugins that have changed files in the PR
# Usage: ./validate-pr.sh [options]
# Exit 0 on pass, exit 1 on fail

set -euo pipefail

# ============================================
# Configuration
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVALS_DIR="$(dirname "$SCRIPT_DIR")"
MARKETPLACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Options
FULL_VALIDATION=false
BASE_REF="origin/main"
VERBOSE=false
JSON_OUTPUT=false

# ============================================
# Helper Functions
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

show_help() {
    cat << EOF
validate-pr.sh v${VERSION} - Diff-Aware PR Validation

USAGE:
    ./validate-pr.sh [OPTIONS]

DESCRIPTION:
    Detects changed files in the PR and only validates affected plugins.
    Much faster than full validation for focused changes.

OPTIONS:
    -h, --help          Show this help message
    -f, --full          Run full marketplace validation instead of diff-aware
    -b, --base REF      Base reference for diff comparison (default: origin/main)
    -v, --verbose       Show detailed validation output
    --json              Output summary in JSON format

EXAMPLES:
    ./validate-pr.sh                      # Diff-aware validation against origin/main
    ./validate-pr.sh --full               # Full marketplace validation
    ./validate-pr.sh --base develop       # Compare against develop branch
    ./validate-pr.sh --base HEAD~3        # Compare against 3 commits ago

EXIT CODES:
    0    All validations passed
    1    One or more validations failed
    2    Invalid arguments or configuration error

EOF
}

# ============================================
# Argument Parsing
# ============================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--full)
                FULL_VALIDATION=true
                shift
                ;;
            -b|--base)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --base requires a reference"
                    exit 2
                fi
                BASE_REF="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            -*)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 2
                ;;
            *)
                echo "Unexpected argument: $1"
                exit 2
                ;;
        esac
    done
}

# ============================================
# Git Functions
# ============================================

get_changed_files() {
    local base="$1"

    # Get list of changed files between base and HEAD
    git diff --name-only "$base"...HEAD 2>/dev/null || \
    git diff --name-only "$base" HEAD 2>/dev/null || \
    git diff --name-only HEAD~1 HEAD 2>/dev/null
}

get_marketplace_json_path() {
    if [[ -f "$MARKETPLACE_ROOT/.claude-plugin/marketplace.json" ]]; then
        echo "$MARKETPLACE_ROOT/.claude-plugin/marketplace.json"
    elif [[ -f "$MARKETPLACE_ROOT/marketplace.json" ]]; then
        echo "$MARKETPLACE_ROOT/marketplace.json"
    else
        echo ""
    fi
}

get_plugin_dirs_from_marketplace() {
    local marketplace_json="$1"

    if ! command -v jq &> /dev/null; then
        log_warning "jq not available, cannot parse marketplace.json"
        return
    fi

    jq -r '.plugins[]? | .source' "$marketplace_json" 2>/dev/null | \
        sed 's|^\./||'  # Remove leading ./
}

# ============================================
# Plugin Detection
# ============================================

get_affected_plugins() {
    local changed_files="$1"
    local marketplace_json="$2"

    # Get all plugin directories from marketplace.json
    local plugin_dirs
    plugin_dirs=$(get_plugin_dirs_from_marketplace "$marketplace_json")

    if [[ -z "$plugin_dirs" ]]; then
        log_warning "Could not determine plugin directories"
        return
    fi

    # Find which plugins have changed files
    local affected_plugins=()

    while IFS= read -r plugin_dir; do
        [[ -z "$plugin_dir" ]] && continue

        # Check if any changed file is in this plugin directory
        while IFS= read -r changed_file; do
            [[ -z "$changed_file" ]] && continue

            if [[ "$changed_file" == "$plugin_dir"* ]] || \
               [[ "$changed_file" == "./$plugin_dir"* ]]; then
                # Extract plugin name from marketplace.json
                local plugin_name
                plugin_name=$(jq -r --arg src "$plugin_dir" \
                    '.plugins[]? | select(.source == $src or .source == ("./"+$src)) | .name' \
                    "$marketplace_json" 2>/dev/null)

                if [[ -n "$plugin_name" ]]; then
                    # Add to array if not already present
                    local found=false
                    for existing in "${affected_plugins[@]:-}"; do
                        if [[ "$existing" == "$plugin_name" ]]; then
                            found=true
                            break
                        fi
                    done

                    if [[ "$found" == "false" ]]; then
                        affected_plugins+=("$plugin_name")
                    fi
                fi
                break
            fi
        done <<< "$changed_files"
    done <<< "$plugin_dirs"

    # Output unique plugin names
    printf '%s\n' "${affected_plugins[@]:-}"
}

check_marketplace_json_changed() {
    local changed_files="$1"

    echo "$changed_files" | grep -qE '(marketplace\.json|\.claude-plugin/marketplace\.json)'
}

check_evals_changed() {
    local changed_files="$1"

    echo "$changed_files" | grep -qE 'claude-code-development-kit/evals/'
}

# ============================================
# Validation Functions
# ============================================

run_full_validation() {
    log_info "Running full marketplace validation..."
    echo ""

    local validate_script="$EVALS_DIR/validate-marketplace.sh"

    if [[ ! -x "$validate_script" ]]; then
        log_error "validate-marketplace.sh not found or not executable"
        exit 2
    fi

    local args=()
    [[ "$VERBOSE" == "true" ]] && args+=("--verbose")
    [[ "$JSON_OUTPUT" == "true" ]] && args+=("--json")

    "$validate_script" "${args[@]}" "$MARKETPLACE_ROOT"
}

run_plugin_validation() {
    local plugin_name="$1"

    local validate_script="$EVALS_DIR/validate-marketplace.sh"

    if [[ ! -x "$validate_script" ]]; then
        log_error "validate-marketplace.sh not found or not executable"
        return 1
    fi

    local args=("--plugin" "$plugin_name")
    [[ "$VERBOSE" == "true" ]] && args+=("--verbose")

    "$validate_script" "${args[@]}" "$MARKETPLACE_ROOT"
}

# ============================================
# Output Functions
# ============================================

print_pr_summary() {
    local changed_files="$1"
    local affected_plugins="$2"
    local plugins_passed="$3"
    local plugins_failed="$4"

    echo ""
    echo -e "${BOLD}=== PR Validation Summary ===${NC}"
    echo ""

    local file_count
    file_count=$(echo "$changed_files" | grep -c . || echo "0")
    echo "Changed files: $file_count"

    if [[ -n "$affected_plugins" ]]; then
        local plugin_count
        plugin_count=$(echo "$affected_plugins" | grep -c . || echo "0")
        echo "Affected plugins: $plugin_count"
        echo ""
        echo "Plugins validated:"
        while IFS= read -r plugin; do
            [[ -z "$plugin" ]] && continue
            echo "  - $plugin"
        done <<< "$affected_plugins"
    else
        echo "Affected plugins: 0 (no plugin changes detected)"
    fi

    echo ""

    local total=$((plugins_passed + plugins_failed))
    if [[ $total -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}No plugins to validate${NC}"
    elif [[ $plugins_failed -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}All $plugins_passed plugin(s) passed validation${NC}"
    else
        echo -e "${RED}${BOLD}$plugins_failed of $total plugin(s) failed validation${NC}"
    fi
}

output_json_summary() {
    local affected_plugins="$1"
    local plugins_passed="$2"
    local plugins_failed="$3"
    local errors="$4"

    local status="pass"
    [[ $plugins_failed -gt 0 ]] && status="fail"

    local plugins_json=""
    if [[ -n "$affected_plugins" ]]; then
        plugins_json=$(echo "$affected_plugins" | jq -R -s 'split("\n") | map(select(length > 0))')
    else
        plugins_json="[]"
    fi

    local errors_json="[]"
    if [[ -n "$errors" ]]; then
        errors_json=$(echo "$errors" | jq -R -s 'split("\n") | map(select(length > 0))')
    fi

    cat << EOF
{
  "version": "${VERSION}",
  "mode": "diff-aware",
  "base_ref": "${BASE_REF}",
  "status": "${status}",
  "summary": {
    "plugins_validated": $((plugins_passed + plugins_failed)),
    "plugins_passed": ${plugins_passed},
    "plugins_failed": ${plugins_failed}
  },
  "affected_plugins": ${plugins_json},
  "errors": ${errors_json}
}
EOF
}

# ============================================
# Main Execution
# ============================================

main() {
    parse_args "$@"

    # If full validation requested, just run it
    if [[ "$FULL_VALIDATION" == "true" ]]; then
        run_full_validation
        exit $?
    fi

    echo ""
    echo -e "${BOLD}=== Diff-Aware PR Validation ===${NC}"
    echo ""

    # Find marketplace.json
    local marketplace_json
    marketplace_json=$(get_marketplace_json_path)

    if [[ -z "$marketplace_json" ]]; then
        log_error "marketplace.json not found"
        exit 2
    fi

    log_info "Base reference: $BASE_REF"
    log_info "Marketplace root: $MARKETPLACE_ROOT"

    # Get changed files
    local changed_files
    changed_files=$(get_changed_files "$BASE_REF")

    if [[ -z "$changed_files" ]]; then
        log_info "No changed files detected"
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json_summary "" 0 0 ""
        else
            echo ""
            echo -e "${GREEN}${BOLD}No changes to validate${NC}"
        fi
        exit 0
    fi

    local file_count
    file_count=$(echo "$changed_files" | wc -l | tr -d ' ')
    log_info "Found $file_count changed file(s)"

    # Check if marketplace.json or evals scripts changed - requires full validation
    if check_marketplace_json_changed "$changed_files"; then
        log_warning "marketplace.json changed - running full validation"
        run_full_validation
        exit $?
    fi

    if check_evals_changed "$changed_files"; then
        log_warning "Validation scripts changed - running full validation"
        run_full_validation
        exit $?
    fi

    # Get affected plugins
    local affected_plugins
    affected_plugins=$(get_affected_plugins "$changed_files" "$marketplace_json")

    if [[ -z "$affected_plugins" ]]; then
        log_info "No plugin changes detected"

        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json_summary "" 0 0 ""
        else
            echo ""
            echo -e "${GREEN}${BOLD}No plugins affected by these changes${NC}"
        fi
        exit 0
    fi

    # Validate each affected plugin
    local plugins_passed=0
    local plugins_failed=0
    local errors=""

    echo ""
    log_info "Validating affected plugins..."

    while IFS= read -r plugin_name; do
        [[ -z "$plugin_name" ]] && continue

        echo ""
        echo -e "${CYAN}Validating: ${BOLD}$plugin_name${NC}"

        if run_plugin_validation "$plugin_name"; then
            ((plugins_passed++))
            log_success "$plugin_name validation passed"
        else
            ((plugins_failed++))
            log_error "$plugin_name validation failed"
            errors+="$plugin_name: validation failed"$'\n'
        fi
    done <<< "$affected_plugins"

    # Output summary
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        output_json_summary "$affected_plugins" "$plugins_passed" "$plugins_failed" "$errors"
    else
        print_pr_summary "$changed_files" "$affected_plugins" "$plugins_passed" "$plugins_failed"
    fi

    # Exit with appropriate code
    if [[ $plugins_failed -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

# Run main function
main "$@"
