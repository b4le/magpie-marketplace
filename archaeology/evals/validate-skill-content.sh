#!/bin/bash
# validate-skill-content.sh - Content and schema integrity validator for the archaeology plugin
#
# Validates SKILL.md frontmatter, body integrity, SCHEMA.md, reference files,
# jq filter syntax, domain cross-references, and version alignment.
#
# Usage:
#   ./validate-skill-content.sh [--help]
#
# Exit codes:
#   0  All checks passed (warnings are non-fatal)
#   1  One or more errors found
#
# Requires: bash 3.2+, grep, awk, wc
# Optional: jq (for jq filter syntax validation)

set -e

# ---------------------------------------------------------------------------
# Colours and logging
# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

log_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

show_help() {
    cat << 'EOF'
validate-skill-content.sh - Content and schema integrity validator for the archaeology plugin

USAGE:
    ./validate-skill-content.sh [--help|-h]

DESCRIPTION:
    Validates the archaeology skill's content and structural integrity:
      1. SKILL.md frontmatter completeness
      2. SKILL.md body integrity (commands, workflow steps, references)
      3. SCHEMA.md integrity (sections, field definitions)
      4. Reference file completeness and non-emptiness
      5. jq filter syntax validity (requires jq)
      6. Domain file cross-reference consistency
      7. Version alignment between SKILL.md and plugin.json

OPTIONS:
    --help, -h    Show this help and exit

EXIT CODES:
    0    All checks passed (warnings are non-fatal)
    1    One or more errors found

EXAMPLES:
    # Run from any directory
    ./archaeology/evals/validate-skill-content.sh

    # Run from the monorepo root
    bash archaeology/evals/validate-skill-content.sh
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# ---------------------------------------------------------------------------
# Path setup — derive everything from the script's own location
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
SKILL_DIR="$PLUGIN_ROOT/skills/archaeology"
SKILL_FILE="$SKILL_DIR/SKILL.md"
SCHEMA_FILE="$SKILL_DIR/SCHEMA.md"
REFS_DIR="$SKILL_DIR/references"
DOMAINS_DIR="$REFS_DIR/domains"
# Check both possible plugin.json locations (consistent with validate-structure.sh)
if [[ -f "$PLUGIN_ROOT/plugin.json" ]]; then
    PLUGIN_JSON="$PLUGIN_ROOT/plugin.json"
elif [[ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]]; then
    PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
else
    PLUGIN_JSON=""
fi

echo "=========================================="
echo "Archaeology Skill Content Validator"
echo "=========================================="
log_info "Plugin root: $PLUGIN_ROOT"
log_info "Skill dir:   $SKILL_DIR"

# ---------------------------------------------------------------------------
# Section 1: SKILL.md frontmatter completeness
# ---------------------------------------------------------------------------

log_section "1. SKILL.md Frontmatter"

if [[ ! -f "$SKILL_FILE" ]]; then
    log_error "SKILL.md not found: $SKILL_FILE"
    # Cannot continue without the file — bail out early with summary
    echo ""
    echo "=========================================="
    echo "VALIDATION SUMMARY"
    echo "=========================================="
    echo "Errors:   ${#ERRORS[@]}"
    echo "Warnings: ${#WARNINGS[@]}"
    exit 1
fi
log_success "SKILL.md exists"

# Read entire file into variable for repeated scanning (file is <500 lines)
SKILL_CONTENT=$(cat "$SKILL_FILE")
SKILL_LINE_COUNT=$(wc -l < "$SKILL_FILE" | tr -d ' ')

# Check frontmatter delimiters
if ! echo "$SKILL_CONTENT" | grep -q "^---$"; then
    log_error "SKILL.md: YAML frontmatter delimiters (---) not found"
else
    log_success "SKILL.md: YAML frontmatter delimiters present"
fi

# Extract content between the first and second --- markers
FRONTMATTER=$(echo "$SKILL_CONTENT" | awk '/^---$/{p++; next} p==1{print}')

# Practically required fields — name and description are needed for Claude
# Code to discover and display the skill, even though the schema marks all
# frontmatter fields as optional.  The devkit's validate-skill.sh treats these
# two as errors and the remainder as warnings.
for field in name description; do
    if echo "$FRONTMATTER" | grep -q "^${field}:"; then
        log_success "Frontmatter field '${field}' present"
    else
        log_error "Frontmatter field '${field}' missing"
    fi
done

# Recommended fields — useful for functionality or metadata but not required
# by the Claude Code runtime.  'argument-hint' controls completion hints,
# 'allowed-tools' restricts tool access, 'version' is extension metadata only.
for field in argument-hint allowed-tools version; do
    if echo "$FRONTMATTER" | grep -q "^${field}:"; then
        log_success "Frontmatter field '${field}' present"
    else
        log_warning "Frontmatter field '${field}' missing (recommended)"
    fi
done

# name must equal "archaeology"
NAME_VALUE=$(echo "$FRONTMATTER" | grep "^name:" | sed 's/^name:[[:space:]]*//' | tr -d '\r')
if [[ "$NAME_VALUE" == "archaeology" ]]; then
    log_success "Frontmatter 'name' equals 'archaeology'"
else
    log_error "Frontmatter 'name' is '${NAME_VALUE}', expected 'archaeology'"
fi

# allowed-tools must include: Read, Write, Bash, Glob, Grep, Agent
# The list is YAML block sequence (one entry per line starting with "  - ")
# Collect all tool entries following allowed-tools: up to the next top-level key
ALLOWED_TOOLS_BLOCK=$(echo "$FRONTMATTER" | awk '/^allowed-tools:/{found=1; next} found && /^[a-zA-Z]/{exit} found{print}')
for required_tool in Read Write Bash Glob Grep Agent; do
    if echo "$ALLOWED_TOOLS_BLOCK" | grep -q "^[[:space:]]*-[[:space:]]*${required_tool}[[:space:]]*$"; then
        log_success "allowed-tools includes '${required_tool}'"
    else
        log_error "allowed-tools missing required tool: '${required_tool}'"
    fi
done

# version must match semver x.y.z
VERSION_VALUE=$(echo "$FRONTMATTER" | grep "^version:" | sed 's/^version:[[:space:]]*//' | tr -d '\r')
if echo "$VERSION_VALUE" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    log_success "Frontmatter 'version' is valid semver: $VERSION_VALUE"
else
    log_error "Frontmatter 'version' does not match semver pattern (got: '${VERSION_VALUE}')"
fi

# ---------------------------------------------------------------------------
# Section 2: SKILL.md body integrity
# ---------------------------------------------------------------------------

log_section "2. SKILL.md Body Integrity"

# Extract body — everything after the closing --- of frontmatter
BODY=$(echo "$SKILL_CONTENT" | awk '/^---$/{p++; next} p>=2{print}')
BODY_LINE_COUNT=$(echo "$BODY" | wc -l | tr -d ' ')

if [[ "$BODY_LINE_COUNT" -gt 100 ]]; then
    log_success "SKILL.md body is non-trivially long ($BODY_LINE_COUNT lines after frontmatter)"
else
    log_error "SKILL.md body is too short ($BODY_LINE_COUNT lines after frontmatter, expected >100)"
fi

# Required command keywords
for cmd in survey list workstyle conserve excavation; do
    if echo "$BODY" | grep -q "$cmd"; then
        log_success "Body contains command keyword: '$cmd'"
    else
        log_error "Body missing command keyword: '$cmd'"
    fi
done

# Workflow step markers live in the workflow reference files, not in SKILL.md.
# Each workflow file declares its step range in its heading/preamble (e.g. "Steps S1-S7").
# We check that each workflow reference file contains its expected step markers.
# Parallel arrays for Bash 3.2 compatibility (no associative arrays).
WORKFLOW_STEP_FILES=("survey-workflow.md" "workstyle-workflow.md" "conserve-workflow.md")
WORKFLOW_STEP_PREFIXES=("S" "W" "C")

for i in 0 1 2; do
    wf_file="${WORKFLOW_STEP_FILES[$i]}"
    prefix="${WORKFLOW_STEP_PREFIXES[$i]}"
    wf_path="$REFS_DIR/$wf_file"
    if [[ ! -f "$wf_path" ]]; then
        # Already reported missing in section 4
        continue
    fi
    missing_steps=""
    for n in 1 2 3 4 5 6 7; do
        if ! grep -q "${prefix}${n}" "$wf_path"; then
            missing_steps="${missing_steps} ${prefix}${n}"
        fi
    done
    if [[ -z "$missing_steps" ]]; then
        log_success "Workflow step markers present (${prefix}1-${prefix}7): references/$wf_file"
    else
        log_error "Workflow step markers missing in references/$wf_file:${missing_steps}"
    fi
done

# Body references SCHEMA.md
if echo "$BODY" | grep -q "SCHEMA"; then
    log_success "Body references SCHEMA.md"
else
    log_warning "Body does not appear to reference SCHEMA.md"
fi

# ---------------------------------------------------------------------------
# Section 3: SCHEMA.md integrity
# ---------------------------------------------------------------------------

log_section "3. SCHEMA.md Integrity"

if [[ ! -f "$SCHEMA_FILE" ]]; then
    log_error "SCHEMA.md not found: $SCHEMA_FILE"
else
    SCHEMA_CONTENT=$(cat "$SCHEMA_FILE")
    SCHEMA_LINE_COUNT=$(wc -l < "$SCHEMA_FILE" | tr -d ' ')

    if [[ "$SCHEMA_LINE_COUNT" -gt 0 ]]; then
        log_success "SCHEMA.md exists and is non-empty ($SCHEMA_LINE_COUNT lines)"
    else
        log_error "SCHEMA.md is empty"
    fi

    # Required section headings (as # headings anywhere in the file)
    for section in "Domain" "Finding" "Workstyle" "Artifact"; do
        if echo "$SCHEMA_CONTENT" | grep -q "^#.*${section}"; then
            log_success "SCHEMA.md contains '${section}' section heading"
        else
            log_error "SCHEMA.md missing '${section}' section heading"
        fi
    done

    # Field definition indicators: type:, required:, enum: (as table columns or YAML keys)
    for indicator in "type" "required" "enum"; do
        if echo "$SCHEMA_CONTENT" | grep -qi "${indicator}"; then
            log_success "SCHEMA.md contains field indicator '${indicator}'"
        else
            log_warning "SCHEMA.md appears to lack field indicator '${indicator}'"
        fi
    done
fi

# ---------------------------------------------------------------------------
# Section 4: Reference file completeness
# ---------------------------------------------------------------------------

log_section "4. Reference File Completeness"

EXPECTED_REFS=(
    "branding.md"
    "conserve-workflow.md"
    "consumption-spec.md"
    "conversation-parser.md"
    "excavation-workflow.md"
    "survey-workflow.md"
    "workstyle-workflow.md"
    "output-templates.md"
)

for ref in "${EXPECTED_REFS[@]}"; do
    ref_path="$REFS_DIR/$ref"
    if [[ ! -f "$ref_path" ]]; then
        log_error "Reference file missing: references/$ref"
        continue
    fi
    ref_lines=$(wc -l < "$ref_path" | tr -d ' ')
    if [[ "$ref_lines" -le 5 ]]; then
        log_error "Reference file is nearly empty ($ref_lines lines): references/$ref"
    else
        log_success "Reference file exists and non-empty ($ref_lines lines): references/$ref"
    fi
done

# Workflow references must contain numbered steps
WORKFLOW_REFS=(
    "survey-workflow.md"
    "workstyle-workflow.md"
    "conserve-workflow.md"
    "excavation-workflow.md"
)

for wf in "${WORKFLOW_REFS[@]}"; do
    wf_path="$REFS_DIR/$wf"
    if [[ ! -f "$wf_path" ]]; then
        # Already reported missing above
        continue
    fi
    # Look for numbered step patterns: "1.", "Step 1", "S1", "W1", "C1", "E1"
    if grep -qE '(^|\s)(Step\s+[0-9]+|[0-9]+\.|[SWCE][0-9]+)' "$wf_path"; then
        log_success "Workflow reference contains numbered steps: references/$wf"
    else
        log_error "Workflow reference lacks numbered steps: references/$wf"
    fi
done

# ---------------------------------------------------------------------------
# Section 5: jq filter validity
# ---------------------------------------------------------------------------

log_section "5. jq Filter Validity"

JQ_FILTERS=(
    "jsonl-filter.jq"
    "jsonl-tool-names.jq"
)

for jqf in "${JQ_FILTERS[@]}"; do
    jqf_path="$REFS_DIR/$jqf"
    if [[ ! -f "$jqf_path" ]]; then
        log_error "jq filter missing: references/$jqf"
        continue
    fi
    jqf_lines=$(wc -l < "$jqf_path" | tr -d ' ')
    if [[ "$jqf_lines" -eq 0 ]]; then
        log_error "jq filter is empty: references/$jqf"
        continue
    fi
    log_success "jq filter exists and non-empty ($jqf_lines lines): references/$jqf"

    # Syntax check if jq is available
    if command -v jq > /dev/null 2>&1; then
        filter_content=$(cat "$jqf_path")
        # Validate by piping null input through the filter; suppress output
        if jq -e -n "null | $filter_content" > /dev/null 2>&1; then
            log_success "jq filter syntax valid: references/$jqf"
        else
            # Many filters require actual JSONL input (they reference . on stream),
            # so a syntax error vs a runtime error needs distinguishing.
            # Use `jq -n 'null' | jq -f` to check parse-only.
            if jq -n '.' > /dev/null 2>&1 && echo "null" | jq -f "$jqf_path" > /dev/null 2>&1; then
                log_success "jq filter syntax valid (stream mode): references/$jqf"
            else
                # Last resort: check jq can at least parse the file without crashing
                if jq -n -f "$jqf_path" > /dev/null 2>&1; then
                    log_success "jq filter syntax valid (null input): references/$jqf"
                else
                    log_warning "jq filter may have syntax issues (could require streaming input): references/$jqf"
                fi
            fi
        fi
    else
        log_info "jq not available — skipping syntax check for references/$jqf"
    fi
done

# ---------------------------------------------------------------------------
# Section 6: Domain file cross-reference
# ---------------------------------------------------------------------------

log_section "6. Domain File Cross-Reference"

if [[ ! -d "$DOMAINS_DIR" ]]; then
    log_error "Domains directory missing: references/domains/"
else
    log_success "Domains directory exists: references/domains/"

    REGISTRY_FILE="$DOMAINS_DIR/registry.yaml"
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        log_error "Domain registry missing: references/domains/registry.yaml"
    else
        log_success "Domain registry exists: references/domains/registry.yaml"
    fi

    # Cross-reference: every active domain in registry.yaml should have a
    # corresponding .md file in domains/, and should be mentioned somewhere in
    # SKILL.md (typically in the argument examples or command list).
    #
    # This is a documentation-completeness check, not a runtime requirement.
    # The skill reads domains dynamically from registry.yaml at runtime, so a
    # missing mention in SKILL.md does not break the plugin — it just means the
    # user documentation is incomplete.  Demoted to warnings accordingly.
    if [[ -f "$REGISTRY_FILE" ]]; then
        # Extract active domain IDs from registry.yaml (lines matching "id: <name>")
        REGISTRY_DOMAINS=$(grep -E '^\s+- id:' "$REGISTRY_FILE" | sed 's/.*id:[[:space:]]*//' | tr -d '\r' | sort)

        if [[ -z "$REGISTRY_DOMAINS" ]]; then
            log_warning "Could not extract domain IDs from registry.yaml"
        else
            while IFS= read -r domain; do
                [[ -z "$domain" ]] && continue
                domain_file="$DOMAINS_DIR/${domain}.md"

                # Check domain .md file exists
                if [[ -f "$domain_file" ]]; then
                    log_success "Domain file exists for '$domain': references/domains/${domain}.md"
                else
                    log_error "Domain '$domain' in registry.yaml but no .md file: references/domains/${domain}.md"
                fi

                # Check domain is mentioned in SKILL.md (documentation completeness)
                if echo "$SKILL_CONTENT" | grep -q "$domain"; then
                    log_success "Domain '$domain' mentioned in SKILL.md"
                else
                    log_warning "Domain '$domain' not mentioned in SKILL.md (documentation gap, not a runtime issue)"
                fi
            done <<< "$REGISTRY_DOMAINS"
        fi
    fi

    # DOMAIN-TEMPLATE.md should contain placeholder fields matching SCHEMA.md field names
    TEMPLATE_FILE="$DOMAINS_DIR/DOMAIN-TEMPLATE.md"
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        log_error "DOMAIN-TEMPLATE.md missing: references/domains/DOMAIN-TEMPLATE.md"
    else
        TEMPLATE_CONTENT=$(cat "$TEMPLATE_FILE")
        log_success "DOMAIN-TEMPLATE.md exists"

        # Expected placeholders derived from Domain File Schema in SCHEMA.md
        for placeholder in "DOMAIN_NAME" "status" "maintainer" "last_updated" "version"; do
            if echo "$TEMPLATE_CONTENT" | grep -qi "$placeholder"; then
                log_success "DOMAIN-TEMPLATE.md contains placeholder/field: '$placeholder'"
            else
                log_warning "DOMAIN-TEMPLATE.md may be missing placeholder/field: '$placeholder'"
            fi
        done
    fi
fi

# ---------------------------------------------------------------------------
# Section 7: Version alignment
# ---------------------------------------------------------------------------

log_section "7. Version Alignment"

if [[ -z "$PLUGIN_JSON" ]]; then
    log_error "plugin.json not found (checked plugin.json and .claude-plugin/plugin.json)"
else
    # Extract version from plugin.json — works without jq using grep + sed
    if command -v jq > /dev/null 2>&1; then
        PLUGIN_VERSION=$(jq -r '.version // empty' "$PLUGIN_JSON" 2>/dev/null || true)
    else
        PLUGIN_VERSION=$(grep '"version"' "$PLUGIN_JSON" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    fi

    if [[ -z "$PLUGIN_VERSION" ]]; then
        log_error "Could not extract version from plugin.json"
    else
        log_info "plugin.json version: $PLUGIN_VERSION"
        log_info "SKILL.md version:    $VERSION_VALUE"

        if [[ "$VERSION_VALUE" == "$PLUGIN_VERSION" ]]; then
            log_success "Version aligned: SKILL.md ($VERSION_VALUE) matches plugin.json ($PLUGIN_VERSION)"
        else
            log_error "Version mismatch: SKILL.md has '$VERSION_VALUE', plugin.json has '$PLUGIN_VERSION'"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "=========================================="
echo "VALIDATION SUMMARY"
echo "=========================================="
echo "Errors:   ${#ERRORS[@]}"
echo "Warnings: ${#WARNINGS[@]}"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo "Failed checks:"
    for error in "${ERRORS[@]}"; do
        echo "  - $error"
    done
    echo ""
    echo -e "${RED}SKILL-CONTENT: FAILED${NC}"
    exit 1
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning"
    done
fi

echo ""
echo -e "${GREEN}SKILL-CONTENT: PASSED${NC}"
exit 0
