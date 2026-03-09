# Plugin Publishing Guide

This guide covers multiple strategies for publishing Claude Code plugins.

## Publishing via Git Repository

### 1. Prepare Repository

```bash
cd my-plugin
git init
git add .
git commit -m "Initial plugin release"
```

### 2. Create GitHub Repository

```bash
gh repo create my-plugin --public --source=. --remote=origin
git push -u origin main
```

### 3. Tag Version

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 4. Share Plugin URL

Users can install from GitHub:

```bash
/plugin marketplace add github https://github.com/username/my-plugin
/plugin install my-plugin@github
```

## Publishing via Plugin Marketplace

### 1. Prepare Plugin Package

```bash
cd my-plugin
# Ensure plugin.json is complete
# Ensure README.md exists
# Add LICENSE file
```

### 2. Create Marketplace Entry

Submit to a plugin marketplace (e.g., company internal marketplace):

```json
{
  "name": "company-marketplace",
  "plugins": {
    "my-plugin": {
      "repository": "https://github.com/company/my-plugin",
      "version": "1.0.0",
      "description": "My plugin description"
    }
  }
}
```

### 3. Users Install

```bash
/plugin marketplace add company https://marketplace.company.com
/plugin install my-plugin@company
```

## Publishing via npm (If Supported)

```bash
# Package plugin
npm pack

# Publish to npm
npm publish

# Users install
/plugin install my-plugin@npm
```

## Marketplace Setup

### Create Team Marketplace

**File**: `marketplace.json`

```json
{
  "name": "Company Marketplace",
  "description": "Official company plugins",
  "url": "https://plugins.company.com/marketplace.json",
  "plugins": {
    "react-toolkit": {
      "repository": "https://github.com/company/react-toolkit",
      "version": "2.1.0",
      "description": "React development toolkit",
      "tags": ["react", "frontend"]
    }
  }
}
```

### Add Marketplace

```bash
/plugin marketplace add company https://plugins.company.com/marketplace.json
```

### Browse and Install

```bash
/plugin  # Opens browser
# Select from company marketplace
# Install desired plugins
```

## Best Practices

- Validate plugin before publishing
- Include comprehensive README
- Use semantic versioning
- Provide clear documentation
- Test in multiple environments
- Keep dependencies minimal
- Include a LICENSE file
- Add tags for better discoverability