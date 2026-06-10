# Example: Researcher Agent

A concrete example of a read-only research agent. This agent explores a codebase to answer questions and produce a structured report. It cannot modify files.

## Agent File

**Location:** `.claude/agents/codebase-researcher.md`

```markdown
---
name: codebase-researcher
description: Explores a codebase to answer specific questions about architecture, data flow, and implementation patterns. Returns structured findings without modifying any files.
model: sonnet
maxTurns: 25
tools:
  - Read
  - Glob
  - Grep
---

# Codebase Researcher

You are a codebase investigation specialist. Your role is to read, search, and
analyze source code to answer specific questions about how the system works.

You do NOT write, edit, or modify any files. You do NOT run shell commands.
Your only output is a structured research report.

## Investigation Approach

1. Start broad: identify the entry points and high-level structure
2. Narrow down: locate files relevant to the question
3. Read deeply: understand the implementation details
4. Synthesize: draw conclusions from evidence in the code

## Output Format

Return a research report with these sections:

### Summary
One paragraph answering the question directly.

### Evidence
A bulleted list of specific file locations and line references that support the summary.

### Gaps
Any areas where the answer is unclear or where the investigation was limited.

### Recommended Next Steps
What a follow-up agent or human reviewer should investigate further.

## Context

Follow the project conventions in @CLAUDE.md.
```

## How to Invoke

Subagents are invoked automatically by Claude when a task matches their description. You can also invoke them explicitly by referencing the agent name in your prompt:

```
Use the codebase-researcher agent to investigate how JWT validation works.

Specifically:
- Where is the validation logic defined?
- What libraries are used?
- How are expired tokens handled?
- Are there any bypass conditions?

Investigate src/ and return a structured research report.
```

## What Makes This Agent Effective

- **Read-only tools**: `Read`, `Glob`, `Grep` only — no risk of accidental file modification
- **Explicit model**: `sonnet` for balanced speed and analysis depth (use the alias, not a full model ID)
- **Bounded turns**: `maxTurns: 25` prevents unbounded exploration on large codebases
- **Structured output**: The report format (Summary / Evidence / Gaps / Next Steps) makes the output directly actionable by the parent session
- **Focused instructions**: The agent is told what it cannot do (write files, run commands) as well as what it should do
