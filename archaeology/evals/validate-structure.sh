#!/bin/bash
# validate-structure.sh - Validates archaeology plugin structure
# Usage: ./validate-structure.sh [--help]
# Exit 0 on pass, exit 1 on fail

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# ============================================
# Help
# ============================================
show_help() {
    cat <<EOF
validate-structure.sh — archaeology plugin structure validation

Usage:
  ./validate-structure.sh [--help]

Checks:
  1.  Plugin manifest    — .claude-plugin/plugin.json exists, valid JSON, correct name; version recommended
  2.  Skill directory    — skills/archaeology/ exists, SKILL.md with YAML frontmatter
  3.  Schema             — skills/archaeology/SCHEMA.md exists and is non-empty
  4.  Reference files    — all expected .md references exist
  5.  jq filters         — .jq files exist and have valid syntax (if jq available)
  6.  Domain infra       — domains/ dir, registry.yaml, DOMAIN-TEMPLATE.md
  7.  Scripts            — all 4 scripts exist and are executable
  8.  Delegate validators — runs validate-domains.sh and check-registry-sync.sh
  9.  Version alignment  — SKILL.md version matches plugin.json version
  10. Documentation      — README.md exists
  11. Security           — no hardcoded /Users/<username> paths (outside docs/)

Exit codes:
  0  All checks passed
  1  One or more errors found
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

echo "=========================================="
echo "STRUCT: archaeology Structure Validation"
echo "=========================================="
echo "Plugin Root: $PLUGIN_ROOT"

# ============================================
# 1. Plugin Manifest
# ============================================
log_section "Plugin Manifest"

PLUGIN_JSON=""
if [[ -f "$PLUGIN_ROOT/plugin.json" ]]; then
    PLUGIN_JSON="$PLUGIN_ROOT/plugin.json"
elif [[ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]]; then
    PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
fi

PLUGIN_VERSION=""

if [[ -z "$PLUGIN_JSON" ]]; then
    log_error "plugin.json not found (checked plugin.json and .claude-plugin/plugin.json)"
else
    log_success "plugin.json exists: ${PLUGIN_JSON#"$PLUGIN_ROOT/"}"

    if command -v jq &> /dev/null; then
        if jq empty "$PLUGIN_JSON" 2>/dev/null; then
            log_success "plugin.json is valid JSON"

            NAME=$(jq -r '.name // empty' "$PLUGIN_JSON")
            PLUGIN_VERSION=$(jq -r '.version // empty' "$PLUGIN_JSON")
            DESCRIPTION=$(jq -r '.description // empty' "$PLUGIN_JSON")

            if [[ "$NAME" == "archaeology" ]]; then
                log_success "Plugin name is correct: $NAME"
            else
                log_error "Plugin name mismatch: expected 'archaeology', got '$NAME'"
            fi

            # version is optional per plugin.schema.json ("Strongly recommended
            # but not required").  Treat absence as a warning, not an error.
            if [[ -n "$PLUGIN_VERSION" ]]; then
                log_success "Version present: $PLUGIN_VERSION"
            else
                log_warning "Version field missing from plugin.json (strongly recommended)"
            fi

            if [[ -n "$DESCRIPTION" ]]; then
                log_success "Description present"
            else
                log_warning "Description field missing from plugin.json"
            fi
        else
            log_error "plugin.json is not valid JSON"
        fi
    else
        log_warning "jq not installed — skipping JSON validation"
    fi
fi

# ============================================
# 2. Skill Directory
# ============================================
log_section "Skills Validation"

SKILL_DIR="$PLUGIN_ROOT/skills/archaeology"
SKILL_MD="$SKILL_DIR/SKILL.md"
SKILL_VERSION=""

if [[ ! -d "$PLUGIN_ROOT/skills" ]]; then
    log_error "skills/ directory not found"
elif [[ ! -d "$SKILL_DIR" ]]; then
    log_error "skills/archaeology/ directory not found"
else
    log_success "skills/archaeology/ directory exists"

    if [[ -f "$SKILL_MD" ]]; then
        log_success "skills/archaeology/SKILL.md exists"

        if head -1 "$SKILL_MD" | grep -q "^---"; then
            log_success "YAML frontmatter present in SKILL.md"

            # Extract version from frontmatter
            SKILL_VERSION=$(awk '/^---/{f++; next} f==1 && /^version:/{print $2; exit}' "$SKILL_MD")
            if [[ -n "$SKILL_VERSION" ]]; then
                log_success "SKILL.md version field present: $SKILL_VERSION"
            else
                log_warning "SKILL.md version field not found in frontmatter"
            fi
        else
            log_error "YAML frontmatter missing from SKILL.md (expected '---' on line 1)"
        fi
    else
        log_error "skills/archaeology/SKILL.md not found"
    fi
fi

SKILL_COUNT=$(find "$PLUGIN_ROOT/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
log_info "Total skills found: $SKILL_COUNT (expected: 1)"

# ============================================
# 3. Schema
# ============================================
log_section "Schema"

SCHEMA_MD="$SKILL_DIR/SCHEMA.md"

if [[ -f "$SCHEMA_MD" ]]; then
    if [[ -s "$SCHEMA_MD" ]]; then
        log_success "skills/archaeology/SCHEMA.md exists and is non-empty"
    else
        log_error "skills/archaeology/SCHEMA.md exists but is empty"
    fi
else
    log_error "skills/archaeology/SCHEMA.md not found"
fi

# ============================================
# 4. Reference Files
# ============================================
log_section "Reference Files"

REFS_DIR="$SKILL_DIR/references"
EXPECTED_REFS=(
    "branding.md"
    "conserve-workflow.md"
    "consumption-spec.md"
    "conversation-parser.md"
    "excavation-workflow.md"
    "output-templates.md"
    "survey-workflow.md"
    "workstyle-workflow.md"
)

if [[ ! -d "$REFS_DIR" ]]; then
    log_error "skills/archaeology/references/ directory not found"
else
    log_success "skills/archaeology/references/ directory exists"

    for ref in "${EXPECTED_REFS[@]}"; do
        if [[ -f "$REFS_DIR/$ref" ]]; then
            log_success "Reference exists: $ref"
        else
            log_error "Reference not found: $ref"
        fi
    done
fi

# ============================================
# 5. jq Filters
# ============================================
log_section "jq Filters"

EXPECTED_JQ_FILTERS=(
    "jsonl-filter.jq"
    "jsonl-tool-names.jq"
)

for filter in "${EXPECTED_JQ_FILTERS[@]}"; do
    FILTER_PATH="$REFS_DIR/$filter"
    if [[ -f "$FILTER_PATH" ]]; then
        log_success "jq filter exists: $filter"

        if command -v jq &> /dev/null; then
            if jq -n -f "$FILTER_PATH" . &>/dev/null 2>&1 || jq --null-input --rawfile f "$FILTER_PATH" 'null' &>/dev/null 2>&1; then
                log_success "jq filter syntax valid: $filter"
            else
                # Syntax check via jq -e: parse errors exit non-zero
                if jq -n -f "$FILTER_PATH" &>/dev/null; then
                    log_success "jq filter syntax valid: $filter"
                else
                    log_warning "jq filter may have syntax issues (could require input): $filter"
                fi
            fi
        else
            log_warning "jq not installed — skipping syntax check for $filter"
        fi
    else
        log_error "jq filter not found: $filter"
    fi
done

# ============================================
# 6. Domain Infrastructure
# ============================================
log_section "Domain Infrastructure"

DOMAINS_DIR="$REFS_DIR/domains"

if [[ ! -d "$DOMAINS_DIR" ]]; then
    log_error "skills/archaeology/references/domains/ directory not found"
else
    log_success "skills/archaeology/references/domains/ directory exists"

    if [[ -f "$DOMAINS_DIR/registry.yaml" ]]; then
        log_success "domains/registry.yaml exists"
    else
        log_error "domains/registry.yaml not found"
    fi

    if [[ -f "$DOMAINS_DIR/DOMAIN-TEMPLATE.md" ]]; then
        log_success "domains/DOMAIN-TEMPLATE.md exists"
    else
        log_error "domains/DOMAIN-TEMPLATE.md not found"
    fi

    DOMAIN_COUNT=$(find "$DOMAINS_DIR" -maxdepth 1 -name "*.md" ! -name "DOMAIN-TEMPLATE.md" ! -name "ADDING-DOMAINS*.md" | wc -l | tr -d ' ')
    log_info "Active domain files found: $DOMAIN_COUNT"
    if [[ "$DOMAIN_COUNT" -eq 0 ]]; then
        log_warning "No active domain .md files found in domains/"
    fi
fi

# ============================================
# 7. Scripts
# ============================================
log_section "Scripts"

SCRIPTS_DIR="$PLUGIN_ROOT/scripts"
EXPECTED_SCRIPTS=(
    "archaeology-excavation.sh"
    "check-registry-sync.sh"
    "prep-rig.sh"
    "validate-conserve.sh"
    "validate-dig.sh"
    "validate-domains.sh"
)

if [[ ! -d "$SCRIPTS_DIR" ]]; then
    log_error "scripts/ directory not found"
else
    log_success "scripts/ directory exists"

    for script in "${EXPECTED_SCRIPTS[@]}"; do
        SCRIPT_PATH="$SCRIPTS_DIR/$script"
        if [[ -f "$SCRIPT_PATH" ]]; then
            log_success "Script exists: $script"
            if [[ -x "$SCRIPT_PATH" ]]; then
                log_success "Script is executable: $script"
            else
                log_error "Script is not executable: $script"
            fi
        else
            log_error "Script not found: $script"
        fi
    done
fi

# ============================================
# 8. Delegate Validators
# ============================================
log_section "Delegate Validators"

VALIDATE_DOMAINS="$SCRIPTS_DIR/validate-domains.sh"
CHECK_REGISTRY="$SCRIPTS_DIR/check-registry-sync.sh"

if [[ -x "$VALIDATE_DOMAINS" ]]; then
    log_info "Running validate-domains.sh..."
    if "$VALIDATE_DOMAINS" 2>&1; then
        log_success "validate-domains.sh passed"
    else
        log_error "validate-domains.sh reported failures"
    fi
else
    log_warning "validate-domains.sh not executable — skipping"
fi

if [[ -x "$CHECK_REGISTRY" ]]; then
    log_info "Running check-registry-sync.sh..."
    if "$CHECK_REGISTRY" 2>&1; then
        log_success "check-registry-sync.sh passed"
    else
        log_error "check-registry-sync.sh reported failures"
    fi
else
    log_warning "check-registry-sync.sh not executable — skipping"
fi

# ============================================
# 9. Version Alignment
# ============================================
log_section "Version Alignment"

if [[ -n "$PLUGIN_VERSION" && -n "$SKILL_VERSION" ]]; then
    if [[ "$SKILL_VERSION" == "$PLUGIN_VERSION" ]]; then
        log_success "Version aligned: SKILL.md ($SKILL_VERSION) matches plugin.json ($PLUGIN_VERSION)"
    else
        log_error "Version mismatch: SKILL.md has '$SKILL_VERSION', plugin.json has '$PLUGIN_VERSION'"
    fi
else
    log_warning "Cannot check version alignment — one or both versions could not be read"
fi

# ============================================
# 10. Documentation
# ============================================
log_section "Documentation"

if [[ -f "$PLUGIN_ROOT/README.md" ]]; then
    log_success "README.md exists"
else
    log_error "README.md not found"
fi

# ============================================
# 11. Security: No Hardcoded Personal Paths
# ============================================
log_section "Security"

# Grep source files only — exclude docs/ and binary/generated content.
# Two-pass approach: first find files with /Users/<word> or /home/<word>,
# then exclude files where EVERY match is a generic placeholder path
# (e.g., /Users/username/...) used in documentation examples.
GENERIC_NAMES="username|user|yourname|you|example|dev|name|someone|person"
CANDIDATE_FILES=$(grep -r --include="*.sh" --include="*.md" --include="*.json" --include="*.yaml" --include="*.jq" \
    -l "/Users/[^/]" "$PLUGIN_ROOT" \
    --exclude-dir="docs" \
    --exclude-dir="evals" \
    2>/dev/null || true)

HARDCODED=""
while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    # Extract matching lines, then filter out generic placeholder paths
    real_hits=$(grep -E '/Users/[a-zA-Z][a-zA-Z0-9._-]+|/home/[a-zA-Z][a-zA-Z0-9._-]+' "$candidate" 2>/dev/null \
        | grep -vE "/Users/(${GENERIC_NAMES})|/home/(${GENERIC_NAMES})" || true)
    if [[ -n "$real_hits" ]]; then
        HARDCODED="${HARDCODED}${candidate}"$'\n'
    fi
done <<< "$CANDIDATE_FILES"

if [[ -z "$HARDCODED" ]]; then
    log_success "No hardcoded personal paths found"
else
    log_warning "Possible hardcoded personal paths in:"
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        log_warning "  ${f#"$PLUGIN_ROOT/"}"
    done <<< "$HARDCODED"
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
