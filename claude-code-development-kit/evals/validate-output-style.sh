#!/bin/bash
# validate-output-style.sh - Validates a Claude Code output style file
# Usage: ./validate-output-style.sh <style-path>
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
validate-output-style.sh - Validates a Claude Code output style file

USAGE:
    ./validate-output-style.sh <style-path>
    ./validate-output-style.sh --help

ARGUMENTS:
    style-path    Path to the output style .md file

VALIDATION RULES:
    Required:
        - File must exist with a .md extension

    Checked:
        - File should have markdown heading structure (# / ##)
        - File should reference at least 2 style-related sections
          (format, style, template, structure, output, example, guidelines, rules)
        - File should include at least one example (code block or example section)
        - File should contain actionable directive words
          (must, should, always, never, use, include, format, ensure)
        - File should be 10-300 lines
        - No hardcoded personal paths (e.g., /Users/yourname/)

EXIT CODES:
    0    Validation passed
    1    One or more validation errors found

EXAMPLES:
    ./validate-output-style.sh ./output-styles/executive-brief.md
    ./validate-output-style.sh /path/to/plugin/output-styles/tech-deep-dive.md
EOF
}

# Check for help flag before processing other arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# Check arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <style-path>"
    echo "       $0 --help"
    echo "  style-path: Path to the output style .md file"
    exit 1
fi

STYLE_PATH="$1"

# Resolve to absolute path
if [[ ! "$STYLE_PATH" = /* ]]; then
    STYLE_PATH="$(pwd)/$STYLE_PATH"
fi

echo "=========================================="
echo "Validating Output Style: $STYLE_PATH"
echo "=========================================="

# Check if file exists
if [[ ! -f "$STYLE_PATH" ]]; then
    log_error "Output style file not found: $STYLE_PATH"
    exit 1
fi
log_success "Output style file exists"

# Claude Code requires output style files to use the .md extension
if [[ ! "$STYLE_PATH" =~ \.md$ ]]; then
    log_error "Output style file must have .md extension"
else
    log_success "Correct .md extension"
fi

# Read file content
CONTENT=$(cat "$STYLE_PATH")

# Markdown headings make the style scannable and help Claude navigate sections
STRUCTURE_INDICATORS=(
    "# "           # Top-level heading
    "## "          # Sub-heading
)

HAS_STRUCTURE=false
for indicator in "${STRUCTURE_INDICATORS[@]}"; do
    if grep -q "^$indicator" "$STYLE_PATH"; then
        HAS_STRUCTURE=true
        break
    fi
done

if [[ "$HAS_STRUCTURE" == "true" ]]; then
    log_success "Has heading structure"
else
    log_warning "No markdown headings found - consider adding structure"
fi

# A well-formed output style covers multiple areas (format, rules, examples, etc.)
# Having fewer than 2 style-related sections suggests an incomplete style definition.
STYLE_SECTIONS=(
    "format"
    "style"
    "template"
    "structure"
    "output"
    "example"
    "guidelines"
    "rules"
)

FOUND_SECTIONS=0
for section in "${STYLE_SECTIONS[@]}"; do
    if grep -qi "$section" "$STYLE_PATH"; then
        ((FOUND_SECTIONS++))
    fi
done

if [[ $FOUND_SECTIONS -ge 2 ]]; then
    log_success "Found $FOUND_SECTIONS style-related sections"
elif [[ $FOUND_SECTIONS -eq 1 ]]; then
    log_warning "Only 1 style-related section found. Consider adding more detail."
else
    log_warning "No clear style definition sections found. Expected sections like: format, template, example, guidelines"
fi

# Concrete examples are the most effective way to communicate expected output format
if grep -qE '```|<example>|Example:|EXAMPLE' "$STYLE_PATH"; then
    log_success "Contains examples (code blocks or example sections)"
else
    log_warning "No examples found. Output styles should include example outputs."
fi

# Placeholder patterns signal that the style is a reusable template
if grep -qE '\{[a-zA-Z_]+\}|\$[a-zA-Z_]+|\[\[.*\]\]|<[a-zA-Z_]+>' "$STYLE_PATH"; then
    log_info "Contains placeholder patterns (template variables)"
fi

# Check for personal identifiers
# Exclude common documentation example patterns (username, dev, <username>, yourname, you, example, etc.)
PERSONAL_MATCHES=$(grep -oE '/Users/[a-zA-Z]+|/home/[a-zA-Z]+|C:\\Users\\[a-zA-Z]+' "$STYLE_PATH" 2>/dev/null | grep -vE '/Users/(username|dev|yourname|you|example|user|name|your-username)|/home/(username|dev|yourname|you|example|user|name|your-username)|C:\\Users\\(username|dev|yourname|you|example|user|your-username)' | sort -u || true)

if [[ -n "$PERSONAL_MATCHES" ]]; then
    log_error "Personal identifier found: $PERSONAL_MATCHES"
else
    log_success "No personal identifiers found"
fi

# Check file size
LINE_COUNT=$(wc -l < "$STYLE_PATH" | tr -d ' ')
CHAR_COUNT=$(wc -c < "$STYLE_PATH" | tr -d ' ')

if [[ $LINE_COUNT -lt 10 ]]; then
    log_warning "Output style is very short ($LINE_COUNT lines). May need more detail."
elif [[ $LINE_COUNT -gt 300 ]]; then
    log_warning "Output style is long ($LINE_COUNT lines). Consider splitting into sections."
else
    log_info "File size: $LINE_COUNT lines, $CHAR_COUNT characters"
fi

# Check for actionable instructions
ACTION_WORDS=(
    "must"
    "should"
    "always"
    "never"
    "use"
    "include"
    "format"
    "ensure"
)

ACTION_COUNT=0
for word in "${ACTION_WORDS[@]}"; do
    COUNT=$(grep -oi "\b$word\b" "$STYLE_PATH" 2>/dev/null | wc -l | tr -d ' ')
    ((ACTION_COUNT += COUNT))
done

if [[ $ACTION_COUNT -ge 5 ]]; then
    log_success "Contains actionable instructions ($ACTION_COUNT directive words)"
elif [[ $ACTION_COUNT -ge 1 ]]; then
    log_info "Contains some directives ($ACTION_COUNT found)"
else
    log_warning "No clear directives found. Output styles should have clear instructions."
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
echo -e "${GREEN}Output style validation passed!${NC}"
exit 0
