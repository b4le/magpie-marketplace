# Plugin Environment Variables Guide

## Special Environment Variables for Plugins

Claude Code provides special environment variables to help plugins access critical system and project contexts.

### ${CLAUDE_PLUGIN_ROOT}

**Purpose**: Points to the plugin's installation directory.

**Use Cases**:
- Reference plugin-specific files
- Load library or configuration files
- Find utility scripts

**Example**:
```bash
# Source plugin helper script
source "${CLAUDE_PLUGIN_ROOT}/lib/helpers.sh"

# Read plugin configuration
cat "${CLAUDE_PLUGIN_ROOT}/config/defaults.json"
```

**Hook Configuration Example**:
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/pre-submit.sh"
          }
        ]
      }
    ]
  }
}
```

### ${CLAUDE_PROJECT_DIR}

**Purpose**: Current working directory where Claude Code was invoked.

**Use Cases**:
- Access project-specific files
- Read project configuration
- Perform context-aware operations

**Example**:
```bash
# Read project package.json
cat "${CLAUDE_PROJECT_DIR}/package.json"

# Change to project source directory
cd "${CLAUDE_PROJECT_DIR}/src"

# Check for project-specific configuration
if [ -f "${CLAUDE_PROJECT_DIR}/.claude/CLAUDE.md" ]; then
  echo "Project has memory file"
fi
```

### ${CLAUDE_CONFIG_DIR}

**Purpose**: Claude Code's configuration directory (`~/.claude`)

**Use Cases**:
- Access global Claude Code settings
- Read/write user-level configurations
- Manage skill and plugin settings

**Example**:
```bash
# View Claude Code settings
cat "${CLAUDE_CONFIG_DIR}/settings.json"

# List installed skills
ls "${CLAUDE_CONFIG_DIR}/skills"

# Check marketplace configurations
cat "${CLAUDE_CONFIG_DIR}/marketplaces/default.json"
```

## Comprehensive Environment Variable Example

```bash
#!/bin/bash
# Demonstrating all environment variables

echo "Plugin Root: ${CLAUDE_PLUGIN_ROOT}"
echo "Project Directory: ${CLAUDE_PROJECT_DIR}"
echo "Configuration Directory: ${CLAUDE_CONFIG_DIR}"

# Load plugin utilities
source "${CLAUDE_PLUGIN_ROOT}/utils.sh"

# Perform project-specific checks
if [ -d "${CLAUDE_PROJECT_DIR}/.git" ]; then
  echo "Working in a Git repository"
fi

# Access global configurations
if [ -f "${CLAUDE_CONFIG_DIR}/global-settings.json" ]; then
  echo "Global settings found"
fi
```

## Plugin Configuration Integration

Allow users to configure plugins using environment variables:

```json
{
  "name": "configurable-plugin",
  "config": {
    "apiEndpoint": "${API_ENDPOINT}",
    "timeout": 5000,
    "retries": 3
  }
}
```

Users set environment variables:
```bash
export API_ENDPOINT="https://api.example.com"
```

## Best Practices

1. **Always use absolute paths**
2. **Validate file/directory existence**
3. **Handle missing environment variables**
4. **Use default fallback values**
5. **Keep sensitive data out of configurations**

## Security Considerations

- Do not expose sensitive credentials
- Use secure environment variable management
- Avoid hardcoding secrets
- Use environment-specific configurations

## Troubleshooting

- Verify environment variable values using `echo`
- Check variable scope and inheritance
- Use `set -u` to catch undefined variables
- Log environment context for debugging

## Resources

- Bash scripting best practices
- Environment variable management
- Claude Code plugin development guide