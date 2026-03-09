# Adding Components to Plugins

This guide explains how to add commands, skills, hooks, and MCP servers to your Claude Code plugins.

## Table of Contents

- [Adding Commands](#adding-commands)
- [Adding Skills](#adding-skills)
- [Adding Hooks](#adding-hooks)
- [Adding MCP Servers](#adding-mcp-servers)
- [Adding LSP Servers](#adding-lsp-servers)
- [Adding Default Settings](#adding-default-settings)
- [Directory Structure](#directory-structure)

## Adding Commands

Commands are custom slash commands that users can invoke in Claude Code.

### Basic Command Structure

**Location**: `commands/[command-name].md`

**Format**:
```markdown
---
description: Brief description of what the command does
argument-hint: [argument-name]
---

Command instructions that Claude will execute.

Use $1, $2, etc. for command arguments.
```

### Example: Create React Component Command

**File**: `commands/create-component.md`

```markdown
---
description: Create React component with tests
argument-hint: [component-name]
---

Create a React component named $1.

Include:
- TypeScript types
- Props interface
- Default export
- CSS module
- Unit tests
- Storybook story

Follow project conventions from @.claude/CLAUDE.md
```

### Usage

After installing the plugin, users can invoke:
```bash
/my-plugin:create-component Button
```

### Command Best Practices

1. **Clear descriptions**: Make it obvious what the command does
2. **Argument hints**: Show users what inputs are expected
3. **Reference project context**: Use `@.claude/CLAUDE.md` for project-specific conventions
4. **Provide examples**: Include usage examples in the command documentation
5. **Namespace properly**: Use subdirectories for related commands

### Organizing Commands

Use subdirectories to organize related commands:

```
commands/
├── frontend/
│   ├── component.md
│   └── page.md
└── backend/
    ├── endpoint.md
    └── model.md
```

Users invoke with: `/my-plugin:frontend:component`, `/my-plugin:backend:endpoint`

## Adding Skills

Skills are specialized capabilities that Claude can invoke automatically when appropriate.

### Basic Skill Structure

**Location**: `skills/[skill-name]/SKILL.md`

**Format**:
```yaml
---
name: skill-name
description: When this skill should be used. Use when [specific scenario].
---

# Skill Name

Detailed instructions for executing this skill.

Include:
- Clear workflow steps
- Expected inputs/outputs
- Examples
- Error handling
```

### Example: Component Generator Skill

**Directory**: `skills/component-generator/`

**File**: `skills/component-generator/SKILL.md`

```yaml
---
name: component-generator
description: Generate React components following company patterns. Use when creating new React components.
---

# Component Generator Skill

This skill generates production-ready React components following company standards.

## When to Use

Invoke this skill when:
- User requests a new React component
- Creating UI elements that need testing and documentation
- Building reusable component library items

## Workflow

### 1. Gather Requirements
Ask the user:
- Component name
- Props needed
- Styling approach (CSS modules, styled-components, etc.)
- Test coverage level

### 2. Generate Component File

Create component with:
```typescript
import React from 'react';
import styles from './{ComponentName}.module.css';

interface {ComponentName}Props {
  // Props interface
}

export const {ComponentName}: React.FC<{ComponentName}Props> = (props) => {
  return (
    <div className={styles.container}>
      {/* Component JSX */}
    </div>
  );
};
```

### 3. Generate Tests

Create test file with:
- Component rendering tests
- Props validation tests
- User interaction tests
- Accessibility tests

### 4. Generate Storybook Story

Create story file showcasing component variants.

### 5. Update Documentation

Add component to README or component library documentation.

## Templates

Reference templates from plugin directory:
- `${CLAUDE_PLUGIN_ROOT}/templates/component.tsx`
- `${CLAUDE_PLUGIN_ROOT}/templates/test.spec.tsx`
- `${CLAUDE_PLUGIN_ROOT}/templates/story.tsx`

## Quality Checks

Before completing:
- [ ] Component follows naming conventions
- [ ] Props are properly typed
- [ ] Tests achieve target coverage
- [ ] Story demonstrates all variants
- [ ] Documentation is updated
```

### Skill Best Practices

1. **Specific descriptions**: Clearly state when the skill should be invoked
2. **Detailed workflows**: Provide step-by-step instructions
3. **Include examples**: Show expected inputs and outputs
4. **Reference templates**: Use templates for consistency
5. **Add quality checks**: Define completion criteria

## Adding Hooks

Hooks are scripts that execute at specific lifecycle events (pre-commit, post-edit, etc.).

### Basic Hook Structure

**Location**: `hooks/[hook-name].sh`

**Format**:
```bash
#!/bin/bash
# Description of what this hook does

# Hook logic here
# Exit 0 for success
# Exit non-zero to block the operation
```

### Example: Pre-commit Hook

**File**: `hooks/pre-commit.sh`

```bash
#!/bin/bash
# Pre-commit hook - runs before commits

echo "Running linter..."
npm run lint

if [ $? -ne 0 ]; then
  echo "Linting failed. Fix errors before committing."
  exit 1
fi

echo "Running tests..."
npm test

if [ $? -ne 0 ]; then
  echo "Tests failed. Fix failing tests before committing."
  exit 1
fi

echo "All checks passed!"
exit 0
```

### Make Hooks Executable

After creating a hook script:
```bash
chmod +x hooks/pre-commit.sh
```

### Hook Configuration File

For more control, use `hooks/hooks.json`:

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
    ]
  }
}
```

### Hook Configuration Options

Each event key maps to an array of matcher/hooks entry objects:

| Field | Required | Description |
|-------|----------|-------------|
| `matcher` | No | Tool name or glob pattern (e.g., `"Bash"`, `"Write\|Edit"`). Omit to match all. |
| `hooks` | Yes | Array of handler objects to execute |

Handler types supported in the `hooks` array:

| Type | Key fields | Default timeout |
|------|-----------|-----------------|
| `command` | `command` (string — shell command or script path) | 600s |
| `http` | `url` (string — endpoint to POST to) | 600s |
| `prompt` | `prompt` (string — model prompt text) | 30s |
| `agent` | `prompt` (string — agent task prompt) | 60s |

All handler types accept an optional `timeout` (integer, 1–600 seconds) and `statusMessage` (string shown while running).

### Hook Execution

- **Synchronous hooks** block until completion
- **Asynchronous hooks** run in background
- Hooks receive event data via stdin
- Hooks can block operations by exiting with non-zero code

### Security Warning

**⚠️ HOOKS EXECUTE ARBITRARY CODE ON YOUR SYSTEM**

Before installing plugins with hooks:
- Review ALL hook code carefully
- Only install hooks from trusted sources
- Understand what each hook does
- Test in isolated environment first
- Be aware hooks can access your filesystem and network

**Hooks can**:
- Execute any shell command
- Read/write any file on your system
- Make network requests
- Modify Claude Code behavior
- Access environment variables and secrets

**Never install hooks from unknown sources.** Malicious hooks can compromise your system.

## Adding MCP Servers

MCP (Model Context Protocol) servers enable integration with external services and APIs.

### Basic MCP Configuration

**Location**: `.mcp.json` at the plugin root

**Format**:
```json
{
  "servers": {
    "server-name": {
      "transport": "http|stdio",
      "url": "https://api.example.com",
      "description": "What this server provides"
    }
  }
}
```

### Example: MCP Servers Configuration

**File**: `.mcp.json`

```json
{
  "servers": {
    "company-api": {
      "transport": "http",
      "url": "https://api.company.com/mcp",
      "description": "Company internal API access"
    },
    "local-db": {
      "transport": "stdio",
      "command": "npx",
      "args": ["mcp-postgres", "${DATABASE_URL}"],
      "description": "Local PostgreSQL access"
    },
    "jira-integration": {
      "transport": "http",
      "url": "https://jira.company.com/mcp",
      "headers": {
        "Authorization": "Bearer ${JIRA_API_TOKEN}"
      },
      "description": "JIRA issue tracking integration"
    }
  }
}
```

### Transport Types

#### HTTP Transport
```json
{
  "server-name": {
    "transport": "http",
    "url": "https://api.example.com/mcp",
    "headers": {
      "Authorization": "Bearer ${API_TOKEN}"
    },
    "description": "HTTP-based MCP server"
  }
}
```

#### STDIO Transport
```json
{
  "server-name": {
    "transport": "stdio",
    "command": "npx",
    "args": ["mcp-server-package", "${CONFIG_PARAM}"],
    "description": "STDIO-based MCP server"
  }
}
```

### Environment Variables

Use environment variables for sensitive configuration:
```json
{
  "servers": {
    "api-server": {
      "transport": "http",
      "url": "${API_ENDPOINT}",
      "headers": {
        "Authorization": "Bearer ${API_TOKEN}"
      }
    }
  }
}
```

Users set environment variables:
```bash
export API_ENDPOINT="https://api.example.com"
export API_TOKEN="your-token-here"
```

### MCP Server Best Practices

1. **Use environment variables** for sensitive data
2. **Provide clear descriptions** of what each server does
3. **Document required environment variables** in README
4. **Test connectivity** before publishing
5. **Handle timeouts gracefully** for network requests

## Adding LSP Servers

Language Server Protocol (LSP) servers provide language-aware features such as completions, diagnostics, and hover documentation. Plugins can bundle an LSP server by declaring it in a `.lsp.json` file at the plugin root.

### LSP vs MCP

| Concern | LSP | MCP |
|---------|-----|-----|
| Purpose | Language intelligence (completions, diagnostics) | Tool and data integration |
| Protocol | Language Server Protocol | Model Context Protocol |
| Consumers | Editors and IDEs | Claude and AI assistants |
| Config file | `.lsp.json` | `.mcp.json` |

Use LSP when you need editor-quality language support (e.g., a custom DSL). Use MCP when you need Claude to call external tools or APIs.

### Basic LSP Configuration

**Location**: `.lsp.json` at the plugin root

**Format**:
```json
{
  "servers": {
    "server-name": {
      "command": "command-to-start-server",
      "args": ["--arg1", "--arg2"],
      "languages": ["languageId"],
      "rootUri": "${workspaceFolder}"
    }
  }
}
```

### Config Fields

| Field | Required | Description |
|-------|----------|-------------|
| `command` | Yes | Executable to launch the LSP server process |
| `args` | No | Arguments passed to the command |
| `languages` | Yes | Array of VS Code language IDs this server handles (e.g., `"typescript"`, `"python"`) |
| `rootUri` | No | Workspace root URI passed to the server on initialization. Use `${workspaceFolder}` for the project root. |

### Minimal LSP Example

**File**: `.lsp.json`

```json
{
  "servers": {
    "my-dsl": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/lsp/server.js", "--stdio"],
      "languages": ["my-dsl"],
      "rootUri": "${workspaceFolder}"
    }
  }
}
```

### Example: Python LSP Server

```json
{
  "servers": {
    "pylsp": {
      "command": "pylsp",
      "args": [],
      "languages": ["python"],
      "rootUri": "${workspaceFolder}"
    }
  }
}
```

### LSP Best Practices

1. **Bundle the server binary** or document installation steps in README
2. **Use `${CLAUDE_PLUGIN_ROOT}`** to reference files relative to the plugin installation
3. **Limit `languages`** to only the language IDs your server actually handles
4. **Document environment requirements** (Node.js version, Python version, etc.) in README

## Adding Default Settings

Plugins can ship default settings by including a `settings.json` file at the plugin root. These defaults are automatically merged with user-level and project-level settings when the plugin is installed.

### Settings Merge Precedence

Settings are merged in this order (highest precedence first):

1. Project settings (`.claude/settings.json` in the project)
2. User settings (`~/.claude/settings.json`)
3. Plugin defaults (`settings.json` in the plugin root)

Plugin defaults have the lowest precedence, so users and projects can always override them.

### Format

**Location**: `settings.json` at the plugin root

```json
{
  "settingKey": "defaultValue"
}
```

### Example: Plugin with Default Settings

**File**: `settings.json`

```json
{
  "my-plugin.outputFormat": "markdown",
  "my-plugin.verbosity": "normal",
  "my-plugin.maxResults": 10,
  "my-plugin.enableDraftMode": false
}
```

### Naming Convention

Prefix all setting keys with your plugin name to avoid conflicts with other plugins:

```json
{
  "react-toolkit.componentStyle": "functional",
  "react-toolkit.testFramework": "jest",
  "react-toolkit.includeStorybook": true
}
```

### Documenting Settings

Always document available settings in your README so users know what they can override:

```markdown
## Configuration

This plugin provides the following default settings. Override them in
your project's `.claude/settings.json` or user `~/.claude/settings.json`.

| Setting | Default | Description |
|---------|---------|-------------|
| `my-plugin.outputFormat` | `"markdown"` | Output format for generated files |
| `my-plugin.verbosity` | `"normal"` | Logging verbosity (`quiet`, `normal`, `verbose`) |
| `my-plugin.maxResults` | `10` | Maximum number of results to return |
```

## Directory Structure

### Complete Plugin Structure

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── commands/                 # Slash commands (legacy; prefer skills/ for new development)
│   ├── command1.md
│   ├── command2.md
│   └── frontend/            # Organized commands
│       ├── component.md
│       └── page.md
├── skills/                   # Skills (preferred for new development)
│   ├── skill1/
│   │   └── SKILL.md
│   └── skill2/
│       ├── SKILL.md
│       └── templates/       # Skill-specific templates
├── .claude/
│   └── agents/              # Sub-agent definitions (markdown files)
│       └── custom-agent.md
├── hooks/                    # Lifecycle hooks
│   ├── hooks.json           # Hook configuration
│   ├── pre-commit.sh
│   ├── post-edit.sh
│   └── scripts/             # Hook scripts
│       ├── validate.sh
│       └── log-bash.js
├── .mcp.json                 # MCP server configuration
├── .lsp.json                 # LSP server configuration (optional)
├── settings.json             # Default plugin settings (optional)
├── templates/                # Shared templates
│   ├── component.tsx
│   └── test.spec.ts
├── lib/                      # Shared utilities
│   └── helpers.sh
├── README.md                 # Plugin documentation
├── LICENSE                   # License file
└── CHANGELOG.md             # Version history
```

### Environment Variables Available in Plugins

Plugins have access to special environment variables:

#### ${CLAUDE_PLUGIN_ROOT}
Points to the plugin's installation directory:
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/helpers.sh"
cat "${CLAUDE_PLUGIN_ROOT}/config/defaults.json"
```

#### ${CLAUDE_PROJECT_DIR}
Points to the current working directory:
```bash
cat "${CLAUDE_PROJECT_DIR}/package.json"
cd "${CLAUDE_PROJECT_DIR}/src"
```

#### ${CLAUDE_CONFIG_DIR}
Points to Claude Code's configuration directory (`~/.claude`):
```bash
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

## Next Steps

- Learn about [Publishing Plugins](publishing.md)
- Review [Best Practices](best-practices.md)
- Explore [Advanced Topics](advanced.md)
- Set up [Team Marketplace](marketplace-setup.md)
