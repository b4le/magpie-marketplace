# Plugin Hooks Configuration Guide

## Hook Configuration File

**Location**: `hooks/hooks.json` within the plugin directory

Hooks are also configurable inline in `plugin.json` via the `hooks` field. In both cases the structure is identical.

### Basic Structure

Hook configuration maps **event names** to arrays of matcher/hooks objects. Each event key holds an array; each array element specifies a `matcher` (which tool to match) and a `hooks` array of handler objects to execute.

```json
{
  "PostToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "echo 'tool used'"
        }
      ]
    }
  ]
}
```

When referenced from `plugin.json`, the inline configuration sits directly under the `"hooks"` key:

```json
{
  "name": "my-plugin",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/log-bash.sh"
          }
        ]
      }
    ]
  }
}
```

Or as a path to a separate file:

```json
{
  "name": "my-plugin",
  "hooks": "./hooks/hooks.json"
}
```

## Supported Hook Events

Event names are the top-level keys in the hooks configuration object. Each maps to an array of matcher/hooks entries.

| Event | When It Fires | Can Block |
|-------|---------------|-----------|
| `SessionStart` | At session beginning or resume | No |
| `SessionEnd` | When session terminates | No |
| `UserPromptSubmit` | Before Claude processes user input | Yes |
| `PreToolUse` | Before a tool executes | Yes |
| `PostToolUse` | After a tool execution succeeds | No |
| `PostToolUseFailure` | After a tool execution fails | No |
| `PermissionRequest` | During permission dialog | Yes |
| `Notification` | When Claude sends a notification | No |
| `Stop` | When Claude finishes responding | Yes |
| `SubagentStart` | When a subagent is spawned | No |
| `SubagentStop` | When a subagent task completes | Yes |
| `TeammateIdle` | When an agent team teammate is about to go idle | Yes |
| `TaskCompleted` | When a task is being marked complete | Yes |
| `PreCompact` | Before history compression | No |
| `ConfigChange` | When a config file changes mid-session | Yes |
| `WorktreeCreate` | When a worktree is being created | Yes |
| `WorktreeRemove` | When a worktree is being removed | No |

## Configuration Fields

### Matcher Object

Each entry in an event's array is a matcher object:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `matcher` | No | String | Tool name or glob pattern to match (e.g., `"Bash"`, `"Write\|Edit"`, `"*"`). Omit or use `"*"` to match all occurrences. Some events (e.g., `Stop`, `UserPromptSubmit`) do not support matchers. |
| `hooks` | Yes | Array | One or more hook handler objects to execute when the matcher fires |

### Hook Handler Object

Each entry in the `hooks` array is a handler. The `type` field selects one of four handler types:

**`command`** — execute a shell command or script:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `type` | Yes | String | `"command"` |
| `command` | Yes | String | Shell command or script path to execute |
| `async` | No | Boolean | Run asynchronously (default: false) |
| `timeout` | No | Integer | Timeout in seconds (1–600). Default: 600 |
| `statusMessage` | No | String | Message shown while hook runs |
| `once` | No | Boolean | Run only once per session (default: false) |

**`http`** — call an HTTP endpoint:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `type` | Yes | String | `"http"` |
| `url` | Yes | String | URL to POST event data to |
| `headers` | No | Object | HTTP headers to include |
| `allowedEnvVars` | No | String[] | Environment variable names to forward |
| `timeout` | No | Integer | Timeout in seconds (1–600). Default: 600 |

**`prompt`** — run a model prompt:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `type` | Yes | String | `"prompt"` |
| `prompt` | Yes | String | Prompt text to send to the model |
| `model` | No | String | Model to use (defaults to current) |
| `timeout` | No | Integer | Timeout in seconds (1–600). Default: 30 |

**`agent`** — run an agent task:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `type` | Yes | String | `"agent"` |
| `prompt` | Yes | String | Task prompt for the agent |
| `model` | No | String | Model to use |
| `tools` | No | String[] | Tools to make available |
| `timeout` | No | Integer | Timeout in seconds (1–600). Default: 60 |

## Example Configurations

### Logging all Bash commands

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "jq -r '.tool_input.command' >> ~/.claude/bash-log.txt"
        }
      ]
    }
  ]
}
```

### Validating files on write or edit

```json
{
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/hooks/validate-skill-structure.sh",
          "timeout": 10
        }
      ]
    }
  ]
}
```

### Blocking a destructive command

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/hooks/block-rm.sh"
        }
      ]
    }
  ]
}
```

### Multiple hooks on the same event

