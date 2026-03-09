# Claude Code Development Kit

Complete toolkit for building Claude Code extensions - skills, commands, plugins, and supporting infrastructure.

## Quick Start

1. Run `/available-skills` to see what's available
2. Start with `using-tools` for Claude Code tool basics
3. Use `authoring-skills` to create your first skill
4. Use `creating-plugins` to package and share

## Who This Is For

- **New Claude Code users** learning the platform and its tooling model
- **Skill and command authors** building reusable extensions for themselves or their team
- **Plugin developers** creating distributable packages for the marketplace

## Learning Paths

| Track | Recommended order |
|-------|-------------------|
| **Beginner** | `using-tools` → `using-commands` → `best-practices-reference` |
| **Skill Author** | `authoring-skills` → `authoring-agent-prompts` → `authoring-output-styles` → `managing-memory` |
| **Plugin Developer** | `creating-plugins` → `creating-commands` → `integrating-mcps` → `understanding-hooks` |

## Skill Naming Conventions

Skills follow a verb-prefix pattern to signal intent at a glance:

| Prefix | Purpose |
|--------|---------|
| `authoring-*` | Creating content (skills, prompts, styles) |
| `creating-*` | Building components (plugins, commands) |
| `using-*` | Working with existing features |
| `understanding-*` | Learning concepts |
| `managing-*` | Configuration and settings |
| `integrating-*` | Connecting external tools |
| `resolving-*` | Troubleshooting |

## What's Included

### Skills (14)

| Skill | Description |
|-------|-------------|
| **authoring-skills** | Create Claude Code skills with YAML frontmatter, progressive disclosure, and best practices |
| **authoring-agent-prompts** | Write effective prompts for agents, skills, and tasks |
| **authoring-agents** | Guide to creating custom agents for Claude Code |
| **authoring-output-styles** | Define output styles for skills and document templates |
| **creating-commands** | Build custom slash commands with proper structure and arguments |
| **creating-plugins** | Create, test, publish, and distribute plugins |
| **using-commands** | Understand and use slash commands effectively |
| **using-tools** | Guide for selecting and using Claude Code tools |
| **managing-memory** | Create and manage CLAUDE.md memory files |
| **understanding-auto-memory** | Guide to Claude Code's automatic memory system |
| **understanding-hooks** | Comprehensive guide to hooks - event-driven automation with shell commands |
| **best-practices-reference** | Quick triage guide for Claude Code - helps you choose the right tool, skill, or feature for your task |
| **resolving-claude-code-issues** | Comprehensive troubleshooting guide for Claude Code installation, authentication, performance, tools, skills, and MCP issues |
| **integrating-mcps** | Complete guide to connecting and using Model Context Protocol (MCP) servers with Claude Code |

### Commands (3)

| Command | Description |
|---------|-------------|
| `/migrate-to-skill` | Migrate existing prompts or files into properly structured skills |
| `/skill-checklist` | Quick validation checklist for skill creation |
| `/available-skills` | Display all available skills from this plugin |

### Hooks (1)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `validate-skill-structure.sh` | PostToolUse/Write | Validates skill structure after Write tool operations on skill files |

## Installation

### Via Git

```bash
# Clone the marketplace repository
git clone git@<your-marketplace-repo>.git

# The plugin lives at:
# content-platform-marketplace/claude-code-development-kit

# Add to your Claude Code settings
# In ~/.claude/settings.json, add to plugins array:
{
  "plugins": [
    "/path/to/content-platform-marketplace/claude-code-development-kit"
  ]
}
```

### Via Marketplace

```bash
# If published to a marketplace
/plugin install claude-code-development-kit
```

### Manual Installation

1. Download or copy the plugin directory
2. Place in a location accessible to Claude Code
3. Add the path to your `~/.claude/settings.json` plugins array

## Usage

### Invoking Skills

```
# Ask Claude to use a skill
Use the authoring-skills skill to help me create a new skill

# Or reference directly
Read the skill at ./skills/authoring-skills/SKILL.md
```

### Using Commands

```
# Migrate a prompt to a skill
/migrate-to-skill ~/prompts/my-prompt.md my-new-skill

# Check skill structure
/skill-checklist

# See available skills
/available-skills
```

### Hook Behavior

The `validate-skill-structure.sh` hook runs after Write tool operations on skill files and:
- Validates YAML frontmatter presence and required fields
- Checks line count limits (max 500 lines)
- Verifies @path imports resolve to existing files

## Validation Tools

The `evals/` directory contains shell scripts for validating plugin components before distribution. Make scripts executable once with `chmod +x evals/*.sh`.

| Script | Purpose |
|--------|---------|
| `validate-plugin.sh` | Full plugin validation: manifest, README, all referenced components |
| `validate-skill.sh` | Checks SKILL.md frontmatter, line count, and @path imports |
| `validate-command.sh` | Checks command frontmatter and argument handling |
| `validate-hook.sh` | Checks shebang, executable bit, and safe scripting practices |
| `validate-output-style.sh` | Checks heading structure, examples, and actionable directives |
| `validate-references.sh` | Verifies cross-file references resolve |
| `validate-structure.sh` | Checks directory layout against expected conventions |
| `validate-agent.sh` | Validates agent prompt files |
| `validate-marketplace.sh` | Validates marketplace manifest entries |

