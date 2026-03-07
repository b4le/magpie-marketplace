#!/bin/bash
# Check registry.yaml is in sync with domain files

DOMAIN_DIR="${HOME}/.claude/skills/archaeology/references/domains"
REGISTRY="$DOMAIN_DIR/registry.yaml"
ERRORS=0

echo "Checking registry sync..."

# Get active domains from registry (those with file != null)
# Using grep/sed since yq may not be available
active_domains=$(awk '/^  - id:/{block=""} /file:/{file=$2} /status: active/{if(file) print file}' "$REGISTRY" | tr -d '"')

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

# Report planned domains (informational)
echo ""
echo "Planned domains (no files expected):"
grep -B2 "status: planned" "$REGISTRY" | grep "id:" | sed 's/.*id: */  - /'

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "Sync check found $ERRORS issues"
    exit 1
else
    echo ""
    echo "Registry in sync with domain files"
    exit 0
fi
