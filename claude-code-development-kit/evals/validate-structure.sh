#!/bin/bash
# validate-structure.sh - Validates claude-code-development-kit plugin structure
# Usage: ./validate-structure.sh [--help]
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

show_help() {
    cat << 'EOF'
validate-structure.sh - Validates claude-code-development-kit plugin structure

USAGE:
    ./validate-structure.sh
    ./validate-structure.sh --help

DESCRIPTION:
    Validates the expected directory layout and manifest of the
    claude-code-development-kit plugin. Unlike validate-plugin.sh, this
    script checks for the specific set of skills that must be present in
    this particular plugin, not just any plugin.

VALIDATION RULES:
    Manifest:
        - plugin.json must exist and be valid JSON
        - 'name' must equal 'claude-code-development-kit'
        - 'version' must be present

    Expected skills (all must exist with SKILL.md and valid frontmatter):
        authoring-agent-prompts, authoring-output-styles, authoring-skills,
        best-practices-reference, creating-commands, creating-plugins,
        integrating-mcps, managing-memory, resolving-claude-code-issues,
        understanding-hooks, using-commands, using-tools

    Directories:
        - commands/    must exist and contain at least one .md file
        - hooks/       must exist (hooks.json recommended)
        - output-styles/ should exist

    Documentation:
        - README.md should exist

EXIT CODES:
    0    Validation passed
    1    One or more validation errors found

EXAMPLES:
    ./validate-structure.sh
    cd /path/to/claude-code-development-kit && ./evals/validate-structure.sh
EOF
}

# Check for help flag
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

echo "=========================================="
echo "STRUCT: claude-code-development-kit Structure Validation"
echo "=========================================="
echo "Plugin Root: $PLUGIN_ROOT"

# ============================================
# Check plugin.json
# ============================================
log_section "Plugin Manifest"

# The plugin.json manifest is required for Claude Code to recognise and load the plugin.
# It may live at the root (development) or in .claude-plugin/ (marketplace convention).
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

            # This script is specific to claude-code-development-kit; name mismatch
            # means the plugin root is pointing to the wrong directory.
            if [[ "$NAME" == "claude-code-development-kit" ]]; then
                log_success "Plugin name is correct: $NAME"
            else
                log_error "Plugin name mismatch: expected 'claude-code-development-kit', got '$NAME'"
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

# These are the skills that must ship with claude-code-development-kit.
# Adding a new skill to the plugin requires updating this list.
EXPECTED_SKILLS=(
    "authoring-agent-prompts"
    "authoring-output-styles"
    "authoring-skills"
    "best-practices-reference"
    "creating-commands"
    "creating-plugins"
    "integrating-mcps"
    "managing-memory"
    "resolving-claude-code-issues"
    "understanding-hooks"
    "using-commands"
    "using-tools"
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

                # YAML frontmatter on line 1 is required for Claude to parse the skill
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

    # Report how many skills were found vs expected (extra skills are allowed)
    SKILL_COUNT=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    log_info "Total skills found: $SKILL_COUNT (expected: ${#EXPECTED_SKILLS[@]})"
fi

# ============================================
# Check Commands Directory
# ============================================
log_section "Commands Validation"

# Commands must live in commands/ as .md files to be loaded as slash commands
COMMANDS_DIR="$PLUGIN_ROOT/commands"

if [[ ! -d "$COMMANDS_DIR" ]]; then
    log_error "commands/ directory not found"
else
    log_success "commands/ directory exists"

    COMMAND_COUNT=$(find "$COMMANDS_DIR" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
    if [[ "$COMMAND_COUNT" -gt 0 ]]; then
        log_success "Commands found: $COMMAND_COUNT"
    else
        log_warning "No command files found"
    fi
fi

# ============================================
# Check Hooks Directory
# ============================================
log_section "Hooks Validation"

# hooks/ must exist; hooks.json declares which events trigger which scripts
HOOKS_DIR="$PLUGIN_ROOT/hooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
    log_error "hooks/ directory not found"
else
    log_success "hooks/ directory exists"

    if [[ -f "$HOOKS_DIR/hooks.json" ]]; then
        log_success "hooks.json exists"

        # Validate hooks.json is parseable JSON before Claude Code tries to load it
        if command -v jq &> /dev/null; then
            if jq empty "$HOOKS_DIR/hooks.json" 2>/dev/null; then
                log_success "hooks.json is valid JSON"
            else
                log_error "hooks.json is not valid JSON"
            fi
        fi
    else
        log_warning "hooks.json not found"
    fi
fi

# ============================================
# Check Output-Styles Directory
# ============================================
log_section "Output-Styles Validation"

OUTPUT_STYLES_DIR="$PLUGIN_ROOT/output-styles"

if [[ ! -d "$OUTPUT_STYLES_DIR" ]]; then
    log_warning "output-styles/ directory not found"
else
    log_success "output-styles/ directory exists"
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
