#!/bin/bash
# validate-structure.sh - Validates mode-plugin plugin structure
# Usage: ./validate-structure.sh
# Exit 0 on pass, exit 1 on fail

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=()
WARNINGS=()

# Get script directory and plugin root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

log_error() {
    ERRORS+=("$1")
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    WARNINGS+=("$1")
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_info() {
    echo -e "[INFO] $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

echo "=========================================="
echo "STRUCT: mode-plugin Structure Validation"
echo "=========================================="
echo "Plugin Root: $PLUGIN_ROOT"

# ============================================
# Check plugin.json
# ============================================
log_section "Plugin Manifest"

PLUGIN_JSON=""
if [[ -f "$PLUGIN_ROOT/plugin.json" ]]; then
    PLUGIN_JSON="$PLUGIN_ROOT/plugin.json"
elif [[ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]]; then
    PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
fi

if [[ -z "$PLUGIN_JSON" ]]; then
    log_error "plugin.json not found"
else
    log_success "plugin.json exists"

    if command -v jq &> /dev/null; then
        if jq empty "$PLUGIN_JSON" 2>/dev/null; then
            log_success "plugin.json is valid JSON"

            NAME=$(jq -r '.name // empty' "$PLUGIN_JSON")
            VERSION=$(jq -r '.version // empty' "$PLUGIN_JSON")

            if [[ "$NAME" == "mode-plugin" ]]; then
                log_success "Plugin name is correct: $NAME"
            else
                log_error "Plugin name mismatch: expected 'mode-plugin', got '$NAME'"
            fi

            if [[ -n "$VERSION" ]]; then
                log_success "Version present: $VERSION"
            else
                log_error "Version missing"
            fi
        else
            log_error "plugin.json is not valid JSON"
        fi
    else
        log_warning "jq not installed - skipping JSON validation"
    fi
fi

# ============================================
# Check Commands Directory (mode-plugin uses commands, not skills)
# ============================================
log_section "Commands Validation"

EXPECTED_COMMANDS=(
    "challenger.md"
    "creative.md"
    "exit.md"
    "status.md"
    "teaching.md"
)

COMMANDS_DIR="$PLUGIN_ROOT/commands"

if [[ ! -d "$COMMANDS_DIR" ]]; then
    log_error "commands/ directory not found"
else
    log_success "commands/ directory exists"

    for cmd in "${EXPECTED_COMMANDS[@]}"; do
        CMD_PATH="$COMMANDS_DIR/$cmd"

        if [[ -f "$CMD_PATH" ]]; then
            log_success "Command exists: $cmd"
        else
            log_error "Command not found: $cmd"
        fi
    done

    # Count total commands
    CMD_COUNT=$(find "$COMMANDS_DIR" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
    log_info "Total commands found: $CMD_COUNT (expected: ${#EXPECTED_COMMANDS[@]})"
fi

# ============================================
# Check README.md
# ============================================
log_section "Documentation"

if [[ -f "$PLUGIN_ROOT/README.md" ]]; then
    log_success "README.md exists"
else
    log_warning "README.md not found"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo "VALIDATION SUMMARY"
echo "=========================================="
echo "Errors: ${#ERRORS[@]}"
echo "Warnings: ${#WARNINGS[@]}"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}STRUCT: FAILED${NC}"
    echo ""
    echo "Errors found:"
    for error in "${ERRORS[@]}"; do
        echo "  - $error"
    done
    exit 1
fi

echo ""
echo -e "${GREEN}STRUCT: PASSED${NC}"
exit 0
