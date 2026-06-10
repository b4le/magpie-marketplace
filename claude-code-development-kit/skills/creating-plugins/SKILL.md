---
name: creating-plugins
description: Comprehensive guide to creating, testing, publishing, and distributing Claude Code plugins with commands, skills, hooks, and MCP servers. Use when building plugins, creating plugin.json manifests, adding plugin components, testing locally with marketplaces, publishing to Git/npm, managing plugin versions, configuring hooks, troubleshooting plugin issues, or setting up team marketplaces.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - WebFetch
  - WebSearch
version: 1.0.0
created: 2025-11-20
last_updated: 2026-02-28
tags:
  - plugins
  - authoring
  - distribution
---

# Creating Claude Code Plugins

Comprehensive guide to creating, testing, publishing, and distributing Claude Code plugins.

## Create Your First Plugin in 3 Steps

If you have never created a plugin before, start here.

**Step 1: Create the manifest**

```bash
mkdir my-plugin
mkdir my-plugin/.claude-plugin
```

Create `my-plugin/.claude-plugin/plugin.json`:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "My first Claude Code plugin"
}
```

**Step 2: Add a skill**

```bash
mkdir -p my-plugin/skills/hello-world
```

Create `my-plugin/skills/hello-world/SKILL.md`:

```markdown
---
name: hello-world
description: Greet the user. Use when asked to say hello.
---

# Hello World Skill

Say "Hello from my-plugin!" and offer to help with whatever the user needs next.
```

**Step 3: Test locally**

```bash
# During development, load the plugin directly:
claude --plugin-dir /path/to/my-plugin

