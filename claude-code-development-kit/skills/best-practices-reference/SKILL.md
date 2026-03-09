---
name: best-practices-reference
description: Quick triage guide for Claude Code - helps you choose the right tool, skill, or feature for your task. Use when unsure where to start, selecting tools, troubleshooting common issues, or deciding between skills/commands/MCP/plugins.
version: 1.0.0
created: 2025-11-20
last_updated: 2026-02-28
tags:
  - best-practices
  - triage
  - reference
---

## When to Use This Skill

Use this skill when:
- Unsure where to start with a new task type
- Selecting between multiple tools, skills, or commands
- Need quick command reference or triage guidance
- Deciding between skills/commands/MCP/plugins for a task

### Do NOT Use This Skill When:
- ❌ Need detailed implementation guidance → Use specialized skills instead (e.g., `authoring-skills`, `integrating-mcps`)
- ❌ Need comprehensive troubleshooting → Use `resolving-claude-code-issues` instead
- ❌ Already know which tool/skill to use → Invoke it directly
- ❌ Need in-depth reference material → Use topic-specific skills (e.g., `using-tools`, `using-commands`)

## Tool Selection Quick Guide

### File Operations - Use Specialized Tools, NOT Bash

| Task | Use This Tool | NOT This |
|------|---------------|----------|
| Read file contents | `Read` | cat, head, tail |
| Search code for patterns | `Grep` | grep, rg bash commands |
| Find files by pattern | `Glob` | find, ls |
| Edit file contents | `Edit` | sed, awk |
| Write new files | `Write` | echo >, cat <<EOF |

### When to Use Task Tool with Agents

**Use `Task` tool with specialized agents:**

- **subagent_type=Explore**:
  - Exploring codebase structure
  - Understanding how features work
  - Questions like "how does X work?" or "where is Y handled?"
  - Any open-ended search requiring multiple rounds

- **subagent_type=Plan**:
  - Breaking down complex implementation tasks
  - Planning multi-step features before coding
  - NOT for research/exploration tasks

**When NOT to use Task tool:**
- Reading a specific known file path → Use `Read`
- Searching for specific class "class Foo" → Use `Glob`
- Searching within 2-3 specific files → Use `Read`

### Agent Orchestration Quick Guide

**The key question:** Do agents need to discuss with each other, or just report back?

| Scenario | Pattern |
|----------|---------|
| Agents work independently, you synthesize | Subagents (Task tool) |
| Agents need to debate/challenge each other | Agent Teams (TeamCreate) |
| Complex multi-phase project | `/orchestrate` (multi-agent-workflows) |
| Need approval gates mid-execution | iterative-agent-refinement |

**Quick commands:**
- `/delegate` - Interactive guide to choosing the right pattern
- `/orchestrate my-project` - Initialize phased workflow

### Parallel vs Sequential Tool Calls

**Call in parallel** (single message with multiple tool calls):
- Independent operations: reading multiple files, git status + git diff
- Multiple searches that don't depend on each other

**Call sequentially** (wait for results between calls):
- Dependent operations: mkdir before cp, git add before git commit
- When later tool calls need data from earlier results


## Essential Commands Quick Reference

### Quick Access
- `#` - Quick memory addition
- `@` - File path autocomplete
- `/` - Access slash commands
- `!` - Direct bash mode

### Key Built-in Commands

| Command | Purpose |
|---------|---------|
| `/help` | Get help with Claude Code |
| `/permissions` | Configure approval settings |
| `/memory` | Edit memory files |
| `/compact` | Reduce resource usage |
| `/rewind` | Access checkpoint history |
| `/doctor` | Check installation health |
| `/mcp` | Manage MCP servers |
| `/plugin` | Manage plugins |
| `/vim` | Enable vim mode |

### Interactive Mode Shortcuts
- `Ctrl+C` - Cancel current input
- `Ctrl+D` - Exit session
- `Ctrl+L` - Clear screen
- `ESC ESC` - Access rewind/checkpoint menu


## Common Quick Fixes

**Permission prompts keep appearing**: `/permissions` to configure settings

**High resource usage**: `/compact` to reduce memory usage

**Authentication problems**: `/logout`, then restart and re-authenticate

**Access checkpoints**: Press `ESC` twice or `/rewind`

**System health check**: `/doctor`

For comprehensive troubleshooting, use `resolving-claude-code-issues` skill.
