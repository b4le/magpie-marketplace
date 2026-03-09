#!/bin/bash
# validate-hook.sh - Validates a Claude Code hook script
# Usage: ./validate-hook.sh <hook-path>
# Exit 0 on pass, exit 1 on fail

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

ERRORS=()
WARNINGS=()

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

show_help() {
    cat << 'EOF'
validate-hook.sh - Validates a Claude Code hook script

USAGE:
    ./validate-hook.sh <hook-path>
    ./validate-hook.sh --help

ARGUMENTS:
    hook-path    Path to the hook script file (any executable script)

VALIDATION RULES:
    Required:
        - File must exist
        - File must have a shebang line (#!) or be marked executable

    Checked:
        - Shebang points to a recognised interpreter (bash, sh, python, node)
        - Script uses error handling (set -e, set -o errexit, or || exit patterns)
        - No hardcoded personal paths (e.g., /Users/yourname/)
        - No dangerous eval patterns with user-controlled input

    Informational:
        - Variable quoting practices
        - Use of environment variables for paths
        - jq usage for JSON processing
        - Script length (>200 lines triggers a warning)

EXIT CODES:
    0    Validation passed
    1    One or more validation errors found

EXAMPLES:
    ./validate-hook.sh ./hooks/pre-tool-use.sh
    ./validate-hook.sh /path/to/plugin/hooks/checkpoint-detector.sh
EOF
}

# Check for help flag before processing other arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# Check arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <hook-path>"
    echo "       $0 --help"
    echo "  hook-path: Path to the hook script file"
    exit 1
fi

HOOK_PATH="$1"

# Resolve to absolute path
if [[ ! "$HOOK_PATH" = /* ]]; then
    HOOK_PATH="$(pwd)/$HOOK_PATH"
fi

echo "=========================================="
echo "Validating Hook: $HOOK_PATH"
echo "=========================================="

# Check if file exists
if [[ ! -f "$HOOK_PATH" ]]; then
    log_error "Hook file not found: $HOOK_PATH"
    exit 1
fi
log_success "Hook file exists"

# Read file content
CONTENT=$(cat "$HOOK_PATH")
FIRST_LINE=$(head -1 "$HOOK_PATH")

# A shebang tells the OS which interpreter to use when the hook is executed directly.
# Without one, execution depends on the shell that spawns the hook process.
if [[ "$FIRST_LINE" =~ ^#! ]]; then
    log_success "Shebang present: $FIRST_LINE"

    # Validate shebang points to a recognised interpreter
    if [[ "$FIRST_LINE" =~ ^#!/bin/bash ]] || \
       [[ "$FIRST_LINE" =~ ^#!/usr/bin/env\ bash ]] || \
       [[ "$FIRST_LINE" =~ ^#!/bin/sh ]] || \
       [[ "$FIRST_LINE" =~ ^#!/usr/bin/env\ sh ]] || \
       [[ "$FIRST_LINE" =~ ^#!/usr/bin/env\ python ]] || \
       [[ "$FIRST_LINE" =~ ^#!/usr/bin/env\ node ]]; then
        log_success "Valid interpreter in shebang"
    else
        log_warning "Unusual shebang: $FIRST_LINE - verify interpreter exists"
    fi
else
    # Check if executable without shebang
    if [[ -x "$HOOK_PATH" ]]; then
        log_warning "File is executable but has no shebang - may fail on some systems"
    else
        log_error "File has no shebang and is not executable"
    fi
fi

# Claude Code must be able to execute the hook file at runtime
if [[ -x "$HOOK_PATH" ]]; then
    log_success "File is executable"
else
    log_warning "File is not executable. Run: chmod +x \"$HOOK_PATH\""
fi

# Error handling prevents hooks from silently succeeding after a failed command.
# At least one form of error handling should be present.
HAS_ERROR_HANDLING=false

if grep -q "set -e" "$HOOK_PATH"; then
    log_success "Uses 'set -e' for error handling"
    HAS_ERROR_HANDLING=true
fi

if grep -q "set -o errexit" "$HOOK_PATH"; then
    log_success "Uses 'set -o errexit' for error handling"
    HAS_ERROR_HANDLING=true
fi

# pipefail causes a pipeline to return the exit code of the first failed command
if grep -q "set -o pipefail" "$HOOK_PATH"; then
    log_success "Uses 'set -o pipefail' for pipeline error handling"
fi

if grep -qE '\|\|\s*(exit|return|die|error|fatal)' "$HOOK_PATH"; then
    log_info "Has explicit error handling with || exit/return patterns"
    HAS_ERROR_HANDLING=true
fi

if grep -qE 'if\s+\[\[.*\]\].*then|if\s+\[.*\].*then' "$HOOK_PATH"; then
    log_info "Has conditional checks"
    HAS_ERROR_HANDLING=true
fi

if [[ "$HAS_ERROR_HANDLING" == "false" ]]; then
    log_warning "No explicit error handling found. Consider adding 'set -e' or explicit checks."
fi

# Unquoted variable expansions can cause word-splitting and glob expansion bugs
QUOTED_VARS=$(grep -oE '"\$[a-zA-Z_][a-zA-Z0-9_]*"|\$\{[a-zA-Z_][a-zA-Z0-9_]*\}' "$HOOK_PATH" | wc -l | tr -d ' ')
UNQUOTED_VARS=$(grep -oE '[^"]\$[a-zA-Z_][a-zA-Z0-9_]*[^"}]' "$HOOK_PATH" 2>/dev/null | wc -l | tr -d ' ')

if [[ $QUOTED_VARS -gt 0 ]]; then
    log_info "Found $QUOTED_VARS quoted variable references (good practice)"
fi

if [[ $UNQUOTED_VARS -gt 5 ]]; then
    log_warning "Found potentially unquoted variables. Consider quoting all variable expansions."
fi

# These patterns may allow command injection if the hook processes untrusted input
DANGEROUS_PATTERNS=(
    'eval\s+\$'
    'eval\s+"\$'
    '\$\(.*\$.*\)'  # Command substitution with user input
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$HOOK_PATH" 2>/dev/null; then
        log_warning "Potentially unsafe pattern found: $pattern - Review for command injection risks"
    fi
done

# eval with user-controlled input can execute arbitrary code
if grep -q '\beval\b' "$HOOK_PATH"; then
    log_warning "'eval' detected - ensure it's not used with user-controlled input"
fi

# Check for personal identifiers
# Exclude common documentation example patterns (username, dev, <username>, yourname, you, example, etc.)
PERSONAL_MATCHES=$(grep -oE '/Users/[a-zA-Z]+|/home/[a-zA-Z]+|C:\\Users\\[a-zA-Z]+' "$HOOK_PATH" 2>/dev/null | grep -vE '/Users/(username|dev|yourname|you|example|user|name|your-username)|/home/(username|dev|yourname|you|example|user|name|your-username)|C:\\Users\\(username|dev|yourname|you|example|user|your-username)' | sort -u || true)

if [[ -n "$PERSONAL_MATCHES" ]]; then
    log_error "Personal/hardcoded path found: $PERSONAL_MATCHES"
else
    log_success "No hardcoded personal paths found"
fi

# Check for environment variable usage (preferred over hardcoded paths)
if grep -qE '\$HOME|\$\{HOME\}|\$USER|\$\{USER\}' "$HOOK_PATH"; then
    log_success "Uses environment variables for paths (good practice)"
fi

# Check for proper JSON handling if jq is used
if grep -q 'jq' "$HOOK_PATH"; then
    log_info "Script uses jq for JSON processing"

    # Check if jq is used safely
    if grep -qE 'jq\s+-r' "$HOOK_PATH"; then
        log_info "Uses jq -r for raw output"
    fi
fi

# Check script length
LINE_COUNT=$(wc -l < "$HOOK_PATH" | tr -d ' ')
if [[ $LINE_COUNT -gt 200 ]]; then
    log_warning "Script is long ($LINE_COUNT lines). Consider breaking into functions or separate scripts."
else
    log_info "Script length: $LINE_COUNT lines"
fi

# Summary
echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo "Errors: ${#ERRORS[@]}"
echo "Warnings: ${#WARNINGS[@]}"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo "Failed checks:"
    for error in "${ERRORS[@]}"; do
        echo "  - $error"
    done
    exit 1
fi

echo ""
echo -e "${GREEN}Hook validation passed!${NC}"
exit 0
