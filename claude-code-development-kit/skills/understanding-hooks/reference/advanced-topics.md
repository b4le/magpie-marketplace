# Advanced Hook Topics

Advanced patterns and techniques for Claude Code hooks.

## Hook Input Structure

Hooks receive JSON via stdin with this structure:

```json
{
  "tool_input": {
    "command": "ls -la",
    "description": "List files",
    "file_path": "/path/to/file"
  },
  "tool_name": "Bash",
  "hook_event_name": "PreToolUse"
}
```

### Available Fields by Tool

**Bash Tool**:
```json
{
  "tool_input": {
    "command": "npm install",
    "description": "Install dependencies",
    "timeout": 120000,
    "run_in_background": false
  }
}
```

**Edit Tool**:
```json
{
  "tool_input": {
    "file_path": "/path/to/file.ts",
    "old_string": "const x = 1",
    "new_string": "const x = 2",
    "replace_all": false
  }
}
```

**Write Tool**:
```json
{
  "tool_input": {
    "file_path": "/path/to/file.ts",
    "content": "file contents..."
  }
}
```

## Hook Output

Command and HTTP hooks can output a JSON object to control Claude Code behavior. There are three kinds of fields:

### Universal Fields

These apply to all events:

| Field | Default | Description |
|-------|---------|-------------|
| `continue` | `true` | If `false`, Claude stops processing entirely after the hook runs. Takes precedence over event-specific decision fields |
| `stopReason` | none | Message shown to the user when `continue` is `false`. Not shown to Claude |
| `suppressOutput` | `false` | If `true`, hides stdout from verbose mode output |
| `systemMessage` | none | Warning message shown to the user |

### Top-level `decision` and `reason`

Used by `UserPromptSubmit`, `PostToolUse`, `PostToolUseFailure`, `Stop`, `SubagentStop`, and `ConfigChange` to block. The only valid value for `decision` is `"block"`:

```json
{
  "decision": "block",
  "reason": "Test suite must pass before proceeding"
}
```

To allow, omit `decision` or exit 0 without any JSON.

### `hookSpecificOutput`

Used by `PreToolUse` and `PermissionRequest` for richer control. Requires a `hookEventName` field set to the event name:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Destructive command blocked by hook"
  }
}
```

### Exit Codes

- **`0`**: Allow operation. Claude Code optionally reads stdout for a JSON control object
- **`2`**: Block operation — stderr is shown to Claude as the reason. Any stdout JSON is ignored
- **Any other code**: Non-blocking error, execution continues

You must choose one approach per hook: either use exit codes alone for signaling, or exit 0 and print JSON for structured control.

## Chaining Hooks

Multiple hooks can be configured for the same event:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "hook1.sh"
          },
          {
            "type": "command",
            "command": "hook2.py"
          },
          {
            "type": "command",
            "command": "hook3.js"
          }
        ]
      }
    ]
  }
}
```

### Execution Order

Hooks within a matcher run **in parallel**. All hooks in the list execute, and if any exits with code **2**, the operation is **blocked**. Exit code 0 allows the operation (with optional JSON output); any other non-zero code (except 2) is treated as a non-blocking error and execution continues.

### Use Cases for Chaining

- **Validation Chain**: syntax check → security scan → business logic validation
- **Logging + Action**: log operation → perform validation
- **Progressive Enhancement**: basic check → detailed analysis → final approval

## Hook Types

Claude Code supports four hook handler types. All share a `type` field plus the common fields `timeout`, `statusMessage`, and `once` (skills only).

### Command Type (`"command"`)

Executes a shell command. The event JSON is passed via stdin. Results are communicated via exit codes and stdout.

```json
{
  "type": "command",
  "command": "python3 ~/.claude/hooks/validate.py",
  "timeout": 30,
  "async": false
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `command` | Yes | Shell command to execute |
| `timeout` | No | Seconds before canceling. Default: 600 |
| `async` | No | If `true`, runs in background without blocking Claude |

Setting `async: true` prevents the hook from blocking or controlling Claude's behavior — decision fields are ignored because the action already completed.

### HTTP Type (`"http"`)

Sends the event JSON as an HTTP POST request to a URL. The response body uses the same JSON output format as command hooks.

```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/pre-tool-use",
  "timeout": 30,
  "headers": {
    "Authorization": "Bearer $MY_TOKEN"
  },
  "allowedEnvVars": ["MY_TOKEN"]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `url` | Yes | URL to POST to |
| `headers` | No | Additional HTTP headers (supports `$VAR` interpolation) |
| `allowedEnvVars` | No | Variables allowed in header interpolation. Required for env var use |
| `timeout` | No | Seconds before canceling. Default: 600 |

HTTP hooks cannot signal blocking errors via status codes alone — return a 2xx response with a JSON body containing `decision: "block"` or `permissionDecision: "deny"` to block.

### Prompt Type (`"prompt"`)

Sends a single-turn prompt to a Claude model for yes/no evaluation. No shell execution. Use `$ARGUMENTS` as a placeholder for the hook's JSON input.

