# Plugin Evaluation Scripts

Reusable shell scripts for validating Claude Code plugin components. These scripts help ensure quality and consistency before distribution.

## Quick Start

```bash
# Make scripts executable (one-time setup)
chmod +x *.sh

# Validate a complete plugin
./validate-plugin.sh /path/to/my-plugin

# Validate individual components
./validate-skill.sh /path/to/skill-directory
./validate-command.sh /path/to/command.md
./validate-hook.sh /path/to/hook-script.sh
./validate-output-style.sh /path/to/style.md
```

## Scripts

### validate-skill.sh

Validates a skill directory containing a SKILL.md file.

**Usage:**
```bash
./validate-skill.sh <skill-path>
```

**Checks:**
- SKILL.md exists in the directory
- YAML frontmatter present and properly formatted
- Required fields: `name`, `description`
- Line count under 500 (recommended limit)
- @path imports resolve to existing files
- No personal identifiers (/Users/, /home/, etc.)

**Example:**
```bash
./validate-skill.sh ~/.claude/skills/my-skill
```

---

### validate-command.sh

Validates a command markdown file.

**Usage:**
```bash
./validate-command.sh <command-path>
```

**Checks:**
- File exists with .md extension
- YAML frontmatter present
- Required fields: `name`, `description`
- Arguments section present if $ARGUMENTS is used
- No personal identifiers

**Example:**
```bash
./validate-command.sh ~/.claude/commands/my-command.md
```

---

### validate-hook.sh

Validates a hook script file.

**Usage:**
```bash
./validate-hook.sh <hook-path>
```

**Checks:**
- File exists and has shebang (#!/bin/bash, etc.)
- File is executable
- Uses safe practices (set -e, quoted variables)
- No eval with user input patterns
- No hardcoded personal paths
- Warns about potential security issues

**Example:**
```bash
./validate-hook.sh ~/.claude/scripts/pre_tool_use.sh
```

---

### validate-output-style.sh

Validates an output style definition file.

**Usage:**
```bash
./validate-output-style.sh <style-path>
```

**Checks:**
- File exists with .md extension
- Has clear heading structure
- Contains style-related sections (format, template, example, etc.)
- Includes examples (code blocks or example sections)
- Contains actionable directives (must, should, always, etc.)
- No personal identifiers

**Example:**
```bash
./validate-output-style.sh ./output-styles/technical-spec.md
```

---

### validate-plugin.sh

Comprehensive validation of an entire plugin structure.

**Usage:**
```bash
./validate-plugin.sh <plugin-root>
```

**Checks:**
- plugin.json exists and is valid JSON
- Required manifest fields: `name`, `version`, `description`
- Version follows semver format (x.y.z)
- README.md exists with adequate content
- All referenced skill paths exist and pass validation
- All referenced command paths exist and pass validation
- All referenced hook paths exist and pass validation
- All referenced output style paths exist and pass validation
- No personal identifiers anywhere in the plugin

**Example:**
```bash
./validate-plugin.sh ./my-plugin
```

## Exit Codes

All scripts follow the same convention:

| Code | Meaning |
|------|---------|
| 0 | Validation passed |
| 1 | Validation failed (errors found) |

Scripts will exit immediately on critical errors but collect all validation issues before reporting.

## Output Format

Scripts use colored output for readability:

- **[PASS]** (green) - Check passed
- **[ERROR]** (red) - Check failed, will cause non-zero exit
- **[WARN]** (yellow) - Warning, non-blocking but should be reviewed
- **[INFO]** - Informational message

## Integration Examples

### CI/CD Pipeline

```bash
#!/bin/bash
set -e

# Validate all plugins before deployment
for plugin in ./plugins/*/; do
    echo "Validating $plugin..."
    ./evals/validate-plugin.sh "$plugin"
done

echo "All plugins validated successfully"
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

EVALS_DIR="$(git rev-parse --show-toplevel)/evals"

# Check modified skills
for skill in $(git diff --cached --name-only | grep "skills/.*/SKILL.md"); do
    skill_dir=$(dirname "$skill")
    "$EVALS_DIR/validate-skill.sh" "$skill_dir" || exit 1
done

# Check modified commands
for cmd in $(git diff --cached --name-only | grep "commands/.*\.md"); do
    "$EVALS_DIR/validate-command.sh" "$cmd" || exit 1
done
```

### Batch Validation

```bash
#!/bin/bash
# Validate all components in a directory

FAILED=0

for skill in ./skills/*/; do
    if ! ./validate-skill.sh "$skill"; then
        ((FAILED++))
    fi
done

for cmd in ./commands/*.md; do
    if ! ./validate-command.sh "$cmd"; then
        ((FAILED++))
    fi
done

echo "Validation complete. $FAILED failures."
exit $FAILED
```

## Requirements

- **bash** 4.0+ (for associative arrays)
- **jq** (optional, for JSON validation in validate-plugin.sh)
- Standard Unix utilities: grep, sed, awk, wc

## Customization

Each script defines arrays of patterns to check. To customize:

1. **Add personal identifier patterns:**
   ```bash
   PERSONAL_PATTERNS=(
       '/Users/[a-zA-Z]+'
       '/home/[a-zA-Z]+'
       'C:\\Users\\'
       '/your/custom/pattern'  # Add custom patterns
   )
   ```

2. **Adjust line limits:**
   ```bash
   # In validate-skill.sh
   if [[ $LINE_COUNT -gt 500 ]]; then  # Change 500 to your limit
   ```

3. **Add required frontmatter fields:**
   ```bash
   # Add checks for additional required fields
   if echo "$FRONTMATTER" | grep -q "^my_field:"; then
       log_success "Required field 'my_field' present"
   else
       log_error "Required field 'my_field' missing"
   fi
   ```

## Troubleshooting

### "jq: command not found"

Install jq for full JSON validation:
```bash
# macOS
brew install jq

# Ubuntu/Debian
apt-get install jq

# Without jq, validate-plugin.sh will skip JSON structure validation
```

### Scripts not executable

```bash
chmod +x *.sh
```

### False positives for personal identifiers

If legitimate paths are flagged (e.g., in documentation examples), either:
1. Use generic placeholders like `/path/to/user/` instead
2. Modify the pattern to exclude specific contexts
