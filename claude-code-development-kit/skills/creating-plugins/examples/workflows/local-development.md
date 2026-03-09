# Local Plugin Development Workflow

## Prerequisites

- Claude Code installed
- Git
- Text editor or IDE
- Bash or compatible shell

## Step-by-Step Guide

### 1. Create Plugin Directory

```bash
# Create plugin root directory
mkdir -p ~/plugins/my-plugin/.claude-plugin
cd ~/plugins/my-plugin
```

### 2. Initialize Plugin Configuration

```bash
# Create plugin.json
cat > .claude-plugin/plugin.json << 'EOF'
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "My custom Claude Code plugin",
  "author": { "name": "Your Name", "email": "you@example.com" }
}
EOF
```

### 3. Create Plugin Components

```bash
# Create directories for plugin components
mkdir -p commands skills hooks mcp

# Example: Create a simple command
cat > commands/hello.md << 'EOF'
---
description: Greeting command
---

Hello from my plugin!
EOF
```

### 4. Create Local Marketplace

```bash
# Create local marketplace configuration
mkdir -p ~/.claude/marketplaces
cat > ~/.claude/marketplaces/local.json << 'EOF'
{
  "name": "local",
  "description": "Local plugin development marketplace",
  "plugins": {
    "my-plugin": {
      "path": "/Users/you/plugins/my-plugin",
      "version": "0.1.0"
    }
  }
}
EOF
```

### 5. Add Local Marketplace

```bash
# Add local marketplace to Claude Code
/plugin marketplace add local ~/.claude/marketplaces/local.json
```

### 6. Install Plugin

```bash
# Install plugin from local marketplace
/plugin install my-plugin@local
```

### 7. Test Plugin

```bash
# Test command
/my-plugin:hello

# Verify plugin is loaded
/plugin list
```

### 8. Iterative Development

```bash
# Make changes to plugin files
# Uninstall and reinstall to reload
/plugin uninstall my-plugin
/plugin install my-plugin@local
```

### Best Practices

- Use absolute paths in configurations
- Test each component individually
- Keep plugin.json updated
- Use semantic versioning

### Troubleshooting

- Check Claude Code logs for errors
- Verify file permissions
- Restart Claude Code if needed
- Validate JSON configurations