```json
{
  "type": "prompt",
  "prompt": "Evaluate if Claude should stop: $ARGUMENTS\n\nCheck if all tasks are complete.",
  "model": "claude-haiku-4-5",
  "timeout": 30
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `prompt` | Yes | Prompt text. Use `$ARGUMENTS` for event JSON. If omitted, JSON is appended to prompt |
| `model` | No | Model for evaluation. Defaults to a fast model |
| `timeout` | No | Seconds before canceling. Default: 30 |

The model must respond with JSON:
```json
{"ok": true}
```
or to block:
```json
{"ok": false, "reason": "Not all tasks are complete"}
```

All matching prompt hooks run in parallel. Identical handlers are deduplicated automatically.

### Agent Type (`"agent"`)

Spawns a subagent that can use tools (Read, Grep, Glob) to inspect files and verify conditions — up to 50 turns — before returning a decision. Use when a yes/no check requires inspecting actual file contents or test output rather than just the event data.

```json
{
  "type": "agent",
  "prompt": "Verify all unit tests pass before Claude stops. Run the test suite. $ARGUMENTS",
  "model": "claude-haiku-4-5",
  "timeout": 120
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `prompt` | Yes | Prompt describing what to verify. Use `$ARGUMENTS` for event JSON |
| `model` | No | Model to use. Defaults to a fast model |
| `timeout` | No | Seconds before canceling. Default: 60 |

The response schema is identical to prompt hooks: `{"ok": true}` or `{"ok": false, "reason": "..."}`.

### Side-by-side comparison

| | `command` | `http` | `prompt` | `agent` |
|---|---|---|---|---|
| Executes shell | Yes | No | No | No |
| Can read files | Yes (via script) | No | No | Yes (Read tool) |
| Default timeout | 600s | 600s | 30s | 60s |
| Can block actions | Yes | Yes | Yes | Yes |
| Can run async | Yes | No | No | No |
| Best for | Scripted validation, formatting | External services | Simple LLM checks | Multi-step inspection |

## Environment Variables in Hooks

### Claude Code Variables

Claude Code sets these environment variables for hook scripts:

| Variable | Available In | Description |
|----------|-------------|-------------|
| `$CLAUDE_PLUGIN_ROOT` | Plugin hooks | Absolute path to the plugin's root directory |
| `$CLAUDE_PROJECT_DIR` | All hooks | Absolute path to the project root (contains `.claude/`) |
| `$CLAUDE_ENV_FILE` | SessionStart only | File path for persisting env vars across the session |
| `$CLAUDE_CODE_REMOTE` | All hooks | Set to `"true"` in remote web environments; unset locally |

Note: The session identifier is available as `session_id` in the stdin JSON rather than as a shell environment variable.

### `$CLAUDE_PLUGIN_ROOT` — Reference plugin scripts

Use `${CLAUDE_PLUGIN_ROOT}` in plugin hooks (`hooks/hooks.json`) to reference scripts bundled with your plugin. This ensures hooks resolve correctly regardless of where Claude is invoked.

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/validate-skill-structure.sh"
      }]
    }]
  }
}
```

In the hook script:
```bash
#!/bin/bash
# The script itself can reference its own location via $0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
```

### `$CLAUDE_PROJECT_DIR` — Reference project scripts

Use `$CLAUDE_PROJECT_DIR` in project-scoped hooks to run scripts relative to the project root, regardless of cwd. Always quote it to handle directory paths with spaces.

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/check-style.sh"
      }]
    }]
  }
}
```

### `$CLAUDE_ENV_FILE` — Persist environment across the session

Available only in `SessionStart` hooks. Write `export VAR=value` statements to this file to make variables available to all subsequent Bash commands during the session.

```bash
#!/bin/bash
# Session setup hook: load project environment
if [ -n "$CLAUDE_ENV_FILE" ]; then
  # Set individual variables
  echo 'export NODE_ENV=development' >> "$CLAUDE_ENV_FILE"
  echo 'export API_BASE_URL=http://localhost:3000' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

Use append (`>>`) rather than redirect (`>`) to preserve variables set by other SessionStart hooks. To capture all environment changes from sourced scripts:

```bash
#!/bin/bash
ENV_BEFORE=$(export -p | sort)

# Load your environment tooling
source ~/.nvm/nvm.sh
nvm use 20

if [ -n "$CLAUDE_ENV_FILE" ]; then
  ENV_AFTER=$(export -p | sort)
  # Write only the new exports
  comm -13 <(echo "$ENV_BEFORE") <(echo "$ENV_AFTER") >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

### `$CLAUDE_CODE_REMOTE` — Detect remote environments

Conditionally adjust behavior based on whether the hook is running in a remote web environment:

```bash
#!/bin/bash
if [ "$CLAUDE_CODE_REMOTE" = "true" ]; then
  # Skip desktop notifications in remote environments
  exit 0
fi
# Run macOS notification
osascript -e 'display notification "Task complete" with title "Claude Code"'
```

