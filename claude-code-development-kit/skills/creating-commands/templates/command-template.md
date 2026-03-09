# Command Template

Use this template when creating new slash commands.

```markdown
---
description: [Short description of what this command does]
argument-hint: [arg1] [arg2] [optional-arg3]
---

# [Command Name]

[Detailed description of command purpose]

## Arguments

- $1: [Description of first argument]
- $2: [Description of second argument]
- $3: [Description of optional third argument]

## Context Files

[If referencing files with @]
- @path/to/file: [Why this file is referenced]

## Bash Commands

[If executing bash commands, explain what they do]

## Instructions

[Detailed step-by-step instructions for Claude]

1. [First step]
2. [Second step]
3. [Third step]

## Example Usage

\`/command-name value1 value2 value3\`

## Notes

[Any additional context or warnings]
```
