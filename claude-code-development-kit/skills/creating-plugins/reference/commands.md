# Plugin Management Commands

## Installation

### Install Plugin

```bash
/plugin install <plugin-name>@<marketplace>
```

**Examples**:
```bash
/plugin install my-plugin@local
/plugin install react-toolkit@company
/plugin install testing-suite@github
```

### Install from Specific Version

```bash
/plugin install my-plugin@marketplace@1.2.0
```

## Uninstallation

### Uninstall Plugin

```bash
/plugin uninstall <plugin-name>
```

**Example**:
```bash
/plugin uninstall my-plugin
```

## Listing

### List Installed Plugins

```bash
/plugin list
```

Shows:
- Plugin name
- Version
- Marketplace source
- Status (enabled/disabled)

### Browse Available Plugins

```bash
/plugin
```

Opens interactive browser showing:
- Available plugins from all marketplaces
- Plugin descriptions
- Installation status
- Versions

## Updates

### Update Specific Plugin

```bash
/plugin update <plugin-name>
```

**Example**:
```bash
/plugin update my-plugin
```

### Update All Plugins

```bash
/plugin update --all
```

## Marketplace Management

### Add Marketplace

```bash
/plugin marketplace add <name> <url-or-path>
```

**Examples**:
```bash
# Add local marketplace
/plugin marketplace add local ~/.claude/marketplaces/local.json

# Add remote marketplace
/plugin marketplace add company https://plugins.company.com/marketplace.json

# Add GitHub marketplace
/plugin marketplace add github https://github.com/user/plugin
```

### Remove Marketplace

```bash
/plugin marketplace remove <name>
```

**Example**:
```bash
/plugin marketplace remove local
```

### List Marketplaces

```bash
/plugin marketplace list
```

Shows:
- Marketplace name
- URL or path
- Number of available plugins

## Validation

### Validate Plugin Structure

```bash
claude plugin validate /path/to/plugin
```

Checks:
- plugin.json syntax and required fields
- Skills YAML frontmatter
- Hooks configuration
- File structure
- Missing dependencies

## Information

### Show Plugin Details

```bash
/plugin info <plugin-name>
```

Shows:
- Full description
- Version
- Author
- Homepage
- Commands provided
- Skills provided
- Hooks
- Dependencies

### Show Plugin Path

```bash
/plugin path <plugin-name>
```

Returns installation directory for the plugin.

## Quick Reference Table

| Command | Purpose | Example |
|---------|---------|---------|
| `/plugin install` | Install a plugin | `/plugin install my-plugin@local` |
| `/plugin uninstall` | Remove a plugin | `/plugin uninstall my-plugin` |
| `/plugin list` | Show installed plugins | `/plugin list` |
| `/plugin` | Browse available plugins | `/plugin` |
| `/plugin update` | Update plugin | `/plugin update my-plugin` |
| `/plugin marketplace add` | Add marketplace | `/plugin marketplace add local <path>` |
| `/plugin marketplace remove` | Remove marketplace | `/plugin marketplace remove local` |
| `/plugin marketplace list` | Show marketplaces | `/plugin marketplace list` |
| `/plugin info` | Show plugin details | `/plugin info my-plugin` |
| `/plugin path` | Show installation path | `/plugin path my-plugin` |
| `claude plugin validate` | Validate plugin | `claude plugin validate /path` |

## Common Workflows

### Install Plugin from GitHub

```bash
/plugin marketplace add github https://github.com/user/my-plugin
/plugin install my-plugin@github
```

### Test Local Plugin

```bash
# Create local marketplace
/plugin marketplace add local ~/.claude/marketplaces/local.json

# Install for testing
/plugin install my-plugin@local

# Make changes, then reload
/plugin uninstall my-plugin
/plugin install my-plugin@local
```

### Update Plugin After Changes

```bash
/plugin update my-plugin
```

### Remove Unused Plugin

```bash
/plugin uninstall my-plugin
```

### Check Plugin Status

```bash
/plugin list
/plugin info my-plugin
```

## Error Handling

Common command errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| "Plugin not found" | Plugin name misspelled | Check spelling and marketplace |
| "Marketplace not found" | Marketplace not added | Add marketplace first |
| "Version not found" | Version doesn't exist | Check available versions |
| "Dependency conflict" | Version incompatibility | Update dependencies |
| "Already installed" | Plugin already exists | Uninstall first or use update |
