# Claude Code Schemas

JSON Schema definitions for validating Claude Code marketplace and plugin structures.

## Available Schemas

| Schema | Purpose | Validates |
|--------|---------|-----------|
| `marketplace.schema.json` | Marketplace definition | `.claude-plugin/marketplace.json` |
| `plugin.schema.json` | Plugin manifest | `.claude-plugin/plugin.json` (or `plugin.json`) |
| `skill-frontmatter.schema.json` | Skill metadata | YAML frontmatter in `SKILL.md` files |

## Schema Conventions

All schemas follow these conventions:

- **JSON Schema draft-07** for broad tooling compatibility
- **Kebab-case identifiers**: `^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$`
- **Semantic versions**: `^\d+\.\d+\.\d+(?:-[a-zA-Z0-9.]+)?$`
- **Relative paths**: Must start with `./`
- **Reusable definitions**: Common types in `definitions` section

## Validation Examples

### Using jq (JSON files)

```bash
# Validate marketplace.json
jq --argjson schema "$(cat marketplace.schema.json)" \
   'if . then "Valid" else "Invalid" end' \
   .claude-plugin/marketplace.json

# Quick structure check for plugin.json
jq 'has("name") and has("version") and has("description")' \
   .claude-plugin/plugin.json
```

### Using ajv-cli (Recommended)

```bash
# Install ajv-cli
npm install -g ajv-cli

# Validate marketplace
ajv validate -s marketplace.schema.json -d .claude-plugin/marketplace.json

# Validate plugin manifest
ajv validate -s plugin.schema.json -d .claude-plugin/plugin.json

# Validate with verbose output
ajv validate -s plugin.schema.json -d .claude-plugin/plugin.json --verbose
```

### Using Python (jsonschema)

```python
import json
from jsonschema import validate, ValidationError

# Load schema
with open('schemas/plugin.schema.json') as f:
    schema = json.load(f)

# Load document to validate
with open('.claude-plugin/plugin.json') as f:
    document = json.load(f)

# Validate
try:
    validate(instance=document, schema=schema)
    print("Valid!")
except ValidationError as e:
    print(f"Invalid: {e.message}")
```

### Validating SKILL.md Frontmatter

SKILL.md files use YAML frontmatter that needs to be extracted before validation:

```bash
# Extract frontmatter from SKILL.md and validate
extract_frontmatter() {
    sed -n '/^---$/,/^---$/p' "$1" | sed '1d;$d'
}

# Using yq to convert YAML to JSON, then validate
extract_frontmatter skills/my-skill/SKILL.md | \
    yq -o=json | \
    ajv validate -s skill-frontmatter.schema.json -d -
```

```python
# Python: Extract and validate SKILL.md frontmatter
import yaml
import json
from jsonschema import validate

def extract_frontmatter(filepath):
    with open(filepath) as f:
        content = f.read()

    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            return yaml.safe_load(parts[1])
    return None

# Load schema
with open('schemas/skill-frontmatter.schema.json') as f:
    schema = json.load(f)

# Extract and validate
frontmatter = extract_frontmatter('skills/authoring-skills/SKILL.md')
validate(instance=frontmatter, schema=schema)
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Validate Plugin Structure

on:
  push:
    paths:
      - '.claude-plugin/**'
      - 'skills/**/SKILL.md'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install ajv-cli
        run: npm install -g ajv-cli

      - name: Validate marketplace.json
        if: hashFiles('.claude-plugin/marketplace.json') != ''
        run: |
          ajv validate \
            -s claude-code-development-kit/schemas/marketplace.schema.json \
            -d .claude-plugin/marketplace.json

      - name: Validate plugin.json files
        run: |
          find . -name 'plugin.json' -path '*/.claude-plugin/*' | while read file; do
            echo "Validating $file"
            ajv validate \
              -s claude-code-development-kit/schemas/plugin.schema.json \
              -d "$file"
          done
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

SCHEMA_DIR="claude-code-development-kit/schemas"

# Validate plugin.json if changed
if git diff --cached --name-only | grep -q 'plugin.json'; then
    for file in $(git diff --cached --name-only | grep 'plugin.json'); do
        if [[ -f "$file" ]]; then
            echo "Validating $file..."
            ajv validate -s "$SCHEMA_DIR/plugin.schema.json" -d "$file"
            if [[ $? -ne 0 ]]; then
                echo "Validation failed for $file"
                exit 1
            fi
        fi
    done
fi

# Validate marketplace.json if changed
if git diff --cached --name-only | grep -q 'marketplace.json'; then
    file=".claude-plugin/marketplace.json"
    if [[ -f "$file" ]]; then
        echo "Validating $file..."
        ajv validate -s "$SCHEMA_DIR/marketplace.schema.json" -d "$file"
        if [[ $? -ne 0 ]]; then
            echo "Validation failed for $file"
            exit 1
        fi
    fi
fi

echo "All validations passed!"
```

