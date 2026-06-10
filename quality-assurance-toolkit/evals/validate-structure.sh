#!/bin/bash
# validate-structure.sh - Validates quality-assurance-toolkit plugin structure
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
echo "STRUCT-05: quality-assurance-toolkit Structure Validation"
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

            if [[ "$NAME" == "quality-assurance-toolkit" ]]; then
                log_success "Plugin name is correct: $NAME"
            else
                log_error "Plugin name mismatch: expected 'quality-assurance-toolkit', got '$NAME'"
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
# Check Required Skills
# ============================================
log_section "Skills Validation"

EXPECTED_SKILLS=(
    "eval-plugin"
)

SKILLS_DIR="$PLUGIN_ROOT/skills"

if [[ ! -d "$SKILLS_DIR" ]]; then
    log_error "skills/ directory not found"
else
    log_success "skills/ directory exists"

    for skill in "${EXPECTED_SKILLS[@]}"; do
        SKILL_PATH="$SKILLS_DIR/$skill"
        SKILL_MD="$SKILL_PATH/SKILL.md"

        if [[ -d "$SKILL_PATH" ]]; then
            log_success "Skill directory exists: $skill"

            if [[ -f "$SKILL_MD" ]]; then
                log_success "SKILL.md exists: $skill"

                # Check for YAML frontmatter
                if head -1 "$SKILL_MD" | grep -q "^---"; then
                    log_success "YAML frontmatter present: $skill"
                else
                    log_error "YAML frontmatter missing: $skill"
                fi
            else
                log_error "SKILL.md not found: $skill"
            fi
        else
            log_error "Skill directory not found: $skill"
        fi
    done

    # Count total skills
    SKILL_COUNT=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    log_info "Total skills found: $SKILL_COUNT (expected: ${#EXPECTED_SKILLS[@]})"
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
    echo -e "${RED}STRUCT-05: FAILED${NC}"
    echo ""
    echo "Errors found:"
    for error in "${ERRORS[@]}"; do
        echo "  - $error"
    done
    exit 1
fi

echo ""
echo -e "${GREEN}STRUCT-05: PASSED${NC}"
exit 0
