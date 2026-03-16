---
name: devkit-investigate
description: Extract and present the full investigation prompt for a roadmap item, ready to execute
argument-hint: "<item-id, e.g. 1.1 or 2.1>"
allowed-tools:
  - Read
  - Grep
user-invocable: true
version: 1.0.0
---

Extract and present the full investigation prompt for a specific roadmap item.

Read the roadmap file:
@${CLAUDE_PLUGIN_ROOT}/docs/roadmap.md

## Arguments

`$ARGUMENTS` accepts:
- An item ID like `1.1`, `2.1`, `4.2` — matches roadmap section headers of the form `### 1.1 ...`
- `--next` — selects the highest-priority planned item automatically

## Argument Parsing

`$ARGUMENTS` should contain an item ID matching the roadmap numbering (e.g., `1.1`, `2.1`, `4.2`).

To locate the item, search for a section header starting with `### {id}` (e.g., `### 1.1` for item `1.1`). The section runs until the next `###` header.

If no argument is provided, show the summary table from `/devkit-roadmap` and ask which item to investigate.

If the argument doesn't match any roadmap item, show the available IDs and ask the user to pick one.

## Output

For the matched item, present:

### 1. Context Header
```
--- Investigation: {item-id} {skill-name} ---
Theme: {theme-name}
Priority: {priority}
Status: {status}
Type: {new-skill | update}
```

### 2. Problem Statement
Extract the problem statement and sub-problems from the roadmap item.

### 3. Investigation Prompt
Extract the full code-fenced investigation prompt exactly as written in the roadmap. This is the prompt the user will copy into a new session.

### 4. Next Steps
Present two options:
- **Copy and run in a new session**: The prompt is self-contained and designed for autonomous execution
- **Run here**: If the user wants to execute in the current session, warn that investigation prompts are context-heavy (research + synthesis + implementation) and recommend a dedicated session

If the user says "run it", "execute", "go", or similar — execute the investigation prompt directly in the current session. Before doing so, remind them this will consume significant context and suggest a new session for best results. If they confirm, proceed.

## Filters

If `$ARGUMENTS` is `--next`, find the highest-priority planned item (P0 first, then lowest ID) and present that one.
