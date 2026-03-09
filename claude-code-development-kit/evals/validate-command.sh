#!/bin/bash
# validate-command.sh - Validates a Claude Code command file
# Usage: ./validate-command.sh <command-path>
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
validate-command.sh - Validates a Claude Code command file

USAGE:
    ./validate-command.sh <command-path>
    ./validate-command.sh --help

ARGUMENTS:
    command-path    Path to the command .md file

VALIDATION RULES:
    Required:
        - File must exist with a .md extension
        - File must have YAML frontmatter (between --- markers)
        - Frontmatter must include a 'description' field
        - If 'name' is absent, the filename (minus .md) is used as the command name

    Checked:
        - Commands using $ARGUMENTS should document them in an Arguments section
        - Body should contain substantive instruction content (>5 lines)
        - No hardcoded personal paths (e.g., /Users/yourname/)

    # TODO: Frontmatter field validation could use the schema at:
    #       schemas/command-frontmatter.schema.json
    #       e.g.: python3 -c "import jsonschema; ..." or ajv validate

EXIT CODES:
    0    Validation passed
    1    One or more validation errors found

EXAMPLES:
    ./validate-command.sh ./commands/available-skills.md
    ./validate-command.sh /path/to/plugin/commands/my-command.md
EOF
}

# Check for help flag before processing other arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# Check arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <command-path>"
    echo "       $0 --help"
    echo "  command-path: Path to the command .md file"
    exit 1
fi

COMMAND_PATH="$1"

# Get script directory for finding schemas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared schema validation helper
# shellcheck source=_schema-validate.sh
source "$SCRIPT_DIR/_schema-validate.sh"

# Resolve to absolute path
if [[ ! "$COMMAND_PATH" = /* ]]; then
    COMMAND_PATH="$(pwd)/$COMMAND_PATH"
fi

echo "=========================================="
echo "Validating Command: $COMMAND_PATH"
echo "=========================================="

# Check if file exists
if [[ ! -f "$COMMAND_PATH" ]]; then
    log_error "Command file not found: $COMMAND_PATH"
    exit 1
fi
log_success "Command file exists"

# Claude Code requires command files to use the .md extension
if [[ ! "$COMMAND_PATH" =~ \.md$ ]]; then
    log_error "Command file must have .md extension"
else
    log_success "Correct .md extension"
fi

# Read file content
CONTENT=$(cat "$COMMAND_PATH")

# YAML frontmatter is parsed by Claude Code to extract command metadata.
# The block must open and close with --- markers.
if [[ ! "$CONTENT" =~ ^--- ]]; then
    log_error "YAML frontmatter not found (file must start with ---)"
else
    log_success "YAML frontmatter present"

    # Extract frontmatter (content between first and second ---)
    FRONTMATTER=$(echo "$CONTENT" | awk '/^---$/{p++; next} p==1{print}')

    # Schema validation (field names, types, patterns, enums, additionalProperties)
    SCHEMA_FILE="$SCRIPT_DIR/../schemas/command-frontmatter.schema.json"
    if [[ -f "$SCHEMA_FILE" ]]; then
        SCHEMA_RC=0
        SCHEMA_OUTPUT=$(validate_frontmatter_schema "$SCHEMA_FILE" "$COMMAND_PATH" 2>&1) || SCHEMA_RC=$?
        if [[ $SCHEMA_RC -eq 0 ]]; then
            log_success "Frontmatter passes schema validation"
        elif [[ $SCHEMA_RC -eq 1 ]]; then
            while IFS= read -r schema_err; do
                [[ -n "$schema_err" ]] && log_error "$schema_err"
            done <<< "$SCHEMA_OUTPUT"
        else
            log_info "${SCHEMA_OUTPUT:-Schema validation skipped (tools not available)}"
        fi
    fi

    # 'name' is optional - if absent, Claude Code derives the command name from the filename.
    # When present, it overrides the filename-based name.
    if echo "$FRONTMATTER" | grep -qE "^name:|^name :|name:"; then
        NAME=$(echo "$FRONTMATTER" | grep -E "^name:" | head -1 | sed 's/^name:[[:space:]]*//')
        log_success "Field 'name' present: $NAME"
    else
        # Derive name from filename
        DERIVED_NAME=$(basename "$COMMAND_PATH" .md)
        log_info "No 'name' in frontmatter - using filename: $DERIVED_NAME"
    fi

    # 'description' is required - shown in the slash command picker and used for discovery
    if echo "$FRONTMATTER" | grep -qE "^description:|^description :"; then
        log_success "Required field 'description' present"
    else
        log_error "Required field 'description' missing from frontmatter"
    fi

    # 'allowed-tools' restricts which tools Claude can use when executing this command
    if echo "$FRONTMATTER" | grep -qE "^allowed-tools:|^allowedTools:"; then
        log_info "Has allowed-tools defined"
    fi
fi

# $ARGUMENTS is a special variable Claude Code replaces with the text after the command name.
# Commands that use it should document expected arguments for users.
if grep -q '\$ARGUMENTS' "$COMMAND_PATH"; then
    log_info "Command uses \$ARGUMENTS"

    # A dedicated Arguments/Usage/Parameters section helps users understand what to pass
    if grep -qiE '^##.*arguments|^##.*usage|^##.*parameters' "$COMMAND_PATH"; then
        log_success "Arguments documentation section found"
    else
        log_warning "Command uses \$ARGUMENTS but no Arguments/Usage/Parameters section found"
    fi

    # argument-hint in frontmatter surfaces the hint in Claude Code's completion UI
    if echo "$FRONTMATTER" | grep -qE "^arguments:|^args:|^argument-hint:"; then
        log_success "Arguments defined in frontmatter"
    else
        log_warning "Consider adding 'argument-hint' to frontmatter for better discoverability"
    fi
fi

# Check for personal identifiers
# Exclude common documentation example patterns (username, dev, <username>, yourname, you, example, etc.)
PERSONAL_MATCHES=$(grep -oE '/Users/[a-zA-Z]+|/home/[a-zA-Z]+|C:\\Users\\[a-zA-Z]+' "$COMMAND_PATH" 2>/dev/null | grep -vE '/Users/(username|dev|yourname|you|example|user|name|your-username)|/home/(username|dev|yourname|you|example|user|name|your-username)|C:\\Users\\(username|dev|yourname|you|example|user|your-username)' | sort -u || true)

if [[ -n "$PERSONAL_MATCHES" ]]; then
    log_error "Personal identifier found: $PERSONAL_MATCHES"
else
    log_success "No personal identifiers found"
fi

# Check for common command best practices
BODY=$(echo "$CONTENT" | awk '/^---$/{p++; next} p>=2{print}')

if [[ -z "$BODY" ]]; then
    log_warning "Command body is empty after frontmatter"
fi

# Check for instruction content
BODY_LINE_COUNT=$(echo "$BODY" | wc -l | tr -d ' ')
if [[ $BODY_LINE_COUNT -lt 5 ]]; then
    log_warning "Command body is very short ($BODY_LINE_COUNT lines). Consider adding more detail."
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
echo -e "${GREEN}Command validation passed!${NC}"
exit 0