### Setting Custom Environment for a hook

Pass temporary variables inline for one-off configuration:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "LOG_LEVEL=debug python3 ~/.claude/hooks/validate.py"
      }]
    }]
  }
}
```

### Standard shell variables

Hook scripts also inherit the standard shell environment:

```bash
#!/bin/bash
echo "User: $USER"
echo "Home: $HOME"
echo "Working dir: $PWD"
echo "PATH: $PATH"
```

## Working with MCP Tools

Hooks can integrate with MCP (Model Context Protocol) tools:

```python
#!/usr/bin/env python3
import json
import sys
import subprocess

data = json.load(sys.stdin)
tool_name = data.get('tool_name', '')

# If using an MCP tool, enhance with custom logic
if tool_name.startswith('mcp__'):
    # Custom handling for MCP tools
    result = subprocess.run(['mcp-cli', 'validate', tool_name],
                          capture_output=True)
    if result.returncode != 0:
        sys.exit(2)  # Block

sys.exit(0)
```

## Conditional Hook Execution

Execute hooks only under certain conditions:

```bash
#!/bin/bash
# Only run hook during work hours
hour=$(date +%H)
if [ $hour -lt 9 ] || [ $hour -gt 17 ]; then
    exit 0  # Skip hook outside work hours
fi

# Run normal hook logic
# ...
```

## Hook State Management

Hooks are stateless by default, but you can maintain state:

```python
#!/usr/bin/env python3
import json
import sys
from pathlib import Path

STATE_FILE = Path.home() / '.claude' / 'hook_state.json'

# Load state
state = {}
if STATE_FILE.exists():
    with open(STATE_FILE) as f:
        state = json.load(f)

# Update state based on event
data = json.load(sys.stdin)
state['last_command'] = data.get('tool_input', {}).get('command', '')
state['execution_count'] = state.get('execution_count', 0) + 1

# Save state
with open(STATE_FILE, 'w') as f:
    json.dump(state, f)

sys.exit(0)
```

## Performance Optimization

### Caching

```python
import functools
import hashlib

@functools.lru_cache(maxsize=128)
def expensive_validation(file_path):
    # Expensive operation cached by file path
    return validate_file(file_path)
```

### Async Operations

```bash
#!/bin/bash
# Run long operation in background, don't block
{
    # Long running task
    analyze_code_quality &
}

# Return immediately
exit 0
```

### Timeout Handling

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "timeout 3s python3 hook.py",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## Security Patterns

### Input Sanitization

```python
import re

def sanitize_path(path: str) -> str:
    # Remove dangerous patterns
    path = re.sub(r'\.\./', '', path)
    path = re.sub(r'[;&|`$]', '', path)
    return path

# Use sanitized path
safe_path = sanitize_path(data['tool_input']['file_path'])
```

### Sandboxing

```bash
#!/bin/bash
# Run hook script in restricted environment
firejail --noprofile --private python3 /path/to/hook.py
```

### Allowlist/Blocklist

```python
ALLOWED_COMMANDS = {'ls', 'cat', 'grep', 'git status'}
BLOCKED_PATHS = {'/etc/passwd', '~/.ssh/id_rsa'}

command = data['tool_input']['command'].split()[0]
if command not in ALLOWED_COMMANDS:
    sys.exit(2)  # Block
```

## Integration Patterns

### CI/CD Integration

```bash
#!/bin/bash
# Notify CI system of code changes
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$TOOL_NAME" == "Write" ]] && [[ -n "$FILE_PATH" ]]; then
    curl -X POST https://ci.example.com/webhook \
         -d "{\"file\": \"$FILE_PATH\"}"
fi
```

### Monitoring Integration

```python
import requests

# Send metrics to monitoring system
requests.post('https://metrics.example.com/hook-execution', json={
    'hook_type': 'PreToolUse',
    'tool_name': data['tool_name'],
    'timestamp': time.time()
})
```

### Version Control Integration

```bash
#!/bin/bash
# Auto-commit on certain file changes
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == *.md ]] && [[ -n "$FILE_PATH" ]]; then
    cd "$(dirname "$FILE_PATH")"
    git add "$FILE_PATH"
    git commit -m "Auto-commit: updated $(basename "$FILE_PATH")"
fi
```

## Testing Hooks

### Unit Testing

```python
import unittest
import json
from io import StringIO

class TestMyHook(unittest.TestCase):
    def test_blocks_dangerous_path(self):
        input_data = {
            'tool_input': {'file_path': '/etc/passwd'}
        }
        # Test hook logic
        result = validate_path(input_data)
        self.assertTrue(result.should_block)

if __name__ == '__main__':
    unittest.main()
```

### Integration Testing

```bash
#!/bin/bash
# Test hook with real Claude Code
echo '{"tool_input":{"command":"ls"}}' | \
    ~/.claude/hooks/my_hook.sh

if [ $? -eq 0 ]; then
    echo "✓ Hook passed"
else
    echo "✗ Hook failed"
    exit 1
fi
```
