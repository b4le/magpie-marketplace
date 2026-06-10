# Local Plugin Development Workflow

This guide provides a comprehensive step-by-step process for developing Claude Code plugins locally.

## Steps to Create a Local Plugin

### 1. Create Plugin Directory

```bash
mkdir -p ~/plugins/my-plugin/.claude-plugin
cd ~/plugins/my-plugin
```

### 2. Create plugin.json Configuration

```bash
cat > .claude-plugin/plugin.json << 'EOF'
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "My custom plugin",
  "author": {"name": "Your Name", "email": "you@example.com"}
}
EOF
```

### 3. Add Plugin Components

```bash
mkdir -p commands skills hooks

# Create a sample command
cat > commands/test.md << 'EOF'
---
description: Test command
---

This is a test command from my plugin.
EOF
```

### 4. Create Local Marketplace

Create a marketplace configuration at `~/.claude/marketplaces/local.json`:

```json
{
  "name": "local",
  "description": "Local plugin development",
  "plugins": [
    {
      "name": "my-plugin",
      "source": "./my-plugin",
      "version": "0.1.0"
    }
  ]
}
```

### 5. Add Marketplace to Claude Code

```bash
/plugin marketplace add local ~/.claude/marketplaces/local.json
```

### 6. Install Your Plugin

```bash
/plugin install my-plugin@local
```

### 7. Test Plugin

Verify that commands, skills, and hooks work as expected:

```bash
# Test command
/my-plugin:test

# Additional verification steps:
# - Verify skills are discoverable
# - Check if hooks trigger correctly
```

### 8. Iterate and Refine

Make changes to your plugin files and reload:

```bash
# Reinstall to pick up changes
/plugin uninstall my-plugin
/plugin install my-plugin@local
```

## Best Practices

- Use clear, descriptive names for your plugin and its components
- Follow semantic versioning
- Include comprehensive documentation
- Test thoroughly before publishing
- Use namespacing to avoid command conflicts
- Review hook scripts carefully for security

## Troubleshooting

- Ensure `plugin.json` is valid JSON
- Check directory structure matches expected format
- Restart Claude Code if components don't load
- Verify file permissions for hooks (use `chmod +x`)