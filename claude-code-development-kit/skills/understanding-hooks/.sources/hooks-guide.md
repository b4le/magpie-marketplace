# Get started with Claude Code hooks

## Overview

Claude Code hooks are user-defined shell commands that execute at various points in Claude Code's lifecycle. They provide deterministic control over the application's behavior, ensuring specific actions always occur.

## Key Use Cases for Hooks

* Notifications
* Automatic code formatting
* Logging
* Providing automated feedback
* Custom permissions and access controls

## Hook Events

Claude Code offers multiple hook events that run at different workflow stages:

1. **PreToolUse**: Runs before tool calls
2. **PermissionRequest**: Handles permission dialogs
3. **PostToolUse**: Runs after tool calls
4. **PostToolUseFailure**: Runs after a tool call fails
5. **UserPromptSubmit**: Triggers before Claude processes a prompt
6. **Notification**: Manages notification events
7. **Stop**: Runs when Claude Code finishes responding
8. **SubagentStart**: Runs when a subagent is spawned
9. **SubagentStop**: Executes when subagent tasks complete
10. **TeammateIdle**: Runs when an agent team teammate is about to go idle
11. **TaskCompleted**: Runs when a task is being marked complete
12. **PreCompact**: Runs before compact operations
13. **ConfigChange**: Runs when a config file changes mid-session
14. **WorktreeCreate**: Runs when a worktree is being created
15. **WorktreeRemove**: Runs when a worktree is being removed
16. **SessionStart**: Triggers at session beginning
17. **SessionEnd**: Runs when session concludes

## Quickstart: Logging Shell Commands

### Prerequisites
* Install `jq` for JSON processing

### Configuration Steps
1. Run `/hooks` and select `PreToolUse` event
2. Add a `Bash` matcher
3. Create a logging command:
```bash
jq -r '"\(.tool_input.command) - \(.tool_input.description // "No description")"' >> ~/.claude/bash-command-log.txt
```
4. Save configuration in user settings

## Advanced Hook Examples

### Code Formatting Hook
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | { read file_path; if echo \"$file_path\" | grep -q '\\.ts$'; then npx prettier --write \"$file_path\"; fi; }"
          }
        ]
      }
    ]
  }
}
```

### Markdown Formatting Hook
Includes a comprehensive Python script for intelligent markdown formatting, with language detection and code block management.

### Custom Notification Hook
```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "notify-send 'Claude Code' 'Awaiting your input'"
          }
        ]
      }
    ]
  }
}
```

### File Protection Hook
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 -c \"import json, sys; data=json.load(sys.stdin); path=data.get('tool_input',{}).get('file_path',''); sys.exit(2 if any(p in path for p in ['.env', 'package-lock.json', '.git/']) else 0)\""
          }
        ]
      }
    ]
  }
}
```

## Important Security Warning

Hooks run with your current environment's credentials, so malicious hook code could potentially exfiltrate data. Always carefully review hook implementations before registering them.

## Additional Resources

* Hooks reference documentation
* Security Considerations
* Debugging documentation
