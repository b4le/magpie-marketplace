---
name: using-commands
description: Guide for understanding and using slash commands in Claude Code - covers built-in commands, custom commands, plugin commands, invocation patterns, and troubleshooting. Use when users want to understand what slash commands are, how to invoke them, discover available commands, or troubleshoot command usage.
version: 1.0.0
created: 2025-11-20
last_updated: 2025-11-26
tags:
  - commands
  - slash-commands
  - usage
---

# Using Slash Commands

Guide to understanding and using slash commands in Claude Code.

## When to Use This Skill

Use this skill when:
- Understanding what slash commands are and how to invoke them
- Discovering available commands
- Learning command invocation patterns
- Troubleshooting command usage

### Do NOT Use This Skill When:
- ❌ Creating new slash commands → Use `creating-commands` instead
- ❌ Creating plugins with commands → Use `creating-plugins` instead
- ❌ Already know how to use commands → Just invoke the command directly
- ❌ Need tool selection guidance → Use `using-tools` or `best-practices-reference` instead

## What Are Slash Commands?

Slash commands are shortcuts that control Claude's behavior and trigger custom interactions. They provide:
- Quick access to reusable prompts
- Standardized team workflows
- Parameterized instructions
- File and bash command integration

## Types of Slash Commands

### 1. Built-in Commands

Pre-defined commands that come with Claude Code:

| Command | Purpose |
|---------|---------|
| `/help` | Get help with Claude Code |
| `/clear` | Clear conversation history |
| `/export` | Export conversation |
| `/permissions` | Configure approval settings |
| `/memory` | Edit memory files |
| `/compact` | Reduce resource usage |
| `/rewind` | Access checkpoint history |
| `/doctor` | Check installation health |
| `/bug` | Report issues |
| `/vim` | Enable vim mode |
| `/logout` | Log out of Claude Code |
| `/init` | Bootstrap project memory |
| `/mcp` | Configure MCP servers |
| `/plugin` | Manage plugins |
| `/output-style` | Change output style |

### 2. Custom Commands

User-created commands stored as Markdown files in:
- **Project Commands**: `.claude/commands/` - Shared with team
- **Personal Commands**: `~/.claude/commands/` - Your commands only

### 3. Plugin Commands

Commands bundled with installed plugins, invoked with namespace:
- `/plugin-name:command-name`

## Command Invocation Patterns

### Basic Invocation

```
/command-name
```

Example: `/help`

### With Arguments

```
/command-name arg1 arg2 arg3
```

Example: `/review-pr 123 high @john`

### Namespaced (Subdirectories)

```
/namespace:command-name arg1 arg2
```

Examples:
- `/git:review-pr 123`
- `/testing:run-unit`
- `/deploy:staging`

### Plugin Commands

```
/plugin-name:command-name arg1
```

Example: `/example-skills:canvas-design "Create a poster"`

### Combining with @ File References

```
/review @src/components/Button.tsx
```

You can reference files in the command invocation AND in the command definition.

## Discovering Available Commands

### List All Commands

Type `/` in Claude Code to see all available commands with descriptions.

### View Command Help

Most commands include a `description` and `argument-hint` to guide usage:

```
/command-name [arg1] [arg2]
```

### Explore Project Commands

```bash
ls .claude/commands/
```

### Explore Personal Commands

```bash
ls ~/.claude/commands/
```

### View Plugin Commands

Check installed plugins:

```
/plugin
```

## How Slash Commands Work

1. **User types command**: `/review-pr 123`
2. **Claude Code finds file**: `.claude/commands/review-pr.md`
3. **Arguments expand**: `$1` becomes `123`
4. **File references load**: `@CLAUDE.md` content is included
5. **Bash commands execute**: `!git status` runs and output is captured
6. **Full prompt sent to Claude**: With expanded template, file contents, bash output

## Command Locations

Commands are discovered in this order:

1. `.claude/commands/` (project-specific, version controlled)
2. `~/.claude/commands/` (personal, across all projects)
3. Plugin commands (from installed plugins)

If multiple commands have the same name, the first one found takes precedence.

## Common Usage Patterns

### Code Review

```
/code-review src/components/UserProfile.tsx
```

### Testing

```
/test UserProfile
/test:unit utils
/test:integration api
```

### Git Workflows

```
/git:commit "Add user authentication"
/git:review-pr 123
```

### Deployment

```
/deploy:staging
/deploy:production
```

### Code Generation

```
/new-component Button
/api:new-endpoint POST /api/users "Create user"
```

## Troubleshooting

See @reference/troubleshooting-usage.md for solutions to:
- Command not found
- Arguments not working as expected
- Understanding command output
- Permission issues

## Skill Tool Limitations

When Claude invokes skills programmatically with the Skill tool:
- Cannot invoke skills that are already running
- Cannot invoke built-in CLI commands (like /help, /clear)
- Only works with custom skills listed in Available Commands
- Permission syntax for allowing skill invocation: `Skill(skill-name)`

Use the `Skill` tool (not `SlashCommand`) for invoking skills programmatically.

## Creating Your Own Commands

Want to create custom slash commands? Invoke the `creating-commands` skill to learn how to author effective slash commands.

Quick start:
1. Create `.claude/commands/my-command.md`
2. Add your prompt content
3. Optionally add YAML frontmatter for metadata
4. Use `/my-command` to invoke

See the `creating-commands` skill for complete guidance.

## Resources

- Slash Commands Documentation: https://code.claude.com/docs/en/skills
- Creating Commands Skill: Invoke `creating-commands` skill for command authoring

## Version History

### v1.1.0 (2026-03-01)
- Renamed "SlashCommand Tool Limitations" section to "Skill Tool Limitations"
- Replaced references to `SlashCommand` tool with correct `Skill` tool
- Added permission syntax `Skill(skill-name)`

### v1.0.0 (2025-11-18)
- Created from slash-commands-guide.md migration
- Separated from creating-commands skill
- Focus on command usage and understanding
- Implemented progressive disclosure architecture
