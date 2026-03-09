#!/bin/bash
# validate-research-output.sh - Validates web-researcher agent output before returning to caller
# Usage: ./validate-research-output.sh <output-file>
# Exit 0 on pass, exit 1 on fail (fail-open: exit 0 if file unreadable)

set -euo pipefail

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

# Check arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <output-file>"
    exit 1
fi

OUTPUT_FILE="$1"

echo "=========================================="
echo "Validating Research Output: $OUTPUT_FILE"
echo "=========================================="

# Fail-open: if file can't be read, exit 0
if [[ ! -f "$OUTPUT_FILE" ]] || [[ ! -r "$OUTPUT_FILE" ]]; then
    log_info "Output file not readable: $OUTPUT_FILE — skipping validation"
    exit 0
fi

CONTENT=$(cat "$OUTPUT_FILE")

# ---- Required Section Checks ----

if echo "$CONTENT" | grep -q "^## Summary"; then
    log_success "Section '## Summary' present"
else
    log_error "Required section '## Summary' missing"
fi

if echo "$CONTENT" | grep -iq "confidence:"; then
    log_success "Summary contains 'confidence:' field"
else
    log_error "Summary missing 'confidence:' field (expected: high/medium/low)"
fi

if echo "$CONTENT" | grep -iq "status:"; then
    log_success "Summary contains 'status:' field"
else
    log_error "Summary missing 'status:' field (expected: complete/partial/blocked)"
fi

if echo "$CONTENT" | grep -q "^## Key Findings"; then
    log_success "Section '## Key Findings' present"
else
    log_error "Required section '## Key Findings' missing"
fi

if echo "$CONTENT" | grep -q "^## Sources"; then
    log_success "Section '## Sources' present"
else
    log_error "Required section '## Sources' missing"
fi

if echo "$CONTENT" | grep -q "^## Gaps"; then
    log_success "Section '## Gaps' present"
else
    log_error "Required section '## Gaps' missing"
fi

# ---- Size Checks ----

WORD_COUNT=$(echo "$CONTENT" | wc -w | tr -d ' ')

if [[ "$WORD_COUNT" -gt 800 ]]; then
    log_error "Word count ($WORD_COUNT) exceeds 800-word limit"
elif [[ "$WORD_COUNT" -gt 600 ]]; then
    log_warning "Word count ($WORD_COUNT) is approaching 800-word limit"
else
    log_success "Word count within limit ($WORD_COUNT / 800)"
fi

# ---- Content Quality Checks ----

if echo "$CONTENT" | grep -q "http"; then
    log_success "At least one URL present in output"
else
    log_error "No URLs found — Key Findings or Sources must include at least one http link"
fi

if echo "$CONTENT" | grep -qE '<div|<span|<table|<script|<html|<body'; then
    log_error "Raw HTML tags detected — output may contain unprocessed WebFetch content"
else
    log_success "No raw HTML tags detected"
fi

# ---- Summary ----

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
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning"
    done
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Research output validation failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Research output validation passed!${NC}"
exit 0
