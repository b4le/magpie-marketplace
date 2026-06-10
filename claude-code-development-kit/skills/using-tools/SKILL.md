---
name: using-tools
description: "Guide for using Claude Code tools effectively. Covers which tool to use (Read, Edit, Write, Glob, Grep, Task, Bash), when to use them, parallel vs sequential execution, best practices, and common anti-patterns. Use when selecting tools, troubleshooting tool usage, or optimizing tool performance."
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
version: 1.0.0
created: 2025-11-20
last_updated: 2025-11-26
tags:
  - tools
  - best-practices
  - reference
---

## When to Use This Skill

Use this skill when:
- Selecting which tool to use for a task
- Troubleshooting tool usage or errors
- Optimizing tool performance
- Understanding parallel vs sequential execution
- Learning tool best practices and anti-patterns

### Do NOT Use This Skill When:
- ❌ Already know which tool to use → Just use the tool directly
- ❌ Need command/skill creation → Use `creating-commands` or `authoring-skills` instead
- ❌ Tool-specific errors → Use `resolving-claude-code-issues` for troubleshooting
- ❌ Quick tool reference → Use `best-practices-reference` for triage guide

## Core Principles

### Golden Rule: Never Speculate About Code You Haven't Opened

**Always read files before making assumptions about their contents.**

Wrong approach:
- "Based on typical React projects, this probably uses Redux..."
- "I assume the API uses REST..."
- "This likely follows the standard pattern..."

Correct approach:
- "Let me read the state management files to see what's being used."
- "I'll check the API client to understand the architecture."
- "I'll examine the existing code to identify the pattern."

**Why this matters**:
- Prevents hallucinations and incorrect assumptions
- Ensures recommendations match actual codebase
- Builds accurate mental model of the project
- Avoids wasting time on wrong approaches

### Use Specialized Tools, Not Bash

**Always prefer specialized tools over bash commands for file operations.** This provides better error handling, user experience, and context management.


## Quick Tool Selection Guide

```
Need to work with files?
├─ Know exact file path?
│  ├─ Read contents? → Read tool
│  ├─ Modify contents? → Edit tool (Read first!)
│  └─ Create new file? → Write tool (only if necessary!)
└─ Don't know path?
   ├─ Search by name/pattern? → Glob tool
   ├─ Search by content? → Grep tool
   └─ Open-ended exploration? → Task tool (Explore agent)

Need to run commands?
├─ File operations? → Use specialized tools (Read/Edit/Write/Glob/Grep)
├─ Terminal operations? → Bash tool
└─ Git operations? → Bash tool with git commands

Need to search/understand code?
├─ Specific file/class/pattern? → Glob or Grep
├─ How does X work? → Task tool (Explore agent)
└─ Within known files? → Read tool

Need to plan or implement?
├─ Break down complex task? → Task tool (Plan agent)
├─ Multi-step task (3+ steps)? → TaskCreate/TaskUpdate tools
└─ Need user input? → AskUserQuestion tool

Need external data?
├─ Web page content? → WebFetch tool
├─ Current information? → WebSearch tool
└─ External APIs/services? → MCP servers
```


## Tool Categories

### File Operation Tools

Essential tools for reading, writing, and editing files:

- **Read** - Read file contents from filesystem
- **Edit** - Perform exact string replacements in files
- **Write** - Write complete file contents (overwrites existing)
- **Glob** - Fast file pattern matching using glob patterns
- **Grep** - Search file contents using regex patterns

For detailed documentation: @reference/file-tools.md

### Task & Workflow Tools

Tools for complex operations and task management:

- **Task** - Launch specialized agents (Explore, Plan, General-Purpose) via `subagent_type` parameter
- **TaskCreate / TaskUpdate / TaskGet / TaskList** - Track multi-step tasks and demonstrate progress
- **AskUserQuestion** - Gather user input during execution

For detailed documentation: @reference/workflow-tools.md

### Command Execution Tools

Tools for running commands and git operations:

- **Bash** - Execute terminal commands in persistent shell
- Git via Bash - Create commits, pull requests, manage repositories

For detailed documentation: @reference/command-tools.md

### Web & External Tools

Tools for accessing external data:

- **WebFetch** - Fetch and analyze web content
- **WebSearch** - Search the web for current information
- **NotebookEdit** - Edit Jupyter notebook cells

For detailed documentation: @reference/web-tools.md


## Performance Tips

1. **Parallel execution**: Call independent tools in single message
2. **Right-sized agents**: Use haiku model for quick tasks
3. **Targeted searches**: Use specific patterns, not broad searches
4. **Incremental reading**: Use offset/limit for large files
5. **Context management**: Use /compact for resource usage


## Examples

### Example 1: Reading Multiple Files (Parallel)

```
Task: Review configuration across multiple files
Tools: Read (parallel)

Correct approach:
- Read config/database.json
- Read config/api.json
- Read config/app.json
[All in one message - parallel execution]
```

### Example 2: Search Then Read (Sequential)

```
Task: Find and read all TODO comments
Tools: Grep → Read (sequential)

Correct approach:
Step 1: Grep pattern: "TODO" --output_mode files_with_matches
Step 2: [Wait for results]
Step 3: Read [files from grep results]
```

For more examples: @reference/usage-examples.md

---

## Version History

**v1.2** - 2026-03-01
- Clarified that the tool is called `Task` with a `subagent_type` parameter (Explore, Plan, General-Purpose)
- Updated task management to `TaskCreate`/`TaskUpdate`/`TaskGet`/`TaskList` (supersedes legacy `TodoWrite`/`Tasks`)

**v1.1** - 2026-03-01
- Replaced `TodoWrite` with `Tasks` (tool renamed in Claude Code v2.1.16)

**v1.0** - 2025-11-18
- Initial skill creation from tools-reference.md
- 6 core capabilities
- 5 supporting reference files
- 4 @path imports for progressive disclosure
- Comprehensive tool coverage (Read, Edit, Write, Glob, Grep, Task, Bash, Web tools)
