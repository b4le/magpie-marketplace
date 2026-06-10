# Plugin Marketplace Setup

This guide explains how to create and host team plugin marketplaces for distributing Claude Code plugins within your organization.

## Table of Contents

- [What is a Plugin Marketplace?](#what-is-a-plugin-marketplace)
- [Creating a Marketplace](#creating-a-marketplace)
- [Marketplace Configuration](#marketplace-configuration)
- [Hosting Options](#hosting-options)
- [Adding Plugins to Marketplace](#adding-plugins-to-marketplace)
- [User Installation](#user-installation)
- [Marketplace Management](#marketplace-management)

## What is a Plugin Marketplace?

A plugin marketplace is a centralized registry that:
- Lists available plugins for your team or organization
- Provides plugin metadata (version, description, tags)
- Enables discovery and installation
- Manages plugin updates
- Controls access and distribution

## Creating a Marketplace

### Basic Marketplace Structure

**File**: `.claude-plugin/marketplace.json`

```json
{
  "name": "company-tools",
  "owner": {
    "name": "DevTools Team",
    "email": "devtools@company.com"
  },
  "plugins": [
    {
      "name": "plugin-name",
      "source": "./plugins/plugin-name",
      "version": "1.0.0",
      "description": "Plugin description",
      "tags": ["category1", "category2"]
    }
  ]
}
```

### Complete Marketplace Example

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
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
      "description": "React development toolkit with components, testing, and docs generation",
      "author": {
        "name": "Frontend Team",
        "email": "frontend@company.com"
      },
      "tags": ["react", "frontend", "typescript"],
      "homepage": "https://docs.company.com/react-toolkit",
      "category": "development"
    },
    {
      "name": "api-toolkit",
      "source": "./plugins/api-toolkit",
      "version": "1.5.0",
      "description": "API development tools for REST and GraphQL",
      "author": {
        "name": "Backend Team"
      },
      "tags": ["api", "backend", "graphql"],
      "homepage": "https://docs.company.com/api-toolkit",
      "category": "development"
    },
    {
      "name": "testing-suite",
      "source": "./plugins/testing-suite",
      "version": "3.0.0",
      "description": "Comprehensive testing tools for unit, integration, and E2E tests",
      "author": {
        "name": "QA Team"
      },
      "tags": ["testing", "qa", "automation"],
      "homepage": "https://docs.company.com/testing-suite",
      "category": "testing"
    },
    {
      "name": "data-tools",
      "source": {
        "source": "github",
        "repo": "company/data-tools"
      },
      "description": "Data processing and analysis utilities",
      "tags": ["data", "analytics"],
      "category": "development"
    },
    {
      "name": "security-scanner",
      "source": {
        "source": "github",
        "repo": "company/security-scanner",
        "ref": "v2.0.0"
      },
      "description": "Security scanning and vulnerability detection",
      "tags": ["security", "scanning", "compliance"],
      "category": "security"
    }
  ]
}
```

## Marketplace Configuration

### Marketplace Metadata

| Field       | Required | Description                                              |
|-------------|----------|----------------------------------------------------------|
| `name`      | Yes      | Marketplace identifier (kebab-case). Users reference this as `plugin-name@name` |
| `owner`     | Yes      | Contact for marketplace issues (`name` required, `email` optional) |
| `plugins`   | Yes      | Array of plugin entries                                  |
| `metadata`  | No       | Optional object with `description`, `version`, `pluginRoot` |

### Plugin Entry Fields

| Field         | Required | Description                                         |
|---------------|----------|-----------------------------------------------------|
| `name`        | Yes      | Plugin identifier (kebab-case)                      |
| `source`      | Yes      | Where to fetch the plugin (string path or source object) |
| `description` | No       | What the plugin does                                |
| `version`     | No       | Current plugin version                              |
| `author`      | No       | Object with `name` (required) and `email` (optional) |
| `tags`        | No       | Categories/keywords for discovery                   |
| `category`    | No       | Plugin category (development, productivity, security, etc.) |
| `homepage`    | No       | Documentation URL                                   |
| `license`     | No       | SPDX license identifier (MIT, Apache-2.0, etc.)     |
| `strict`      | No       | Controls whether `plugin.json` is the authority for component definitions (default: `true`). Set to `false` for marketplace-defined plugins. |

### Plugin Sources

The `source` field supports multiple formats:

**Relative path** (co-located in same repo):
```json
{ "source": "./plugins/my-plugin" }
```

**GitHub repository**:
```json
{
  "source": {
    "source": "github",
    "repo": "owner/repo",
    "ref": "v2.0.0"
  }
}
```

**Git URL**:
```json
{
  "source": {
    "source": "url",
    "url": "https://gitlab.com/team/plugin.git"
  }
}
```

**npm package**:
```json
{
  "source": {
    "source": "npm",
    "package": "@acme/claude-plugin",
    "version": "2.1.0"
  }
}
```

## Hosting Options

### Option 1: GitHub (Recommended)

Host your marketplace in a GitHub repository:

```bash
# Create marketplace repository
mkdir company-plugin-marketplace
cd company-plugin-marketplace
git init

# Create the marketplace file
mkdir .claude-plugin
# Create .claude-plugin/marketplace.json with your plugin definitions

# Push to GitHub
gh repo create company-plugin-marketplace --public --source=. --remote=origin
git push -u origin main
```

**Users add**:
```bash
/plugin marketplace add your-org/company-plugin-marketplace
```

### Option 2: Other Git Services

Any git hosting service works (GitLab, Bitbucket, self-hosted):

```bash
/plugin marketplace add https://gitlab.com/company/plugins.git
```

### Option 3: Local File Share

For teams without external hosting:

```bash
# Copy to shared location
cp -r marketplace/ /mnt/shared/claude/marketplace/

# Users add with local path
/plugin marketplace add /mnt/shared/claude/marketplace/
```

## Adding Plugins to Marketplace

### Step 1: Plugin is Published

Ensure plugin is:
- In a Git repository (or in the same marketplace repo)
- Has complete `.claude-plugin/plugin.json`
- Has a README.md
- Tested and validated

### Step 2: Update Marketplace

Add entry to `.claude-plugin/marketplace.json` plugins array:

```json
{
  "plugins": [
    {
      "name": "new-plugin",
      "source": "./plugins/new-plugin",
      "version": "1.0.0",
      "description": "New plugin for X",
      "tags": ["category"]
    }
  ]
}
```

### Step 3: Validate JSON

```bash
# Validate marketplace structure
claude plugin validate .

# Or validate JSON syntax only
cat .claude-plugin/marketplace.json | jq empty
```

### Step 4: Deploy Updated Marketplace

```bash
# Commit and push
git add .claude-plugin/marketplace.json
git commit -m "Add new-plugin v1.0.0"
git push
```

### Step 5: Users Update and Install

```bash
# Update marketplace listing
/plugin marketplace update company-tools

# Install new plugin
/plugin install new-plugin@company-tools
```

## User Installation

### Adding Marketplace

Users add marketplace once:

```bash
# From GitHub
/plugin marketplace add your-org/marketplace-repo

# From git URL
/plugin marketplace add https://gitlab.com/company/plugins.git

# From local path
/plugin marketplace add ./path/to/marketplace
```

### Installing Plugins

```bash
# Install from specific marketplace
/plugin install react-toolkit@company-tools

# Install specific version (if marketplace supports version pinning)
/plugin install react-toolkit@company-tools
```

### Updating Plugins

```bash
# Update all plugins
/plugin marketplace update company-tools
```

### Listing Installed Plugins

```bash
/plugin list
```

## Marketplace Management

### Versioning Strategy

For relative-path plugins (co-located in the same repo), set the version in the marketplace entry:

```json
{
  "plugins": [
    {
      "name": "my-plugin",
      "source": "./plugins/my-plugin",
      "version": "2.0.0"
    }
  ]
}
```

For external source plugins, set the version in the plugin's own `plugin.json` and optionally pin a ref in the marketplace entry.

### Deprecation Strategy

Mark plugins as deprecated:

```json
{
  "plugins": [
    {
      "name": "old-plugin",
      "source": "./plugins/old-plugin",
      "version": "1.0.0",
      "description": "DEPRECATED: Use new-plugin instead."
    }
  ]
}
```

### Access Control

**Public Marketplace** (anyone can access):
- Host on public GitHub or GitLab repository
- No authentication required

**Private Marketplace** (team/org only):
- Host in private repository
- Users need repository access for manual install/update
- Set `GITHUB_TOKEN` or `GITLAB_TOKEN` for background auto-updates

## Example: Complete Marketplace Setup

### 1. Create Marketplace Repository

```bash
mkdir company-plugin-marketplace
cd company-plugin-marketplace
git init
mkdir -p .claude-plugin
mkdir -p plugins/react-toolkit/.claude-plugin
mkdir -p plugins/react-toolkit/skills/review
```

### 2. Create Plugin Manifest

```json
{
  "name": "react-toolkit",
  "description": "React development toolkit",
  "version": "1.0.0"
}
```
Save as `plugins/react-toolkit/.claude-plugin/plugin.json`.

### 3. Create marketplace.json

```json
{
  "name": "company-tools",
  "owner": {
    "name": "DevTools Team",
    "email": "devtools@company.com"
  },
  "plugins": [
    {
      "name": "react-toolkit",
      "source": "./plugins/react-toolkit",
      "version": "1.0.0",
      "description": "React development toolkit",
      "tags": ["react", "frontend"]
    }
  ]
}
```
Save as `.claude-plugin/marketplace.json`.

### 4. Validate and Push

```bash
claude plugin validate .
git add .
git commit -m "Initial marketplace setup"
git push origin main
```

### 5. Users Install

```bash
# Add marketplace
/plugin marketplace add your-org/company-plugin-marketplace

# Browse plugins
/plugin

# Install plugin
/plugin install react-toolkit@company-tools
```

## Next Steps

- Review [Adding Components](adding-components.md)
- Learn about [Publishing](publishing.md)
- Study [Best Practices](best-practices.md)
- Explore [Advanced Topics](advanced.md)