## Validation Strictness Levels

The schemas are designed for **STANDARD** mode validation:

| Mode | Description | Use Case |
|------|-------------|----------|
| **STRICT** | All fields validated, patterns enforced | Marketplace registry, CI/CD |
| **STANDARD** | Required fields + patterns | Development, PR checks |
| **LENIENT** | Required fields only | Quick checks, migration |

To achieve LENIENT validation, remove pattern constraints:

```bash
# Create lenient schema by removing patterns
jq 'del(.. | .pattern?)' plugin.schema.json > plugin.schema.lenient.json
```

## Schema Details

### marketplace.schema.json

Validates marketplace registry files with:
- Required: `name`, `description`, `plugins` array
- Optional: `owner` object with `name`, `email`, `url`
- Plugin references with source paths and metadata

### plugin.schema.json

Validates plugin manifests with:
- Required: `name`, `version`, `description`
- Optional: `author`, `license`, `homepage`, `repository`, `keywords`, `engines`
- Components: `skills`, `commands`, `agents`, `hooks`, `outputStyles`
- Dependencies: `mcpDependencies`

Hook events supported:
- `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`
- `Notification`, `Stop`, `SubagentStart`, `SubagentStop`
- `SessionStart`, `SessionEnd`, `UserPromptSubmit`
- `PreCompact`, `PostCompact`, `TeammateIdle`, `TaskCompleted`
- `ConfigChange`, `WorktreeCreate`, `WorktreeRemove`
- Tool-specific variants: `PreToolUse/Write`, `PostToolUse/Bash`, etc.

### skill-frontmatter.schema.json

Validates SKILL.md YAML frontmatter with:
- Required: `name`, `description`
- Optional: `allowed-tools`, `version`, `created`, `last_updated`, `auto-invoke`, `categories`, `author`, `tags`, `dependencies`

## Extending Schemas

To add custom fields while maintaining compatibility:

```json
{
  "$ref": "plugin.schema.json",
  "properties": {
    "x-custom-field": {
      "type": "string",
      "description": "Custom extension field"
    }
  }
}
```

## Troubleshooting

### Common Validation Errors

**"name" does not match pattern**
- Ensure kebab-case: `my-plugin` not `myPlugin` or `My Plugin`

**"version" does not match pattern**
- Use semantic versioning: `1.0.0` not `1.0` or `v1.0.0`

**"path" does not match pattern**
- Paths must start with `./`: `./skills/my-skill` not `skills/my-skill`

**Additional properties not allowed**
- Check for typos in field names
- Verify field is defined in schema

### Debugging

```bash
# Get detailed error output
ajv validate -s schema.json -d document.json --errors=json 2>&1 | jq

# Check schema itself is valid
ajv compile -s schema.json
```

## Contributing

When updating schemas:

1. Maintain backward compatibility when possible
2. Add new fields as optional
3. Update examples in the schema
4. Update this README with new validation examples
5. Test with existing marketplace/plugin files
