# Hooks Configuration in Settings

## Overview
Hooks can be configured in the `settings.json` file, which can be located in:
- User settings: `~/.claude/settings.json`
- Project settings: `.claude/settings.json`
- Local project settings: `.claude/settings.local.json`

## Hook Configuration Example

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Running command...'"
          }
        ]
      }
    ]
  },
  "disableAllHooks": false
}
```

## Key Hook Settings

| Setting | Description | Example |
|---------|-------------|---------|
| `hooks` | Configure event-driven handlers (array of matcher objects with nested hook definitions) | `{"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "..."}]}]}` |
| `disableAllHooks` | Completely disable all hooks | `true` or `false` |

## Important Notes
- Hooks can be set to run before or after tool use
- Can be configured at user, project, or local project levels
- The `disableAllHooks` setting provides a quick way to turn off all hook functionality

For more detailed information about creating and using hooks, refer to the hooks documentation.
