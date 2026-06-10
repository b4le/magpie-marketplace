#!/bin/bash

# Pre-commit hook to validate Claude Code skill structure
# Checks: frontmatter presence, required fields, line counts, @path validity
#
# Usage:
#   ./validate-skill-structure.sh                    # Validates all skills in default directory
#   ./validate-skill-structure.sh path/to/SKILL.md   # Validates a single skill file
#   SKILLS_DIR=/custom/path ./validate-skill-structure.sh  # Use custom skills directory

set -e

# Allow custom skills directory via environment variable or use default
SKILLS_DIR="${SKILLS_DIR:-$HOME/.claude/skills}"

# When invoked as a Claude Code hook, input comes as JSON on stdin
# with tool_input.file_path containing the path to the written/edited file.
# When invoked manually, pass the file path as $1.
if [ -z "$1" ] && [ ! -t 0 ]; then
  INPUT=$(cat)
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
  if [ -n "$FILE_PATH" ]; then
    set -- "$FILE_PATH"
  fi
fi

ERRORS=()
WARNINGS=()

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Validating skill structure..."

# Function to check if a file has valid YAML frontmatter
check_frontmatter() {
    local file=$1
    local skill_name=$(basename $(dirname "$file"))

    # Check if file starts with ---
    if ! head -n 1 "$file" | grep -q "^---$"; then
        ERRORS+=("$skill_name: Missing YAML frontmatter (must start with ---)")
        return 1
    fi

    # Extract frontmatter (between first and second ---)
    # Use awk for better portability (macOS head doesn't support -n -1)
    local frontmatter=$(awk '/^---$/{if(++n==2)exit;next}n==1' "$file")

    # Check required fields
    if ! echo "$frontmatter" | grep -q "^name:"; then
        ERRORS+=("$skill_name: Missing required field 'name' in frontmatter")
    fi

    if ! echo "$frontmatter" | grep -q "^description:"; then
        ERRORS+=("$skill_name: Missing required field 'description' in frontmatter")
    fi

    if ! echo "$frontmatter" | grep -q "^allowed-tools:"; then
        WARNINGS+=("$skill_name: Missing 'allowed-tools' field (recommended)")
    fi

    if ! echo "$frontmatter" | grep -q "^version:"; then
        WARNINGS+=("$skill_name: Missing 'version' field (recommended)")
    fi

    if ! echo "$frontmatter" | grep -q "^last_updated:"; then
        WARNINGS+=("$skill_name: Missing 'last_updated' field (recommended)")
    fi

    # Check description length (should be 200-400 characters)
    local desc_length=$(echo "$frontmatter" | grep "^description:" | cut -d':' -f2- | tr -d '\n' | wc -c | tr -d ' ')
    if [ "$desc_length" -lt 200 ]; then
        WARNINGS+=("$skill_name: Description too short ($desc_length chars, recommend 200-400)")
    elif [ "$desc_length" -gt 400 ]; then
        WARNINGS+=("$skill_name: Description too long ($desc_length chars, recommend 200-400)")
    fi
}

# Function to check line count
check_line_count() {
    local file=$1
    local skill_name=$(basename $(dirname "$file"))
    local line_count=$(wc -l < "$file" | tr -d ' ')

    if [ "$line_count" -gt 500 ]; then
        ERRORS+=("$skill_name: Exceeds 500 line limit ($line_count lines). Use @path imports to reduce size.")
    fi
}

# Function to check @path imports validity
check_path_imports() {
    local file=$1
    local skill_name=$(basename $(dirname "$file"))
    local skill_dir=$(dirname "$file")

    # Find all @path imports
    grep "@path:" "$file" 2>/dev/null | while read -r line; do
        local import_path=$(echo "$line" | sed 's/.*@path: *\(.*\)/\1/' | tr -d ' ')
        local full_path="$skill_dir/$import_path"

        if [ ! -f "$full_path" ]; then
            ERRORS+=("$skill_name: Invalid @path import '$import_path' - file not found")
        fi
    done
}

# Check if a specific file was provided as argument
if [ -n "$1" ]; then
    # Validate single file
    if [ ! -f "$1" ]; then
        echo -e "${RED}Error: File not found: $1${NC}"
        exit 1
    fi

    check_frontmatter "$1"
    check_line_count "$1"
    check_path_imports "$1"
else
    # Main validation loop for all skills
    if [ ! -d "$SKILLS_DIR" ]; then
        echo -e "${YELLOW}Skills directory not found: $SKILLS_DIR${NC}"
        echo "Set SKILLS_DIR environment variable to specify a custom location."
        exit 0
    fi

    for skill_dir in "$SKILLS_DIR"/*/; do
        # Skip .archive directory
        if [[ "$skill_dir" == *"/.archive/"* ]]; then
            continue
        fi

        skill_file="$skill_dir/SKILL.md"

        # Skip if SKILL.md doesn't exist
        if [ ! -f "$skill_file" ]; then
            continue
        fi

        check_frontmatter "$skill_file"
        check_line_count "$skill_file"
        check_path_imports "$skill_file"
    done
fi

# Print results
echo ""
if [ ${#ERRORS[@]} -gt 0 ]; then
    echo -e "${RED}=== ERRORS ===${NC}"
    for error in "${ERRORS[@]}"; do
        echo -e "  - $error"
    done
    echo ""
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}=== WARNINGS ===${NC}"
    for warning in "${WARNINGS[@]}"; do
        echo -e "  - $warning"
    done
    echo ""
fi

if [ ${#ERRORS[@]} -eq 0 ]; then
    if [ ${#WARNINGS[@]} -eq 0 ]; then
        echo -e "${GREEN}All skills pass validation!${NC}"
    else
        echo -e "${GREEN}No errors found${NC} (but ${#WARNINGS[@]} warnings)"
    fi
    exit 0
else
    echo -e "${RED}Validation failed with ${#ERRORS[@]} error(s)${NC}"
    echo ""
    echo "Fix the errors above before committing."
    exit 1
fi
