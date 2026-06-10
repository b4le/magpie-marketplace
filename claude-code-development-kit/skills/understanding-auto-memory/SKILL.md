---
name: understanding-auto-memory
description: Guide to Claude Code's auto-memory system — how MEMORY.md works, what gets saved automatically, how to use /memory and /remember commands, and how auto memory differs from manual CLAUDE.md files. Use when configuring auto memory, troubleshooting missing context, or deciding what to put in CLAUDE.md vs letting auto memory handle.
allowed-tools:
  - Read
  - Edit
  - Write
version: 1.0.0
created: 2026-02-28
last_updated: 2026-02-28
tags:
  - memory
  - auto-memory
  - memory-md
  - configuration
---

## When to Use This Skill

Use this skill when:
- Understanding how auto memory works and where it stores data
- Deciding what to put in CLAUDE.md vs letting auto memory capture
- Configuring or toggling auto memory for a project
- Using `/memory` or `/remember` commands effectively
- Troubleshooting why context is not persisting across sessions

### Do NOT Use This Skill When:
- Creating or editing CLAUDE.md files — use the `managing-memory` skill instead
- Just running `/memory` to open a file — do it directly without invoking the skill
- Using `@path` imports in CLAUDE.md — covered in `managing-memory`
- Auto memory is working fine and no configuration changes are needed

## Memory System Overview

Claude Code has two kinds of memory that persist across sessions:

| Type | Written by | Purpose |
|------|-----------|---------|
| **CLAUDE.md files** | You | Instructions, conventions, project standards |
| **Auto memory (MEMORY.md)** | Claude | Learnings, patterns, preferences Claude discovers |

Both are loaded into context at the start of every session. Auto memory loads only the first 200 lines of `MEMORY.md`. CLAUDE.md files are loaded in full.

**Key distinction:** CLAUDE.md contains what *you* want Claude to know. Auto memory contains what *Claude* has learned during sessions.

## MEMORY.md — Auto-Generated Memory

Auto memory is a persistent directory where Claude records learnings as it works. It is **enabled by default**.

Claude writes to auto memory when it:
- Discovers patterns in your codebase (e.g., "this project uses pnpm, not npm")
- Learns your preferences from corrections (e.g., preferred naming conventions)
- Captures key decisions made during a session
- Notes project-specific commands and configurations

### What Gets Remembered

Claude captures:
- Build tool and package manager preferences (`pnpm` not `npm`)
- Naming conventions and code style patterns observed in the codebase
- API endpoints, environment variable names, and config keys
- Decisions you made during sessions ("we chose Postgres over MySQL")
- Corrections you gave Claude ("don't use default exports here")
- Frequently used commands and their flags

### What Does NOT Get Remembered Automatically

Auto memory does not capture everything — Claude is selective. For important stable rules, put them in CLAUDE.md explicitly rather than relying on auto memory.

## Memory Storage Location

Each project gets its own memory directory:

```
~/.claude/projects/<project>/memory/
├── MEMORY.md          # Concise index, loaded into every session
├── patterns.md        # Optional topic file (Claude-managed)
└── commands.md        # Optional topic file (Claude-managed)
```

The `<project>` path is derived from the git repository root. All subdirectories and all worktrees within the same repo share one auto memory directory.

`MEMORY.md` acts as an index. Claude reads and writes files in this directory throughout your session, using `MEMORY.md` to track what is stored where.

See @reference/memory-md-format.md for the file structure and entry format.

## Memory Commands

**`/memory`** — Opens the file selector showing all loaded memory files (`MEMORY.md`, CLAUDE.md files). Also includes the auto-memory toggle to enable or disable the feature.

**Save context explicitly** — Tell Claude in natural language: `"Remember that we use pnpm, not npm"` or `"Save to memory that API tests require a local Redis instance"`. Claude writes to auto memory immediately.

See @reference/memory-commands.md for full command reference and options.

## Memory Scoping

| Scope | Location | Shared? |
|-------|----------|---------|
| Project auto memory | `~/.claude/projects/<project>/memory/` | No — per user |
| User CLAUDE.md | `~/.claude/CLAUDE.md` | No — personal |
| Project CLAUDE.md | `.claude/CLAUDE.md` | Yes — committed to git |

Auto memory is always **user-local** — it is stored in your home directory, not in the repository. It is never shared with teammates.

## Disabling Auto Memory

| Method | How |
|--------|-----|
| Per-session toggle | Run `/memory`, use the auto-memory toggle |
| User settings (all projects) | Add `"autoMemoryEnabled": false` to `~/.claude/settings.json` |
| Project settings (single project) | Add `"autoMemoryEnabled": false` to `.claude/settings.json` |
| Environment variable (CI) | `export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` |

The environment variable takes precedence over all other settings. Use it in CI pipelines where auto memory is not appropriate.

## What to Put in CLAUDE.md vs Auto Memory

| Put in CLAUDE.md | Let auto memory handle |
|-----------------|----------------------|
| Team-wide conventions | Personal preferences Claude has observed |
| Non-obvious architecture decisions | Package manager / build tool (Claude will learn) |
| Rules that must always apply | Patterns Claude has already discovered |
| Context teammates need | One-off session learnings |
| Secrets that are NOT secrets (e.g., public API base URLs) | Corrections you gave Claude verbally |

**Practical rule:** If something must *reliably* be followed across all sessions and by all teammates, write it in CLAUDE.md. If it is a personal preference or project pattern Claude will naturally observe, let auto memory capture it.

## @path Imports

CLAUDE.md files can import additional files using `@path/to/file` syntax. Imports work in CLAUDE.md files only — `MEMORY.md` is managed entirely by Claude and does not support imports. See the `managing-memory` skill for full import documentation.

## Related Documentation

- **managing-memory** skill — creating and editing CLAUDE.md files, @path imports, hierarchy
- @reference/memory-commands.md — `/memory` command reference and options
- @reference/memory-md-format.md — MEMORY.md file structure and entry format
- Official docs: https://code.claude.com/docs/en/memory
