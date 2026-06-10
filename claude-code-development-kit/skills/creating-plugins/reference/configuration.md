# Plugin Configuration Guide

## Settings File Location

`.claude/settings.json` (user-level configuration)

## Enabling/Disabling Plugins

### Enable Specific Plugins

`enabledPlugins` is an **object** where keys are `"plugin-name@marketplace-name"` and values are booleans:

```json
{
  "enabledPlugins": {
    "my-plugin@my-marketplace": true,
    "another-plugin@my-marketplace": true
  }
}
```

**Only plugins with `true` in `enabledPlugins` will be loaded.**

### Disable Plugin Temporarily

Set the value to `false` without removing the entry:

```json
{
  "enabledPlugins": {
    "my-plugin@my-marketplace": true,
    "another-plugin@my-marketplace": false
  }
}
```

### Default Behavior

If `enabledPlugins` is not specified, **all installed plugins are enabled**.

## Marketplace Configuration

### extraKnownMarketplaces

Configure additional marketplaces for your project in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "company-tools": {
      "source": {
        "source": "github",
        "repo": "your-org/claude-plugins"
      }
    }
  }
}
```

The key is the marketplace name, and the value is an object with a `source` field (same format as plugin sources).

**Source options:**

GitHub:
```json
{
  "extraKnownMarketplaces": {
    "company-tools": {
      "source": {
        "source": "github",
        "repo": "your-org/claude-plugins",
        "ref": "main"
      }
    }
  }
}
```

Git URL:
```json
{
  "extraKnownMarketplaces": {
    "internal-tools": {
      "source": {
        "source": "url",
        "url": "https://git.company.com/plugins.git"
      }
    }
  }
}
```

### Combined Example

```json
{
  "extraKnownMarketplaces": {
    "company-tools": {
      "source": {
        "source": "github",
        "repo": "your-org/claude-plugins"
      }
    }
  },
  "enabledPlugins": {
    "code-formatter@company-tools": true,
    "deployment-tools@company-tools": true
  }
}
```

## Plugin-Specific Configuration

### Environment Variables

Pass runtime configuration to plugin scripts via environment variables. Define them in the environment before running Claude Code, or set them in your shell profile:

```bash
export API_ENDPOINT="https://api.example.com"
```

### Accessing Configuration

Environment variables are available in plugin hook scripts:

```bash
#!/bin/bash
# Access user-configured endpoint
echo "Using endpoint: $API_ENDPOINT"
```

## Plugin Environment Variables

### CLAUDE_PLUGIN_ROOT

Points to plugin's installation directory:

```bash
# In a hook script
source "${CLAUDE_PLUGIN_ROOT}/lib/helpers.sh"
cat "${CLAUDE_PLUGIN_ROOT}/config/defaults.json"
```

**Example hook**:
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/pre-submit.sh"
          }
        ]
      }
    ]
  }
}
```

### CLAUDE_PROJECT_DIR

Points to current working directory:

```bash
# Access project files
cat "${CLAUDE_PROJECT_DIR}/package.json"
cd "${CLAUDE_PROJECT_DIR}/src"
```

### CLAUDE_CONFIG_DIR

Points to Claude Code's configuration directory (`~/.claude`):

```bash
# Access Claude config
cat "${CLAUDE_CONFIG_DIR}/settings.json"
ls "${CLAUDE_CONFIG_DIR}/skills"
```

### Example Using All Variables

```bash
#!/bin/bash
# Hook script with environment variables

echo "Plugin root: ${CLAUDE_PLUGIN_ROOT}"
echo "Project dir: ${CLAUDE_PROJECT_DIR}"
echo "Config dir: ${CLAUDE_CONFIG_DIR}"

# Load plugin utilities
source "${CLAUDE_PLUGIN_ROOT}/utils.sh"

# Check project configuration
if [ -f "${CLAUDE_PROJECT_DIR}/.claude/CLAUDE.md" ]; then
  echo "Project has memory file"
fi
```

## Complete Settings Example

```json
{
  "extraKnownMarketplaces": {
    "company-tools": {
      "source": {
        "source": "github",
        "repo": "your-org/claude-plugins"
      }
    }
  },
  "enabledPlugins": {
    "react-toolkit@company-tools": true,
    "testing-suite@company-tools": true,
    "api-generator@company-tools": true
  }
}
```

## Configuration Best Practices

### 1. Document Configuration Requirements

In your plugin's README.md:

```markdown
## Configuration

This plugin requires the following environment variables:

- `API_ENDPOINT` - API base URL (required)
- `API_KEY` - Authentication key (optional)
- `TIMEOUT` - Request timeout in ms (default: 5000)

### Example

\`\`\`bash
export API_ENDPOINT="https://api.example.com"
export API_KEY="your-key-here"
\`\`\`
```

### 2. Provide Default Values

Use shell parameter expansion for defaults in hook scripts:

```bash
#!/bin/bash
API_ENDPOINT="${API_ENDPOINT:-https://api.example.com}"
TIMEOUT="${TIMEOUT:-5000}"
RETRIES="${RETRIES:-3}"
```

The `:-` syntax provides a fallback if the variable is not set.

### 3. Validate Configuration

Check required values in plugin scripts:

```bash
#!/bin/bash

if [ -z "$API_ENDPOINT" ]; then
  echo "Error: API_ENDPOINT not configured"
  exit 1
fi
```

### 4. Use Namespace Prefixes

Avoid conflicts with environment variable names:

```bash
# Good - namespaced
export MYPLUGIN_API_ENDPOINT="..."

# Bad - generic
export API_ENDPOINT="..."
```

## Project-Level Configuration

### Project-Specific Settings

`.claude/settings.json` in project directory:

```json
{
  "enabledPlugins": {
    "react-toolkit@company-tools": true,
    "testing-suite@company-tools": true
  }
}
```

Overrides user-level settings for this project.

### Priority Order

1. Project-level `.claude/settings.json`
2. User-level `~/.claude/settings.json`
3. Plugin defaults

## Configuration Troubleshooting

### Plugin Not Loading

Check enabled plugins format (must be object, not array):
```bash
cat .claude/settings.json | jq .enabledPlugins
```

Expected format: `{ "plugin-name@marketplace": true }`

### Environment Variables Not Working

Verify variables are set:
```bash
env | grep MYPLUGIN
```

### Configuration Changes Not Applied

Restart Claude Code after changing:
- `.claude/settings.json`
- Environment variables
- Plugin configuration
