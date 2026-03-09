#!/bin/bash
# validate-skill.sh - Validates a Claude Code skill directory
# Usage: ./validate-skill.sh [--hook-mode] <skill-path>
# Exit 0 on pass, exit 1 on fail
#
# This is the canonical skill validator used by both the CI/CLI pipeline
# and the PostToolUse hook (via --hook-mode for JSON output).

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

ERRORS=()
WARNINGS=()
HOOK_MODE=false

log_error() {
    ERRORS+=("$1")
    if [[ "$HOOK_MODE" != "true" ]]; then
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

log_warning() {
    WARNINGS+=("$1")
    if [[ "$HOOK_MODE" != "true" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_success() {
    if [[ "$HOOK_MODE" != "true" ]]; then
        echo -e "${GREEN}[PASS]${NC} $1"
    fi
}

log_info() {
    if [[ "$HOOK_MODE" != "true" ]]; then
        echo -e "[INFO] $1"
    fi
}

show_help() {
    cat << 'EOF'
validate-skill.sh - Validates a Claude Code skill directory

USAGE:
    ./validate-skill.sh [OPTIONS] <skill-path>
    ./validate-skill.sh --help

ARGUMENTS:
    skill-path    Path to the skill directory containing SKILL.md,
                  or direct path to a SKILL.md file (hook mode)

OPTIONS:
    --hook-mode   Output results as JSON (for use as a Claude Code hook).
                  Accepts a SKILL.md path directly or reads JSON from
                  stdin with tool_input.file_path.

VALIDATION RULES:
    Required:
        - Directory must exist and contain a SKILL.md file
        - SKILL.md must have YAML frontmatter (between --- markers)
        - Frontmatter must include 'name' and 'description' fields
        - File must not exceed 500 lines

    Recommended (warnings):
        - 'allowed-tools' field present
        - 'version' field present
        - 'last_updated' field present
        - Description between 200–400 characters

    Schema validation:
        - If python3 + jsonschema + pyyaml are available, validates
          frontmatter against schemas/skill-frontmatter.schema.json

    Checked:
        - @path imports are resolved relative to the skill directory
        - No hardcoded personal paths (e.g., /Users/yourname/)

EXIT CODES:
    0    Validation passed
    1    One or more validation errors found

EXAMPLES:
    ./validate-skill.sh ./skills/authoring-skills
    ./validate-skill.sh --hook-mode path/to/SKILL.md
EOF
}

# Check for help flag before processing other arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# Parse options
while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --hook-mode) HOOK_MODE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# In hook mode, resolve the skill file from argument or stdin JSON
if [[ "$HOOK_MODE" == "true" ]]; then
    if [[ -n "${1:-}" ]]; then
        INPUT_PATH="$1"
    elif [[ ! -t 0 ]]; then
        INPUT=$(cat)
        INPUT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
        if [[ -z "$INPUT_PATH" ]]; then
            # Try jq fallback
            INPUT_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
        fi
    fi

    if [[ -z "${INPUT_PATH:-}" ]]; then
        echo '{"status":"skip","reason":"no file path provided"}'
        exit 0
    fi

    # If path points to a file, derive skill directory
    if [[ -f "$INPUT_PATH" ]]; then
        SKILL_FILE="$INPUT_PATH"
        SKILL_PATH="$(dirname "$INPUT_PATH")"
    elif [[ -d "$INPUT_PATH" ]]; then
        SKILL_PATH="$INPUT_PATH"
        SKILL_FILE="$INPUT_PATH/SKILL.md"
    else
        echo '{"status":"skip","reason":"path not found"}'
        exit 0
    fi

    # Only validate SKILL.md files
    if [[ "$(basename "$SKILL_FILE")" != "SKILL.md" ]]; then
        echo '{"status":"skip","reason":"not a SKILL.md file"}'
        exit 0
    fi
else
    # Normal CLI mode
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 [--hook-mode] <skill-path>"
        echo "       $0 --help"
        echo "  skill-path: Path to the skill directory containing SKILL.md"
        exit 1
    fi

    SKILL_PATH="$1"

    # Resolve to absolute path
    if [[ ! "$SKILL_PATH" = /* ]]; then
        SKILL_PATH="$(pwd)/$SKILL_PATH"
    fi

    SKILL_FILE="$SKILL_PATH/SKILL.md"
fi

# Get script directory for finding schemas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared schema validation helper
# shellcheck source=_schema-validate.sh
source "$SCRIPT_DIR/_schema-validate.sh"

if [[ "$HOOK_MODE" != "true" ]]; then
    echo "=========================================="
    echo "Validating Skill: $SKILL_PATH"
    echo "=========================================="
fi

# Check if directory exists
if [[ ! -d "$SKILL_PATH" ]]; then
    log_error "Skill path is not a directory: $SKILL_PATH"
    if [[ "$HOOK_MODE" == "true" ]]; then
        echo '{"status":"fail","errors":["Skill path is not a directory"]}'
    fi
    exit 1
fi

# Every skill must have a SKILL.md as its entry point
if [[ ! -f "$SKILL_FILE" ]]; then
    log_error "SKILL.md not found in $SKILL_PATH"
    if [[ "$HOOK_MODE" == "true" ]]; then
        echo '{"status":"fail","errors":["SKILL.md not found"]}'
    fi
    exit 1
fi
log_success "SKILL.md exists"

# Read file content
CONTENT=$(cat "$SKILL_FILE")

# YAML frontmatter is required for Claude Code to parse skill metadata.
# The frontmatter block must start on line 1 with ---.
if [[ ! "$CONTENT" =~ ^--- ]]; then
    log_error "YAML frontmatter not found (file must start with ---)"
else
    log_success "YAML frontmatter present"

    # Extract frontmatter (content between first --- and second ---)
    FRONTMATTER=$(echo "$CONTENT" | awk '/^---$/{p++; next} p==1{print}')

    # Schema validation (field names, types, patterns, enums, additionalProperties)
    SCHEMA_FILE="$SCRIPT_DIR/../schemas/skill-frontmatter.schema.json"
    if [[ -f "$SCHEMA_FILE" ]]; then
        SCHEMA_RC=0
        SCHEMA_OUTPUT=$(validate_frontmatter_schema "$SCHEMA_FILE" "$SKILL_FILE" 2>&1) || SCHEMA_RC=$?
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

    # Structural presence checks — 'name' and 'description' are practically required
    # for a skill to function even though the schema marks them optional.
    if echo "$FRONTMATTER" | grep -q "^name:"; then
        log_success "Field 'name' present"
    else
        log_error "Field 'name' missing from frontmatter"
    fi

    if echo "$FRONTMATTER" | grep -q "^description:"; then
        log_success "Field 'description' present"

        # Description length check (200–400 chars recommended)
        DESC_VALUE=$(echo "$FRONTMATTER" | grep "^description:" | cut -d':' -f2- | sed 's/^[[:space:]]*//')
        DESC_LENGTH=${#DESC_VALUE}
        if [[ $DESC_LENGTH -lt 200 ]]; then
            log_warning "Description is short ($DESC_LENGTH chars, recommend 200–400)"
        elif [[ $DESC_LENGTH -gt 400 ]]; then
            log_warning "Description is long ($DESC_LENGTH chars, recommend 200–400)"
        else
            log_success "Description length OK ($DESC_LENGTH chars)"
        fi
    else
        log_error "Field 'description' missing from frontmatter"
    fi

    # Recommended fields (warnings only)
    if ! echo "$FRONTMATTER" | grep -q "^allowed-tools:"; then
        log_warning "Missing 'allowed-tools' field (recommended)"
    fi

    if ! echo "$FRONTMATTER" | grep -q "^version:"; then
        log_warning "Missing 'version' field (recommended)"
    fi

    if ! echo "$FRONTMATTER" | grep -q "^last_updated:"; then
        log_warning "Missing 'last_updated' field (recommended)"
    fi
fi

# Skills over 500 lines become hard to scan; large content should use @path imports
LINE_COUNT=$(wc -l < "$SKILL_FILE" | tr -d ' ')
if [[ $LINE_COUNT -gt 500 ]]; then
    log_error "SKILL.md exceeds 500 lines (has $LINE_COUNT lines). Consider splitting content."
else
    log_success "Line count within limit ($LINE_COUNT/500)"
fi

# @path imports allow skills to reference external files for progressive disclosure.
# Each import is resolved relative to the skill directory.
IMPORTS=$(grep -oE '@[a-zA-Z0-9_./-]+' "$SKILL_FILE" 2>/dev/null || true)

if [[ -n "$IMPORTS" ]]; then
    log_info "Checking @path imports..."
    while IFS= read -r import; do
        # Remove @ prefix
        IMPORT_PATH="${import#@}"

        # Skip if it looks like a reference rather than a file path
        if [[ ! "$IMPORT_PATH" =~ \. && ! "$IMPORT_PATH" =~ / ]]; then
            continue
        fi

        # Try resolving relative to skill directory
        RESOLVED_PATH="$SKILL_PATH/$IMPORT_PATH"

        if [[ -f "$RESOLVED_PATH" ]]; then
            log_success "Import resolves: $import -> $RESOLVED_PATH"
        else
            # Try as absolute path
            if [[ -f "$IMPORT_PATH" ]]; then
                log_success "Import resolves (absolute): $import"
            else
                log_warning "Import may not resolve: $import (checked $RESOLVED_PATH)"
            fi
        fi
    done <<< "$IMPORTS"
fi

# Check for personal identifiers
# Exclude common documentation example patterns (username, dev, <username>, yourname, you, example, etc.)
PERSONAL_MATCHES=$(grep -oE '/Users/[a-zA-Z]+|/home/[a-zA-Z]+|C:\\Users\\[a-zA-Z]+' "$SKILL_FILE" 2>/dev/null | grep -vE '/Users/(username|dev|yourname|you|example|user|name|your-username)|/home/(username|dev|yourname|you|example|user|name|your-username)|C:\\Users\\(username|dev|yourname|you|example|user|your-username)' | sort -u || true)

if [[ -n "$PERSONAL_MATCHES" ]]; then
    log_error "Personal identifier found: $PERSONAL_MATCHES"
else
    log_success "No personal identifiers found"
fi

# ============================================
# Output
# ============================================

if [[ "$HOOK_MODE" == "true" ]]; then
    # JSON output for hook consumers
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        # Build JSON error array
        ERR_JSON=""
        for err in "${ERRORS[@]}"; do
            # Escape quotes for JSON
            escaped=$(echo "$err" | sed 's/"/\\"/g')
            ERR_JSON="${ERR_JSON}\"${escaped}\","
        done
        ERR_JSON="[${ERR_JSON%,}]"

        echo "{\"status\":\"fail\",\"errors\":${ERR_JSON}}"
        exit 1
    elif [[ ${#WARNINGS[@]} -gt 0 ]]; then
        WARN_JSON=""
        for warn in "${WARNINGS[@]}"; do
            escaped=$(echo "$warn" | sed 's/"/\\"/g')
            WARN_JSON="${WARN_JSON}\"${escaped}\","
        done
        WARN_JSON="[${WARN_JSON%,}]"

        echo "{\"status\":\"pass\",\"warnings\":${WARN_JSON}}"
        exit 0
    else
        echo '{"status":"pass"}'
        exit 0
    fi
fi

# Normal CLI summary
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
echo -e "${GREEN}Skill validation passed!${NC}"
exit 0