```bash
# Validate a complete plugin
./evals/validate-plugin.sh /path/to/my-plugin

# Validate individual components
./evals/validate-skill.sh /path/to/skill-directory
./evals/validate-command.sh /path/to/command.md
./evals/validate-hook.sh /path/to/hook-script.sh
./evals/validate-output-style.sh /path/to/style.md
```

All scripts exit `0` on pass and `1` on failure, making them suitable for CI pipelines and pre-commit hooks. See `evals/README.md` for full details including CI integration examples.

## Skill Summaries

### authoring-skills
**Use when:** Creating new skills, writing SKILL.md files, designing skill workflows, or learning skill development patterns.

**Includes:**
- YAML frontmatter best practices
- Progressive disclosure patterns
- Skill templates (minimal, comprehensive, code-generation, analysis)
- Testing and troubleshooting guides

### authoring-agent-prompts
**Use when:** Crafting prompts for agents/skills that aren't producing desired results, structuring multi-step workflows, or debugging unexpected agent behaviors.

**Includes:**
- Core prompt engineering principles
- Error prevention patterns
- Workflow templates (feature implementation, code review, debugging)
- Anti-patterns to avoid

### authoring-agents
**Use when:** Creating custom agent definitions for Claude Code, defining agent roles and responsibilities, or building agent-based workflows.

**Includes:**
- Agent definition structure and frontmatter
- Role and responsibility patterns
- Agent composition and delegation patterns
- Testing and validation guides

### authoring-output-styles
**Use when:** Defining consistent formatting for skill outputs, creating document templates, or establishing style guidelines.

**Includes:**
- Style definition patterns
- Storage approaches (inline, external, registry)
- Document templates (briefs, reports, agent responses)
- Integration patterns

### creating-commands
**Use when:** Creating, designing, or authoring new slash commands.

**Includes:**
- Command structure and frontmatter
- Argument handling patterns
- Example commands (code review, git, testing, API)
- Troubleshooting guide

### creating-plugins
**Use when:** Building plugins from scratch, testing locally, publishing to Git/npm/team marketplaces.

**Includes:**
- Plugin structure and manifest specification
- Component guides (commands, skills, hooks, MCP)
- Publishing workflows
- Marketplace setup

### using-commands
**Use when:** Understanding what slash commands are, how to invoke them, or discovering available commands.

**Includes:**
- Built-in command reference
- Invocation patterns
- Plugin command namespacing
- Troubleshooting usage

### using-tools
**Use when:** Selecting which tool to use, troubleshooting tool usage, or optimizing tool performance.

**Includes:**
- Tool selection flowchart
- Parallel vs sequential execution
- Anti-patterns
- Usage examples

### understanding-auto-memory
**Use when:** Learning how Claude Code's automatic memory system works, understanding when memory is loaded automatically, or diagnosing memory-related behavior.

**Includes:**
- Automatic memory loading rules and precedence
- Memory file discovery and scoping
- Interaction between auto-memory and manual @path imports
- Troubleshooting unexpected memory behavior

### managing-memory
**Use when:** Creating CLAUDE.md files, organizing project memory, or implementing @path imports.

**Includes:**
- Memory hierarchy explanation
- Best practices and patterns
- Project-type examples
- Troubleshooting and maintenance guides

### understanding-hooks
**Use when:** Understanding hooks, creating hook scripts, or implementing event-driven automation in Claude Code.

**Includes:**
- Hook system overview and lifecycle
- Event triggers and patterns
- Shell script best practices for hooks
- Hook configuration and troubleshooting
- Integration with plugins and workflows

### best-practices-reference
**Use when:** Unsure where to start with a new task type, selecting between multiple tools/skills/commands, or need quick triage guidance.

**Includes:**
- Tool selection quick guide
- Agent orchestration decision framework
- Essential commands reference
- Common quick fixes

### resolving-claude-code-issues
**Use when:** Diagnosing problems with Claude Code installation, authentication, performance, tools, skills, or MCP connections.

**Includes:**
- Common error messages and solutions
- Diagnostic commands
- Installation and authentication troubleshooting
- Performance issue investigation
- Prevention strategies

### integrating-mcps
**Use when:** Connecting external services via MCP, configuring OAuth authentication, managing MCP servers, or creating custom MCP servers.

**Includes:**
- Transport types (HTTP, stdio) and configuration
- Connection scopes (local, user, enterprise)
- Authentication setup (OAuth 2.1, API keys)
- Security considerations and best practices
- Common use cases and advanced patterns

## Requirements

- Claude Code (latest version recommended)
- Bash shell (for hook execution)

## License

MIT

## Contributing

Contributions welcome. Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Version History

### 2.0.0
- Added `authoring-agents` skill - Guide to creating custom agents for Claude Code
- Added `understanding-auto-memory` skill - Guide to Claude Code's automatic memory system
- 14 skills total (up from 12)
- Schema overhaul: corrected required fields, hook event names, and handler formats
- Updated all 12 existing skills with corrected technical content and schema accuracy

### 1.0.0
- Initial release
- 12 skills for Claude Code extension development
- 3 utility commands
- 1 validation hook
- 1 output style
