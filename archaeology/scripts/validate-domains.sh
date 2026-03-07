#!/bin/bash
# Validate domain files against SCHEMA.md

DOMAIN_DIR="${HOME}/.claude/skills/archaeology/references/domains"
ERRORS=0

for domain_file in "$DOMAIN_DIR"/*.md; do
    filename=$(basename "$domain_file")

    # Skip non-domain files
    [[ "$filename" == "DOMAIN-TEMPLATE.md" ]] && continue
    [[ "$filename" == "ADDING-DOMAINS.md" ]] && continue
    [[ "$filename" == "ADDING-DOMAINS-COMPREHENSIVE.md" ]] && continue
    [[ "$filename" =~ ^registry ]] && continue

    echo "Validating $filename..."

    # Extract YAML frontmatter
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$domain_file" | sed '1d;$d')

    if [[ -z "$frontmatter" ]]; then
        echo "  ERROR: No YAML frontmatter found"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Check required fields using grep on frontmatter
    required_fields=("domain:" "status:" "maintainer:" "last_updated:" "version:" "agent_count:" "keywords:" "locations:" "outputs:")

    for field in "${required_fields[@]}"; do
        if ! echo "$frontmatter" | grep -q "$field"; then
            echo "  ERROR: Missing required field: $field"
            ERRORS=$((ERRORS + 1))
        fi
    done

    # Check domain matches filename
    domain_value=$(echo "$frontmatter" | grep "^domain:" | sed 's/domain: *//')
    expected_domain="${filename%.md}"
    if [[ "$domain_value" != "$expected_domain" ]]; then
        echo "  ERROR: domain '$domain_value' doesn't match filename '$expected_domain'"
        ERRORS=$((ERRORS + 1))
    fi

    # Check status is valid enum
    status_value=$(echo "$frontmatter" | grep "^status:" | sed 's/status: *//')
    if [[ ! "$status_value" =~ ^(active|planned|deprecated|archived)$ ]]; then
        echo "  ERROR: Invalid status '$status_value' (must be active|planned|deprecated|archived)"
        ERRORS=$((ERRORS + 1))
    fi
done

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "Validation failed with $ERRORS errors"
    exit 1
else
    echo ""
    echo "All domain files valid"
    exit 0
fi
