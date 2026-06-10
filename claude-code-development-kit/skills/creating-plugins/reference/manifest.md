# Plugin Manifest (plugin.json)

## Location

`.claude-plugin/plugin.json`

## Minimum Required Fields

Only `name` is strictly required. `version` and `description` are strongly recommended.

```json
{
  "name": "my-plugin"
}
```

## Complete Example

```json
{
  "name": "react-toolkit",
  "version": "2.1.0",
  "description": "Comprehensive React development toolkit with components, testing, and docs generation",
  "author": {
    "name": "Development Team",
    "email": "dev@company.com",
    "url": "https://company.com"
  },
  "homepage": "https://github.com/company/react-toolkit",
  "repository": "https://github.com/company/react-toolkit",
  "license": "MIT",
  "keywords": ["react", "components", "testing", "typescript"]
}
```

## Field Reference

### Required Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `name` | string | Unique plugin identifier (lowercase, hyphens) | `"my-plugin"` |

### Strongly Recommended Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `version` | string | Semantic version (major.minor.patch) | `"1.0.0"` |
| `description` | string | What the plugin does | `"Testing toolkit"` |

### Optional Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `author` | object | Creator info — object with `name`, `email`, `url` | See below |
| `homepage` | string | Plugin website or documentation | `"https://github.com/user/plugin"` |
| `repository` | string | Source code URL | `"https://github.com/company/plugin"` |
| `license` | string | License type | `"MIT"`, `"Apache-2.0"` |
| `keywords` | array | Search/discovery terms | `["react", "testing"]` |
| `hooks` | object | Hook definitions | See hooks reference |

## Author Field

The `author` field must be an object with three optional properties: `name`, `email`, and `url`:

```json
{
  "author": {
    "name": "Development Team",
    "email": "dev@company.com",
    "url": "https://company.com"
  }
}
```

## Repository Field

The `repository` field accepts a URL string pointing to the plugin's source repository:

```json
{ "repository": "https://github.com/company/plugin" }
```

## Naming Conventions

### Plugin Name
- Use lowercase
- Separate words with hyphens
- Be descriptive
- Avoid generic names

Good: `react-toolkit`, `api-generator`, `testing-suite`
Bad: `plugin`, `tools`, `util`

### Keywords
- Use lowercase
- Single words or hyphenated phrases
- Technology names
- Use case descriptors

Example: `["react", "components", "testing", "typescript", "frontend"]`

## Validation

Required checks:
- Valid JSON syntax
- `name` field is present
- `version` follows semver if provided
- Name follows conventions (lowercase, hyphens)
- Valid repository URL (if provided)