# Or create a local marketplace and install:
/plugin marketplace add /path/to/my-plugin
/plugin install my-plugin@my-plugin
```

Your plugin is now active. Ask Claude to say hello and the skill will invoke automatically.

For full details on each step, continue reading below or jump to **@guides/adding-components.md**.

---

## Do You Need a Plugin?

Before building a plugin, check whether a lighter-weight option covers your needs:

```
Do you need to share this with others or reuse it across projects?
├── No, just this session → Use a CLAUDE.md instruction or inline prompt
└── Yes → Continue
    │
    Is this a single standalone skill?
    ├── Yes → Create a skill directly (no plugin packaging needed)
    │          See: authoring-skills skill
    └── No → Continue
        │
        Is this a single slash command?
        ├── Yes → Create a command directly (no plugin packaging needed)
        │          See: creating-commands skill
        └── No → Build a plugin (you're in the right place)
            │
            Who will use it?
            ├── Just me, all projects → user scope (~/.claude/settings.json)
            ├── My team, this project → project scope (.claude/settings.json)
            ├── Personal, this project only → local scope (.claude/settings.local.json)
            └── Enterprise-wide → managed scope (admin-controlled)
```

---

## What are Plugins?

Plugins extend Claude Code with custom commands, skills, hooks, and MCP servers. They enable:

- **Custom Commands**: Create slash commands for team workflows
- **Specialized Skills**: Package domain expertise as reusable skills
- **Event Hooks**: Automate responses to Claude Code events
- **MCP Integration**: Bundle MCP servers with your plugin
- **Team Distribution**: Share via Git, npm, or team marketplaces

## When to Use This Skill

Use this skill when you need to:

- Build a new Claude Code plugin from scratch
- Create plugin.json manifests
- Add commands, skills, or hooks to a plugin
- Test plugins locally with marketplace configuration
- Publish plugins to Git or npm registries
- Set up team plugin marketplaces
- Manage plugin versions and updates
- Configure plugin hooks
- Troubleshoot plugin loading or installation issues

### Do NOT Use This Skill When:
- ❌ Creating a single skill without plugin packaging → Use `authoring-skills` instead
- ❌ Creating a single slash command → Use `creating-commands` instead
- ❌ Just understanding hooks → Use `understanding-hooks` instead
- ❌ Installing or using existing plugins → Use `/plugin` command directly

## Quick Start

**For detailed guides, see:**
- **@guides/adding-components.md** - Add commands, skills, hooks, MCP servers
- **@guides/best-practices.md** - Quality, testing, documentation standards
- **@guides/publishing.md** - Publish to Git, npm, team marketplaces
- **@guides/marketplace-setup.md** - Configure team plugin distribution
- **@guides/advanced.md** - Advanced patterns and techniques

**For reference documentation:**
- **@reference/structure.md** - Plugin directory structure
- **@reference/manifest.md** - plugin.json specification
- **@reference/commands.md** - Command authoring
- **@reference/configuration.md** - Configuration options
- **@reference/troubleshooting.md** - Common issues and solutions

**For examples:**
- **@examples/api-plugin.md** - Simple API integration plugin
- **@examples/fullstack-plugin.md** - Complete plugin with all components
- **@examples/workflows/** - Publishing, development, hooks workflows

**For templates:**
- **@templates/minimal-plugin-manifest.json** - Minimal manifest template
- **@templates/complete-plugin-manifest.json** - Complete manifest template
- **@templates/structures/complete-structure.md** - Full directory structure with all components
- **@templates/structures/minimal-structure.md** - Minimal starting structure
- **@templates/documentation/** - README and CHANGELOG templates

---

## LSP Server Configuration

Plugins can bundle a Language Server Protocol (LSP) server by including a `.lsp.json` file at the plugin root. LSP servers provide language-aware features (completions, diagnostics, hover) for custom languages or DSLs.

**LSP vs MCP at a glance:**

| | LSP (`.lsp.json`) | MCP (`.mcp.json`) |
|-|-------------------|-------------------|
| Purpose | Language intelligence | Tool and API integration |
| Consumers | Editors / IDEs | Claude |
| Use when | Custom language support | External service calls |

**Minimal `.lsp.json`:**

```json
{
  "my-language": {
    "command": "node",
    "args": ["${CLAUDE_PLUGIN_ROOT}/lsp/server.js", "--stdio"],
    "extensionToLanguage": {
      ".mylang": "my-language-id"
    }
  }
}
```

**Required fields:**

| Field | Description |
|-------|-------------|
| `command` | The LSP binary to execute (must be in PATH) |
| `extensionToLanguage` | Maps file extensions to language identifiers |

**Optional fields:**

| Field | Description |
|-------|-------------|
| `args` | Command-line arguments for the LSP server |
| `transport` | Communication transport: `stdio` (default) or `socket` |
| `env` | Environment variables to set when starting the server |
| `initializationOptions` | Options passed to the server during initialization |
| `settings` | Settings passed via `workspace/didChangeConfiguration` |
| `workspaceFolder` | Workspace folder path for the server |
| `startupTimeout` | Max time to wait for server startup (milliseconds) |
| `restartOnCrash` | Whether to automatically restart if the server crashes |

For detailed examples and best practices, see **@guides/adding-components.md** (Adding LSP Servers section).

---

## Plugin Default Settings

Plugins can include a `settings.json` file at the plugin root to declare default configuration applied when the plugin is enabled. Currently, only [agent](/en/sub-agents) settings are supported in plugin `settings.json`.

For detailed format and examples, see **@guides/adding-components.md** (Adding Default Settings section).

---

## Installation Scopes

When users install your plugin, they choose a scope that determines which settings file the `enabledPlugins` entry is written to. Plugins are cached at `~/.claude/plugins/cache` regardless of scope.

| Scope | Settings File | Use Case |
|-------|--------------|----------|
| `user` | `~/.claude/settings.json` | Personal plugins available across all projects (default) |
| `project` | `.claude/settings.json` | Team plugins shared via version control |
| `local` | `.claude/settings.local.json` | Project-specific plugins, gitignored |
| `managed` | Managed settings | Managed plugins (read-only, admin-controlled) |

**Recommendation for plugin authors:** State the recommended scope in your README. Team workflow plugins should recommend `project` scope so the installation is committed alongside code.

For full scope documentation, see **@guides/publishing.md** (Installation Scopes section).
