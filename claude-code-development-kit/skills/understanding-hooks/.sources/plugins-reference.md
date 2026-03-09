# Hooks in Claude Code Plugins

## Overview
Hooks allow plugins to provide event handlers that automatically respond to Claude Code events.

## Location and Format
- Located at: `hooks/hooks.json` in plugin root
- Can be inline in `plugin.json`
- Configuration format is JSON

## Hook Configuration Example
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format-code.sh"
          }
        ]
      }
    ]
  }
}
```

## Available Events
- `PreToolUse`: Before using any tool
- `PermissionRequest`: During permission dialog
- `PostToolUse`: After using any tool
- `PostToolUseFailure`: After a tool call fails
- `UserPromptSubmit`: When user submits a prompt
- `Notification`: When Claude Code sends notifications
- `Stop`: When Claude attempts to stop
- `SubagentStart`: When a subagent is spawned
- `SubagentStop`: When a subagent attempts to stop
- `TeammateIdle`: When an agent team teammate is about to go idle
- `TaskCompleted`: When a task is being marked complete
- `ConfigChange`: When a config file changes mid-session
- `WorktreeCreate`: When a worktree is being created
- `WorktreeRemove`: When a worktree is being removed
- `SessionStart`: At session beginning
- `SessionEnd`: At session end
- `PreCompact`: Before conversation history compaction

## Hook Types
1. `command`: Execute shell commands or scripts
2. `http`: Send event data as POST request to a URL
3. `prompt`: Single-turn LLM evaluation for yes/no decisions
4. `agent`: Spawn a subagent with tools for multi-step verification

## Key Considerations
- Hooks are automatically discovered when a plugin is installed
- Use `${CLAUDE_PLUGIN_ROOT}` for reliable path referencing
- Ensure scripts are executable (`chmod +x script.sh`)
