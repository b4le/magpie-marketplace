# Plugin Marketplace Setup Guide

## Creating a Team Marketplace

### Marketplace Configuration File

**File location**: `.claude-plugin/marketplace.json`

```json
{
  "$schema": "https://claude.ai/schemas/marketplace.schema.json",
  "name": "company-tools",
  "owner": {
    "name": "DevTools Team",
    "email": "devtools@company.com"
  },
  "plugins": [
    {
      "name": "react-toolkit",
      "source": "./plugins/react-toolkit",
      "version": "2.1.0",
      "description": "React development toolkit",
      "tags": ["react", "frontend"]
    },
    {
      "name": "api-toolkit",
      "source": "./plugins/api-toolkit",
      "version": "1.5.0",
      "description": "API development tools",
      "tags": ["api", "backend"]
    },
    {
      "name": "testing-suite",
      "source": "./plugins/testing-suite",
      "version": "3.0.0",
      "description": "Comprehensive testing tools",
      "tags": ["testing", "qa"]
    }
  ]
}
```

## Marketplace Configuration Fields

### Top-Level Fields

| Field       | Required | Description                              |
|-------------|----------|------------------------------------------|
| `name`      | Yes      | Marketplace identifier (kebab-case, no spaces). Users see this when installing: `/plugin install my-tool@name` |
| `owner`     | Yes      | Marketplace maintainer information       |
| `plugins`   | Yes      | Array of plugin entries                  |
| `metadata`  | No       | Optional description, version, pluginRoot |

### Owner Fields

| Field   | Required | Description                      |
|---------|----------|----------------------------------|
| `name`  | Yes      | Name of the maintainer or team   |
| `email` | No       | Contact email for the maintainer |

### Plugin Entry Fields

| Field         | Required | Description                                           |
|---------------|----------|-------------------------------------------------------|
| `name`        | Yes      | Plugin identifier (kebab-case)                        |
| `source`      | Yes      | Where to fetch the plugin (path string or source object) |
| `description` | No       | Plugin purpose                                        |
| `version`     | No       | Semantic version                                      |
| `author`      | No       | Plugin author object with `name` and optional `email` |
| `tags`        | No       | Discovery keywords                                    |
| `category`    | No       | Plugin category for organization                      |
| `homepage`    | No       | Documentation URL                                     |
| `strict`      | No       | Controls whether `plugin.json` is the authority for component definitions (default: `true`). When `false`, the marketplace entry is the entire definition. |

## Plugin Sources

The `source` field tells Claude Code where to find each plugin.

### Relative path (plugins in same repo)

```json
{ "name": "my-plugin", "source": "./plugins/my-plugin" }
```

### GitHub repository

```json
{
  "name": "my-plugin",
  "source": {
    "source": "github",
    "repo": "owner/plugin-repo",
    "ref": "v2.0.0"
  }
}
```

### Git URL

```json
{
  "name": "my-plugin",
  "source": {
    "source": "url",
    "url": "https://gitlab.com/team/plugin.git"
  }
}
```

### npm package

```json
{
  "name": "my-plugin",
  "source": {
    "source": "npm",
    "package": "@acme/claude-plugin",
    "version": "2.1.0"
  }
}
```

## Adding Marketplace

### Command

```bash
/plugin marketplace add <name-or-path-or-url>
```

### Examples

```bash
# Add from GitHub
/plugin marketplace add owner/repo

# Add local marketplace
/plugin marketplace add ./my-local-marketplace

# Add from git URL
/plugin marketplace add https://gitlab.com/company/plugins.git
```

## Browsing and Installing

### Open Marketplace Browser

```bash
/plugin  # Opens interactive browser
```

### Install Plugin

```bash
/plugin install <plugin-name>@<marketplace-name>
```

### Example

```bash
# Install react-toolkit from company marketplace
/plugin install react-toolkit@company-tools
```

## Hosting Marketplace

### Recommended: Host on GitHub

1. Create a repository for your marketplace
2. Create `.claude-plugin/marketplace.json` with your plugin definitions
3. Share with users: `/plugin marketplace add owner/repo`

### Other Git Services

Any git hosting service works (GitLab, Bitbucket, self-hosted):

```bash
/plugin marketplace add https://gitlab.com/company/plugins.git
```

### Security Considerations

- Use HTTPS or SSH
- For private repos, set `GITHUB_TOKEN` or `GITLAB_TOKEN` for background auto-updates
- Test with `claude plugin validate .` before sharing

## Marketplace Management

### List Marketplaces

```bash
/plugin marketplace list
```

### Remove Marketplace

```bash
/plugin marketplace remove <name>
```

### Update Marketplace

```bash
/plugin marketplace update <name>
```

## Best Practices

1. Use kebab-case for marketplace and plugin names
2. Include comprehensive descriptions
3. Add meaningful tags for discovery
4. Validate with `claude plugin validate .` before publishing
5. Use semantic versioning in plugin entries
6. Use `owner` (not `maintainer`) for contact information

## Example Workflow

1. Create `.claude-plugin/marketplace.json`
2. Add plugins in the `plugins` array
3. Push to GitHub or other git host
4. Users add with `/plugin marketplace add owner/repo`
5. Users install with `/plugin install plugin-name@marketplace-name`

## Troubleshooting

- Verify JSON syntax with `claude plugin validate .`
- Check network connectivity and repository access
- Ensure `.claude-plugin/marketplace.json` exists (not `marketplace.json` at root)
- Relative path sources only work with Git-based marketplaces (not URL-only)
