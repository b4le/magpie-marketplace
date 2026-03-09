# Advanced Plugin Topics

This guide covers advanced plugin development topics including dependencies, hooks, environment variables, configuration, and security.

## Table of Contents

- [Plugin Dependencies](#plugin-dependencies)
- [Advanced Hook Patterns](#advanced-hook-patterns)
- [Environment Variables](#environment-variables)
- [Plugin Configuration](#plugin-configuration)
- [Dynamic Plugin Content](#dynamic-plugin-content)
- [Security Considerations](#security-considerations)
- [Plugin Scoping](#plugin-scoping)
- [Enabling and Disabling Plugins](#enabling-and-disabling-plugins)

## Plugin Dependencies

Plugins can depend on other plugins to share functionality and avoid duplication.

### Declaring Dependencies

In `.claude-plugin/plugin.json`:

```json
{
  "name": "advanced-plugin",
  "version": "1.0.0",
  "dependencies": {
    "base-plugin": "^1.0.0",
    "helper-plugin": "^2.1.0",
    "utilities": ">=1.5.0"
  }
}
```

### Dependency Resolution

Claude Code will:
1. Check if dependencies are installed
2. Install missing dependencies automatically
3. Verify version compatibility
4. Resolve transitive dependencies

### Version Constraints

Use semantic versioning constraints:

```json
{
  "dependencies": {
    "plugin-a": "^1.0.0",    // Compatible with 1.x.x (>= 1.0.0, < 2.0.0)
    "plugin-b": "~1.2.0",    // Compatible with 1.2.x (>= 1.2.0, < 1.3.0)
    "plugin-c": ">=2.0.0",   // At least 2.0.0
    "plugin-d": "1.5.2",     // Exact version (avoid unless necessary)
    "plugin-e": "*"          // Any version (not recommended)
  }
}
```

### Dependency Best Practices

1. **Minimize dependencies**: Only depend on what you truly need
2. **Use version ranges**: Allow flexibility for updates
3. **Document dependencies**: Explain why each is needed
4. **Test with dependencies**: Ensure compatibility
5. **Avoid circular dependencies**: Plugin A depends on B which depends on A

### Example: Building on Base Plugin

**Base plugin** (`base-utilities`):
```
base-utilities/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── string-helpers/
│       └── SKILL.md
└── commands/
    └── format.md
```

**Advanced plugin** depends on base:
```json
{
  "name": "advanced-formatter",
  "version": "1.0.0",
  "dependencies": {
    "base-utilities": "^1.0.0"
  }
}
```

**Advanced plugin** can use base plugin's commands and skills:
```markdown
---
description: Advanced formatting using base utilities
---

Use the base-utilities:format command to format the text.
Then apply advanced transformations...
```

## Advanced Hook Patterns

Hooks enable plugins to respond to lifecycle events and extend Claude Code behavior.

### Hook Configuration File

**Location**: `hooks/hooks.json`

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/log-bash.js"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/analyze-edit.py",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

### Hook Configuration Options

Each event key maps to an array of matcher/hooks entry objects:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `matcher` | No | string | Tool name or glob pattern (e.g., `"Bash"`, `"Write\|Edit"`). Omit to match all. |
| `hooks` | Yes | array | Array of handler objects to execute |

Each handler object supports four types:

**`command`** — execute a shell command or script:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `type` | Yes | string | `"command"` |
| `command` | Yes | string | Shell command or script path (use `${CLAUDE_PLUGIN_ROOT}`) |
| `timeout` | No | number | Timeout in seconds (1–600). Default: 600 |
| `async` | No | boolean | Run asynchronously (default: false) |
| `statusMessage` | No | string | Message shown while hook runs |
| `once` | No | boolean | Run only once per session (default: false) |

**`http`** — call an HTTP endpoint:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `type` | Yes | string | `"http"` |
| `url` | Yes | string | URL to POST event data to |
| `headers` | No | object | HTTP headers to include |
| `allowedEnvVars` | No | string[] | Env var names to forward |
| `timeout` | No | number | Timeout in seconds (1–600). Default: 600 |

**`prompt`** — run a model prompt:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `type` | Yes | string | `"prompt"` |
| `prompt` | Yes | string | Prompt text to send to the model |
| `model` | No | string | Model to use (defaults to current) |
| `timeout` | No | number | Timeout in seconds (1–600). Default: 30 |

**`agent`** — run an agent task:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `type` | Yes | string | `"agent"` |
| `prompt` | Yes | string | Task prompt for the agent |
| `model` | No | string | Model to use |
| `tools` | No | string[] | Tools to make available |
| `timeout` | No | number | Timeout in seconds (1–600). Default: 60 |

### Hook Execution Flow

**Synchronous hooks** (async: false):
1. Event occurs (e.g., user submits prompt)
2. Hook script executes
3. Claude Code waits for completion
4. Hook exits with code 0 (success) or non-zero (failure)
5. If failure, operation may be blocked

**Asynchronous hooks** (async: true):
1. Event occurs
2. Hook script starts in background
3. Claude Code continues immediately
4. Hook completes independently

### Hook Script Examples

#### Pre-commit Validation

**File**: `scripts/pre-commit-validate.sh`

```bash
#!/bin/bash
# Pre-commit validation hook

# Receive event data from stdin
read -r event_data

# Load plugin utilities
source "${CLAUDE_PLUGIN_ROOT}/lib/utils.sh"

# Check for linting errors
echo "Running linter..."
cd "${CLAUDE_PROJECT_DIR}"
npm run lint --silent

if [ $? -ne 0 ]; then
  echo "❌ Linting failed. Please fix errors before committing."
  exit 1
fi

# Check for test failures
echo "Running tests..."
npm test --silent

if [ $? -ne 0 ]; then
  echo "❌ Tests failed. Please fix failing tests."
  exit 1
fi

echo "✅ All checks passed!"
exit 0
```

#### Bash Command Logger

**File**: `scripts/log-bash.js`

```javascript
#!/usr/bin/env node
// Log all bash commands for audit trail

const fs = require('fs');
const path = require('path');

// Read event data from stdin
let eventData = '';
process.stdin.on('data', chunk => {
  eventData += chunk;
});

process.stdin.on('end', () => {
  const event = JSON.parse(eventData);

  const logFile = path.join(
    process.env.CLAUDE_PROJECT_DIR,
    '.claude',
    'bash-commands.log'
  );

  const logEntry = {
    timestamp: new Date().toISOString(),
    command: event.command,
    cwd: event.cwd
  };

  fs.appendFileSync(
    logFile,
    JSON.stringify(logEntry) + '\n'
  );

  console.log('Command logged');
});
```

#### File Edit Analyzer

**File**: `scripts/analyze-edit.py`

```python
#!/usr/bin/env python3
# Analyze file edits for patterns

import sys
import json
from datetime import datetime

def analyze_edit(event):
    """Analyze file edit event"""

    file_path = event.get('file_path')
    old_content = event.get('old_content')
    new_content = event.get('new_content')

    # Analyze changes
    old_lines = old_content.count('\n') if old_content else 0
    new_lines = new_content.count('\n') if new_content else 0
    delta = new_lines - old_lines

    # Log analysis
    log_entry = {
        'timestamp': datetime.now().isoformat(),
        'file': file_path,
        'lines_added': delta if delta > 0 else 0,
        'lines_removed': abs(delta) if delta < 0 else 0
    }

    print(json.dumps(log_entry))
    return 0

if __name__ == '__main__':
    # Read event from stdin
    event_data = sys.stdin.read()
    event = json.parse(event_data) if event_data else {}

    sys.exit(analyze_edit(event))
```

### Hook Event Data

Hooks receive event data via stdin as JSON:

```json
{
  "event": "UserPromptSubmit",
  "timestamp": "2025-01-18T12:00:00Z",
  "data": {
    "prompt": "User's prompt text",
    "context": {}
  }
}
```

### Hook Best Practices

1. **Keep hooks fast**: Avoid long-running operations in synchronous hooks
2. **Use async for logging**: Don't block operations for logging
3. **Handle errors gracefully**: Provide clear error messages
4. **Test thoroughly**: Test hooks in various scenarios
5. **Use timeouts**: Prevent hung hooks from blocking
6. **Validate input**: Check event data is valid
7. **Log appropriately**: Don't spam logs

## Environment Variables

Plugins have access to special environment variables and can use custom ones.

### Built-in Environment Variables

#### ${CLAUDE_PLUGIN_ROOT}

Points to the plugin's installation directory:

```bash
#!/bin/bash
# Access plugin files

# Load plugin libraries
source "${CLAUDE_PLUGIN_ROOT}/lib/helpers.sh"

# Read plugin configuration
cat "${CLAUDE_PLUGIN_ROOT}/config/defaults.json"

# Execute plugin scripts
"${CLAUDE_PLUGIN_ROOT}/bin/process.sh"
```

#### ${CLAUDE_PROJECT_DIR}

Points to the current working directory where Claude Code was invoked:

```bash
#!/bin/bash
# Access project files

# Read project configuration
cat "${CLAUDE_PROJECT_DIR}/package.json"

# Change to project directory
cd "${CLAUDE_PROJECT_DIR}"

# Access project subdirectories
ls "${CLAUDE_PROJECT_DIR}/src"
```

#### ${CLAUDE_CONFIG_DIR}

Points to Claude Code's configuration directory (`~/.claude`):

```bash
#!/bin/bash
# Access Claude configuration

# Read Claude settings
cat "${CLAUDE_CONFIG_DIR}/settings.json"

# List installed skills
ls "${CLAUDE_CONFIG_DIR}/skills"

# Access user-level plugins
ls "${CLAUDE_CONFIG_DIR}/plugins"
```

### Using All Variables Together

**Example**: `scripts/setup-check.sh`

```bash
#!/bin/bash
# Comprehensive setup check using all environment variables

echo "=== Plugin Environment Check ==="
echo ""

echo "Plugin Root: ${CLAUDE_PLUGIN_ROOT}"
echo "Project Directory: ${CLAUDE_PROJECT_DIR}"
echo "Config Directory: ${CLAUDE_CONFIG_DIR}"
echo ""

# Load plugin utilities
if [ -f "${CLAUDE_PLUGIN_ROOT}/lib/utils.sh" ]; then
  source "${CLAUDE_PLUGIN_ROOT}/lib/utils.sh"
  echo "✅ Plugin utilities loaded"
else
  echo "❌ Plugin utilities not found"
  exit 1
fi

# Check project configuration
if [ -f "${CLAUDE_PROJECT_DIR}/.claude/CLAUDE.md" ]; then
  echo "✅ Project has memory file"
else
  echo "⚠️  Project does not have memory file"
fi

# Check Claude Code settings
if [ -f "${CLAUDE_CONFIG_DIR}/settings.json" ]; then
  echo "✅ Claude settings found"
else
  echo "❌ Claude settings not found"
  exit 1
fi

echo ""
echo "=== Environment check complete ==="
exit 0
```

### Custom Environment Variables

Allow users to configure plugins with environment variables:

**In plugin.json**:
```json
{
  "name": "configurable-plugin",
  "version": "1.0.0",
  "config": {
    "apiEndpoint": "${API_ENDPOINT}",
    "apiToken": "${API_TOKEN}",
    "timeout": "${REQUEST_TIMEOUT:-5000}",
    "retries": "${MAX_RETRIES:-3}"
  }
}
```

**Syntax**:
- `${VAR}` - Required variable
- `${VAR:-default}` - Optional with default value

**Users set variables**:
```bash
export API_ENDPOINT="https://api.example.com"
export API_TOKEN="secret-token"
export REQUEST_TIMEOUT="10000"
export MAX_RETRIES="5"
```

### Environment Variable Best Practices

1. **Document all variables**: List in README with descriptions
2. **Provide defaults**: Use `${VAR:-default}` syntax
3. **Validate values**: Check variables in hook scripts
4. **Never hardcode secrets**: Always use environment variables
5. **Use descriptive names**: `API_TOKEN` not `TOKEN`

### Example: API Integration Plugin

**README.md**:
```markdown
## Configuration

### Required Environment Variables

- `JIRA_API_URL` - JIRA instance URL (e.g., https://company.atlassian.net)
- `JIRA_API_TOKEN` - JIRA API token for authentication

### Optional Environment Variables

- `JIRA_TIMEOUT` - Request timeout in milliseconds (default: 5000)
- `JIRA_MAX_RETRIES` - Maximum retry attempts (default: 3)
- `JIRA_DEFAULT_PROJECT` - Default project key (default: none)

### Setup

\`\`\`bash
export JIRA_API_URL="https://company.atlassian.net"
export JIRA_API_TOKEN="your-token-here"
export JIRA_TIMEOUT="10000"
export JIRA_MAX_RETRIES="5"
export JIRA_DEFAULT_PROJECT="PROJ"
\`\`\`
```

**.mcp.json**:
```json
{
  "servers": {
    "jira": {
      "transport": "http",
      "url": "${JIRA_API_URL}/rest/api/3/mcp",
      "headers": {
        "Authorization": "Bearer ${JIRA_API_TOKEN}"
      },
      "timeout": "${JIRA_TIMEOUT:-5000}",
      "description": "JIRA integration"
    }
  }
}
```

## Plugin Configuration

Allow users to configure plugin behavior.

### Configuration in plugin.json

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "config": {
    "feature1": {
      "enabled": true,
      "setting": "value"
    },
    "feature2": {
      "enabled": false
    },
    "apiEndpoint": "${API_ENDPOINT}",
    "timeout": 5000,
    "retries": 3
  }
}
```

### User Configuration Override

Users can override in `.claude/settings.json`:

```json
{
  "plugins": {
    "my-plugin": {
      "config": {
        "feature1": {
          "enabled": false
        },
        "timeout": 10000
      }
    }
  }
}
```

### Accessing Configuration in Scripts

**Example**: `scripts/get-config.sh`

```bash
#!/bin/bash
# Read plugin configuration

CONFIG_FILE="${CLAUDE_CONFIG_DIR}/settings.json"

if [ -f "$CONFIG_FILE" ]; then
  # Extract plugin config using jq
  TIMEOUT=$(jq -r '.plugins["my-plugin"].config.timeout // 5000' "$CONFIG_FILE")
  echo "Timeout: $TIMEOUT"
fi
```

## Dynamic Plugin Content

Generate plugin content dynamically based on context.

### Dynamic Commands

**Example**: `commands/select-option.md`

```markdown
---
description: Select from dynamic options
---

Available options:

\`\`\`bash
${CLAUDE_PLUGIN_ROOT}/scripts/generate-options.sh
\`\`\`

Select option: $1
```

**Script**: `scripts/generate-options.sh`

```bash
#!/bin/bash
# Generate options dynamically

echo "Available options:"
echo "1. Option from config"
echo "2. Option from environment"
echo "3. Option from project files"

# Could read from files, APIs, etc.
```

### Context-Aware Skills

Skills can adapt based on project context:

```yaml
---
name: context-aware-generator
description: Generate code based on project type
---

# Context-Aware Generator

## Detection

First, detect project type:

\`\`\`bash
if [ -f "${CLAUDE_PROJECT_DIR}/package.json" ]; then
  echo "Node.js project detected"
elif [ -f "${CLAUDE_PROJECT_DIR}/Cargo.toml" ]; then
  echo "Rust project detected"
elif [ -f "${CLAUDE_PROJECT_DIR}/pom.xml" ]; then
  echo "Java project detected"
fi
\`\`\`

## Adaptation

Generate appropriate code based on detected type...
```

## Security Considerations

Security is critical when developing plugins.

### Hook Security Warning

**⚠️ SECURITY WARNING: HOOKS EXECUTE ARBITRARY CODE**

Hooks can:
- Execute any shell command
- Read/write any file on your system
- Make network requests
- Modify Claude Code behavior
- Access environment variables and secrets

**Before installing plugins with hooks**:
1. ⚠️ Review ALL hook code carefully
2. ⚠️ Only install hooks from trusted sources
3. ⚠️ Understand what each hook does
4. ⚠️ Test in isolated environment first
5. ⚠️ Be aware of filesystem and network access

**Never install hooks from unknown sources.** Malicious hooks can compromise your system.

### Security Best Practices

#### 1. Never Hardcode Secrets

**Bad**:
```json
{
  "config": {
    "apiToken": "secret-token-123"
  }
}
```

**Good**:
```json
{
  "config": {
    "apiToken": "${API_TOKEN}"
  }
}
```

#### 2. Validate Input

**Example**: Validate hook event data

```bash
#!/bin/bash
# Validate input before processing

read -r event_data

# Check if event_data is valid JSON
if ! echo "$event_data" | jq empty 2>/dev/null; then
  echo "Invalid event data"
  exit 1
fi

# Proceed with processing
```

#### 3. Sanitize User Input

**Example**: Sanitize command arguments

```bash
#!/bin/bash
# Sanitize file path argument

FILE_PATH="$1"

# Check for path traversal attempts
if [[ "$FILE_PATH" == *".."* ]]; then
  echo "Invalid file path"
  exit 1
fi

# Proceed with file operation
```

#### 4. Use Least Privilege

- Don't require root/admin permissions
- Only access necessary files
- Limit network requests to required endpoints

#### 5. Audit Third-Party Code

- Review all dependencies
- Check for known vulnerabilities
- Keep dependencies updated

## Plugin Scoping

Enterprise can scope plugins to specific teams.

### Scoped Plugin Configuration

```json
{
  "name": "frontend-toolkit",
  "version": "1.0.0",
  "scope": "@company/frontend-team",
  "description": "Frontend team's development toolkit"
}
```

### Benefits of Scoping

1. **Team isolation**: Prevent conflicts between teams
2. **Access control**: Limit plugin availability
3. **Version management**: Different teams can use different versions
4. **Customization**: Team-specific configurations

### Installing Scoped Plugins

```bash
/plugin install @company/frontend-toolkit
```

## Enabling and Disabling Plugins

Control which plugins are active.

### Enabling Plugins

**File**: `.claude/settings.json`

```json
{
  "enabledPlugins": [
    "my-plugin",
    "another-plugin",
    "team-utilities"
  ]
}
```

**Only plugins in this list will be loaded.**

### Disabling Plugins Temporarily

Remove from `enabledPlugins` without uninstalling:

```json
{
  "enabledPlugins": [
    "my-plugin"
    // "another-plugin" - disabled temporarily
  ]
}
```

### Disabling All Plugins

```json
{
  "enabledPlugins": []
}
```

### Default Behavior

If `enabledPlugins` is not specified, **all installed plugins are enabled**.

### Marketplace Configuration

Specify which marketplace plugins to install:

```json
{
  "marketplace": [
    "author/plugin-name",
    "author/another-plugin"
  ]
}
```

**Important**: This is an array format, not an object.

**Correct**:
```json
{
  "marketplace": [
    "company/react-toolkit",
    "company/api-helpers"
  ]
}
```

**Incorrect**:
```json
{
  "marketplace": {
    "react-toolkit": "company/react-toolkit"
  }
}
```

## Next Steps

- Review [Adding Components](adding-components.md)
- Learn about [Publishing](publishing.md)
- Study [Best Practices](best-practices.md)
- Set up [Team Marketplace](marketplace-setup.md)
