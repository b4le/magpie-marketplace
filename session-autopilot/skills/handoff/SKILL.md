---
name: handoff
description: >-
  Invoke on "/handoff", "summarise for handoff", "prep for a new session",
  "wrap up", "save my progress", "I'm done for today", "end session", or
  "write a handoff". Writes a structured handoff document capturing goal,
  decisions, files touched, and next steps for seamless session continuity.
user-invocable: true
---

# Manual Session Handoff

Write a detailed handoff document so the next session (or a different person) can pick up exactly where this one left off.

## Output Location

Write the handoff to: `.claude/handoffs/{branch}_{timestamp}.md` under the project root.

- Resolve project root via `git rev-parse --show-toplevel` or the current working directory.
- Branch: sanitize slashes to dashes (e.g., `feature/auth` → `feature-auth`)
- Timestamp: UTC format `YYYYMMDDTHHMMSSZ` (e.g., `20260304T183022Z`)

## Handoff Format

Use this exact template:

```
# Session Handoff
**Updated:** {ISO timestamp}
**Project:** {project path}
**Branch:** {branch}
**HEAD:** {short SHA}

## Goal
{1-2 sentences: what this session was trying to accomplish}

## Where I got to
{Bullet list of what was accomplished. Be specific — file names, function names, decisions.}

## What's not done
{Checkbox list of remaining work. Be specific enough that someone with zero context can execute.}

## Key decisions made
{Bullet list of decisions and their rationale. Include alternatives that were rejected and why.}

## Files touched
{output of git status --short}
{Highlight any new files with a brief description}

## Blockers / open questions
{Anything that's unclear or needs external input}

## How to continue
{Numbered steps for the next session. Start with "Read X" to establish context, then list actions.}
```

## Instructions

1. Review the conversation to extract: goal, progress, decisions, remaining work
2. Run `git status` and `git diff --stat` to capture file state
3. Run `git log --oneline -5` for recent commits
4. Write the handoff using the template above
5. Copy the handoff to `.claude/handoffs/latest.md` (overwriting any previous latest) for quick access
6. After writing, confirm to the user: "Handoff saved to `.claude/handoffs/{filename}`"

> **Note:** The auto-handoff hook will skip writing if this manual handoff was created within the last 60 seconds.
