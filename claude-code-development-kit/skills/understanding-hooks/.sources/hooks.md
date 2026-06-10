# Hooks Reference

This documentation provides a detailed reference for implementing hooks in Claude Code, covering configuration, event types, input/output handling, and best practices.

## Key Sections

1. Configuration
2. Hook Events
3. Hook Input
4. Hook Output
5. Working with MCP Tools
6. Security Considerations
7. Hook Execution Details
8. Debugging

## Core Concepts

Hooks in Claude Code allow you to:
- Execute commands at specific points in the Claude Code workflow
- Control tool usage and permissions
- Add context to conversations
- Validate and modify tool inputs
- Perform custom actions during session lifecycle

## Configuration Structure

Hooks are configured in JSON settings files with this basic structure:

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "ToolPattern",
        "hooks": [
          {
            "type": "command",
            "command": "your-command-here"
          }
        ]
      }
    ]
  }
}
```

### Key Configuration Elements

- **matcher**: Specifies which tools or events trigger the hook
- **type**: Defines hook execution type (`"command"`, `"http"`, `"prompt"`, or `"agent"`)
- **command**: Bash command to execute (for `command` type)
- **timeout**: Optional maximum runtime for the hook in seconds

## Hook Types

Supported hook events include:
- `PreToolUse`
- `PermissionRequest`
- `PostToolUse`
- `PostToolUseFailure`: Runs after a tool call fails
- `Notification`
- `UserPromptSubmit`
- `Stop`
- `SubagentStart`: Runs when a subagent is spawned
- `SubagentStop`
- `TeammateIdle`: Runs when an agent team teammate is about to go idle
- `TaskCompleted`: Runs when a task is being marked complete
- `PreCompact`
- `ConfigChange`: Runs when a config file changes mid-session
- `WorktreeCreate`: Runs when a worktree is being created
- `WorktreeRemove`: Runs when a worktree is being removed
- `SessionStart`
- `SessionEnd`

## Security Warning

> "USE AT YOUR OWN RISK": Claude Code hooks execute arbitrary shell commands on your system automatically.

Hooks can modify, delete, or access files, so extreme caution is recommended.

## Example Hook Script

Here's a Python example for validating bash commands:

```python
#!/usr/bin/env python3
import json
import re
import sys

VALIDATION_RULES = [
    (
        r"\bgrep\b(?!.*\|)",
        "Use 'rg' (ripgrep) instead of 'grep' for better performance and features",
    )
]

def validate_command(command: str) -> list[str]:
    issues = []
    for pattern, message in VALIDATION_RULES:
        if re.search(pattern, command):
            issues.append(message)
    return issues

# Script implementation continues...
```

## Best Practices

1. Validate and sanitize inputs
2. Quote shell variables
3. Block path traversal
4. Use absolute paths
5. Skip sensitive files

## Debugging

Use `claude --debug` to see detailed hook execution information.