Multiple entries in the `hooks` array run in parallel. If any exits with code 2, the operation is blocked.

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/hooks/validate.sh"
        },
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/hooks/log.sh"
        }
      ]
    }
  ]
}
```

### Session setup

```json
{
  "SessionStart": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/hooks/setup-env.sh"
        }
      ]
    }
  ]
}
```

## Hook Execution Behavior

### How Command Hooks Communicate

Command hooks receive event JSON via **stdin** and communicate results through:

- **Exit code 0**: Allow operation; Claude Code may optionally parse stdout for a JSON control object
- **Exit code 2**: Block operation — stderr content is shown to Claude as the reason
- **Any other exit code**: Non-blocking error, execution continues

> Choose one approach per hook: either use exit codes alone for signaling, or exit 0 and print JSON for structured control. Claude Code only processes JSON on exit 0. If you exit 2, any JSON output is ignored.

### JSON Control Output (exit 0)

A hook that exits 0 may print a JSON object to stdout to control Claude's behavior:

```json
{
  "decision": "block",
  "reason": "Test suite must pass before proceeding"
}
```

Universal fields available in all events:

| Field | Default | Description |
|-------|---------|-------------|
| `continue` | `true` | If `false`, Claude stops processing entirely |
| `stopReason` | none | Message shown to the user when `continue` is `false` |
| `suppressOutput` | `false` | If `true`, hides stdout from verbose mode output |
| `systemMessage` | none | Warning message shown to the user |

## Environment Variables

Hooks can reference these special environment variables:

- `${CLAUDE_PLUGIN_ROOT}`: Absolute path to the plugin's root directory. Use this to reference scripts bundled with your plugin regardless of working directory.
- `${CLAUDE_PROJECT_DIR}`: Absolute path to the project root (the directory containing `.claude/`). Quote this variable to handle paths with spaces.
- `${CLAUDE_ENV_FILE}`: Available **only in `SessionStart` hooks**. Write `export VAR=value` lines to this file to persist environment variables for all subsequent Bash commands in the session.
- `${CLAUDE_CODE_REMOTE}`: Set to `"true"` in remote web environments. Not set in the local CLI.

### Example Hook Script

```bash
#!/bin/bash
# Hook script demonstrating environment variables

# Reference plugin files
source "${CLAUDE_PLUGIN_ROOT}/lib/helpers.sh"

# Access project context
cd "${CLAUDE_PROJECT_DIR}"

# Log to a stable path
echo "Plugin root: ${CLAUDE_PLUGIN_ROOT}" >> /tmp/plugin-debug.log
echo "Project dir: ${CLAUDE_PROJECT_DIR}" >> /tmp/plugin-debug.log
```

### SessionStart: Persisting Environment Variables

```bash
#!/bin/bash
# Set up project environment at session start
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=development' >> "$CLAUDE_ENV_FILE"
  echo 'export DEBUG=true' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

Use append (`>>`) to preserve variables set by other hooks running in the same event.

## Best Practices

- Keep hook scripts simple and focused on a single concern
- Use `${CLAUDE_PLUGIN_ROOT}` with absolute paths so scripts resolve correctly regardless of working directory
- Set reasonable timeouts — long-running hooks block the user experience
- Test hooks in isolated environments before distribution
- Validate and sanitize all inputs from hook event JSON
- Use `jq` to extract specific fields from the event JSON received on stdin

## Hook Script Requirements

- Must be executable (`chmod +x`)
- Include a proper shebang line (e.g., `#!/bin/bash`)
- Read event data from **stdin** (JSON format)
- Provide meaningful exit codes:
  - `0`: Success / allow operation
  - `2`: Block operation (stderr shown to Claude)
  - Other non-zero: Non-blocking error

## Common Use Cases

- Post-edit validation of file structure or content
- Bash command logging and audit trails
- Blocking destructive operations (e.g., `rm -rf`)
- Environment setup at session start
- Desktop notifications on task completion

## Security Warning

**Hooks execute arbitrary shell commands with your user privileges.**

Risks include:
- File modification or deletion
- Data exfiltration
- Credential access
- Network requests
- System-level changes

**Always review hook scripts carefully before installation.**

### Security Best Practices

1. **Validate and sanitize inputs**
   ```python
   # BAD - vulnerable to injection
   os.system(f"echo {user_input}")

   # GOOD - validated and quoted
   safe_input = re.sub(r'[^a-zA-Z0-9_-]', '', user_input)
   subprocess.run(['echo', safe_input])
   ```

2. **Quote shell variables**
   ```bash
   # BAD: cat $file_path
   # GOOD: cat "$file_path"
   ```

3. **Block path traversal**
   ```python
   if '../' in path or path.startswith('/'):
       sys.exit(2)  # Block
   ```

4. **Use absolute paths**
   ```bash
   # BAD: python script.py
   # GOOD: /usr/bin/python3 "${CLAUDE_PLUGIN_ROOT}/hooks/script.py"
   ```

5. **Never use untrusted hook scripts** — audit all plugin hooks before installation
