# Plugin Management Commands

## Install Plugin

### Basic Installation
```bash
/plugin install <plugin-name>
```

### Install from Specific Marketplace
```bash
/plugin install <plugin-name>@<marketplace>
```

### Examples
```bash
# Install from default marketplace
/plugin install react-toolkit

# Install from GitHub
/plugin install author/plugin-name@github

# Install from company marketplace
/plugin install team-plugin@company
```

## Uninstall Plugin

### Remove Specific Plugin
```bash
/plugin uninstall <plugin-name>
```

### Remove All Versions
```bash
/plugin uninstall <plugin-name> --all
```

## List Plugins

### List Installed Plugins
```bash
/plugin list
```

### List Plugins from Specific Marketplace
```bash
/plugin list @github
/plugin list @company
```

## Update Plugins

### Update Specific Plugin
```bash
/plugin update <plugin-name>
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

#### Examples
```bash
# Add GitHub marketplace
/plugin marketplace add github https://github.com/marketplace.json

# Add local marketplace
/plugin marketplace add local ~/.claude/marketplaces/local.json
```

### Remove Marketplace
```bash
/plugin marketplace remove <name>
```

### List Marketplaces
```bash
/plugin marketplace list
```

## Plugin Validation

### Validate Plugin Structure
```bash
claude plugin validate /path/to/plugin
```

### Validation Checks
- Verifies plugin.json
- Checks SKILL.md files
- Validates hook scripts
- Ensures directory structure
- Checks dependencies

## Advanced Commands

### Dry Run Installation
```bash
/plugin install <plugin-name> --dry-run
```

### Show Plugin Details
```bash
/plugin show <plugin-name>
```

### Search Plugins
```bash
/plugin search <keyword>
```

## Best Practices

1. Always use specific marketplace
2. Validate plugins before installation
3. Keep plugins updated
4. Check compatibility
5. Review plugin permissions
6. Use dry run for testing

## Troubleshooting

- Use `--verbose` flag for detailed output
- Check logs for installation issues
- Verify network connectivity
- Ensure Claude Code is up-to-date