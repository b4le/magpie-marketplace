#!/bin/bash
# Check registry.yaml is in sync with domain files
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOMAIN_DIR="$PLUGIN_ROOT/skills/archaeology/references/domains"
REGISTRY="$DOMAIN_DIR/registry.yaml"
ERRORS=0

echo "Checking registry sync..."

# Get active/draft domains from registry (those with file != null)
# Confirmed entries are intentionally excluded — they have no .md file by design.
# Using grep/sed since yq may not be available
active_domains=$(awk '/^  - id:/{file=""} /file:/{file=$2} /status: (active|draft)/{if(file) print file}' "$REGISTRY" | tr -d '"')

# shellcheck disable=SC2086  # intentional word-split: active_domains is newline/space-separated filenames with no spaces
for domain_file in $active_domains; do
    filepath="$DOMAIN_DIR/$domain_file"
    if [[ ! -f "$filepath" ]]; then
        echo "  ERROR: Registry references '$domain_file' but file doesn't exist"
        ERRORS=$((ERRORS + 1))
    else
        echo "  OK: $domain_file exists"
    fi
done

# Check for orphan domain files (exist but not in registry)
for filepath in "$DOMAIN_DIR"/*.md; do
    filename=$(basename "$filepath")

    # Skip non-domain files
    [[ "$filename" == "DOMAIN-TEMPLATE.md" ]] && continue
    [[ "$filename" == "ADDING-DOMAINS.md" ]] && continue
    [[ "$filename" == "ADDING-DOMAINS-COMPREHENSIVE.md" ]] && continue

    # Check if file is referenced in registry
    if ! grep -q "file: $filename" "$REGISTRY" && ! grep -q "file: \"$filename\"" "$REGISTRY"; then
        echo "  WARNING: '$filename' exists but not in registry"
        ERRORS=$((ERRORS + 1))
    fi
done

# Report confirmed domains (informational — no files expected by design)
echo ""
echo "Confirmed domains (no .md files expected):"
grep -B2 "status: confirmed" "$REGISTRY" | grep "id:" | sed 's/.*id: */  - /' || true

# Report planned domains (informational)
echo ""
echo "Planned domains (no files expected):"
grep -B2 "status: planned" "$REGISTRY" | grep "id:" | sed 's/.*id: */  - /' || true

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "Sync check found $ERRORS issues"
    exit 1
else
    echo ""
    echo "Registry in sync with domain files"
    exit 0
fi
