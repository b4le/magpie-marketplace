---
name: understanding-hooks
description: Comprehensive guide to Claude Code hooks - event-driven automation with shell commands, prompts, and agents. Use when implementing hooks, configuring event handlers, automating workflows, setting up validation, or understanding hook types, events, environment variables, and security.
allowed-tools:
  - Read
  - Edit
  - Write
version: 1.1.0
created: 2026-02-19
last_updated: 2026-03-09
tags:
  - hooks
  - automation
  - event-driven
---

## When to Use This Skill

Use this skill when:
- Implementing hooks or configuring event handlers
- Automating workflows with Claude Code events
- Setting up validation or custom automation
- Understanding hook events, security, and structure

### Do NOT Use This Skill When:
- Creating plugins (use `creating-plugins` for complete plugin guidance, which includes hooks)
- Just using slash commands (use `using-commands` instead)
- Simple automation that doesn't need event-driven behavior (use slash commands)
- Security concerns with hooks (refer to your organization's security practices)

## Prerequisites

### Required
- [ ] Claude Code installed and configured
- [ ] Basic understanding of shell commands (bash, python, etc.)
- [ ] Access to settings files (`~/.claude/settings.json` or `.claude/settings.json`)

### Recommended
- [ ] `jq` installed for JSON processing in hooks
- [ ] Understanding of JSON configuration format
- [ ] Familiarity with your shell environment

## Hook Types

Claude Code supports four hook handler types. All share a common `type` field in the hook configuration.

### command — Run a shell command

The most common type. Receives event JSON via stdin and communicates results through exit codes and stdout.

```json
{
  "type": "command",
  "command": "python3 ~/.claude/hooks/validate.py",
  "timeout": 10
}
```

### prompt — Ask a Claude model

Sends a single-turn prompt to a fast Claude model for yes/no evaluation. No shell execution occurs. Use `$ARGUMENTS` as a placeholder for the hook's JSON input.

```json
{
  "type": "prompt",
  "prompt": "Evaluate if Claude should stop: $ARGUMENTS. Check if all tasks are complete.",
  "timeout": 30
}
```

The model must respond with `{"ok": true}` to allow or `{"ok": false, "reason": "..."}` to block.

### agent — Spawn an agent

Spawns a subagent that can use tools (Read, Grep, Glob) to inspect files and verify conditions before returning a decision. Useful when a yes/no check requires looking at actual file contents or test output, not just the event data.

```json
{
  "type": "agent",
  "prompt": "Verify all unit tests pass before allowing Claude to stop. $ARGUMENTS",
  "timeout": 120
}
```

The agent returns the same `{"ok": true/false}` schema as prompt hooks, after up to 50 turns of tool use.

### http — Send an HTTP POST request

Sends the event JSON as an HTTP POST request to a URL. The endpoint communicates results back through the response body using the same JSON output format as command hooks. Non-2xx responses, connection failures, and timeouts produce non-blocking errors — to block, return a 2xx response with a JSON body containing the appropriate decision fields.

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

### Side-by-side comparison

| | `command` | `http` | `prompt` | `agent` |
|---|---|---|---|---|
| Executes shell | Yes | No | No | No (uses Claude tools) |
| Can read files | Yes (via script) | No | No | Yes (via Read tool) |
| Default timeout | 600s | 600s | 30s | 60s |
| Can block actions | Yes | Yes | Yes | Yes |
| Can run async | Yes | No | No | No |
| Best for | Scripted validation, formatting, logging | External services | Simple LLM-evaluated conditions | Multi-step file inspection |

See @reference/advanced-topics.md for full configuration field details for each type.

## Hook Events Reference

Claude Code provides **19 hook events**:

### Lifecycle Events

| Event | When It Fires | Can Block | Common Use Cases |
|-------|---------------|-----------|------------------|
| **Setup** | During initial setup/configuration phase (v2.1.10) | No | One-time environment prep, dependency checks |
| **SessionStart** | At session beginning or resume | No | Load context, setup logging, persist env vars |
| **InstructionsLoaded** | After CLAUDE.md, skills, and other instructions are loaded (v2.1.69) | No | Audit active instructions, set context based on loaded config |
| **SessionEnd** | When session terminates | No | Cleanup, save state, commit changes |

### User Interaction Events

| Event | When It Fires | Can Block | Common Use Cases |
|-------|---------------|-----------|------------------|
| **UserPromptSubmit** | Before Claude processes input | Yes | Input validation, context injection |
| **Notification** | When Claude sends notification | No | Custom alerts, status updates |

### Tool Events

| Event | When It Fires | Can Block | Common Use Cases |
|-------|---------------|-----------|------------------|
| **PreToolUse** | Before tool executes | Yes | Validation, logging, permissions |
| **PostToolUse** | After tool execution succeeds | No | Formatting, processing, notifications |
| **PostToolUseFailure** | After tool execution fails | No | Error logging, fallback actions |
| **PermissionRequest** | During permission dialog | Yes | Custom permissions, audit logging |

### Agent and Workflow Events

| Event | When It Fires | Can Block | Common Use Cases |
|-------|---------------|-----------|------------------|
| **Stop** | When Claude finishes responding | Yes | Post-processing, completion checks |
| **SubagentStart** | When a subagent is spawned | No | Audit logging, resource tracking |
| **SubagentStop** | When subagent task completes | Yes | Collect results, validation |
| **TeammateIdle** | When an agent team teammate is about to go idle | Yes | Keep teammate active, redistribute work |
| **TaskCompleted** | When a task is being marked complete | Yes | Validate completion criteria |

### Session and Context Events

| Event | When It Fires | Can Block | Common Use Cases |
|-------|---------------|-----------|------------------|
| **PreCompact** | Before history compression | No | Save conversation state |
| **ConfigChange** | When a config file changes mid-session | Yes | Audit config changes |
| **WorktreeCreate** | When a worktree is being created | Yes | Custom worktree setup |
| **WorktreeRemove** | When a worktree is being removed | No | Cleanup on removal |

### Events that do not support matchers

`UserPromptSubmit`, `Stop`, `TeammateIdle`, `TaskCompleted`, `WorktreeCreate`, and `WorktreeRemove` do not support the `matcher` field — they always fire on every occurrence.

## Quick Start Examples

### command hook — Logging Bash Commands

Track all bash commands using a shell command that receives event JSON via stdin:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "jq -r '.tool_input.command' >> ~/.claude/bash-log.txt"
      }]
    }]
  }
}
```

### prompt hook — Validate task completion before stopping

Ask a Claude model to evaluate whether work is complete before allowing Claude to stop:

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "prompt",
        "prompt": "Evaluate if Claude should stop. Context: $ARGUMENTS\n\nCheck if all user-requested tasks are complete. Respond with {\"ok\": true} if done, or {\"ok\": false, \"reason\": \"what still needs doing\"} to continue."
      }]
    }]
  }
}
```

### agent hook — Verify tests pass before stopping

Spawn an agent that can actually run and read test output before deciding:

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "agent",
        "prompt": "Verify that all unit tests pass before allowing Claude to stop. Run the test suite and check the output. $ARGUMENTS",
        "timeout": 120
      }]
    }]
  }
}
```

### Complete Examples

See @examples/hook-examples.md for 5 detailed command hook examples:
- Bash command logging (with jq)
- Auto-formatting (TypeScript/Prettier)
- File protection (.env, package-lock.json)
- Desktop notifications
- Command validation (Python)

## Security Considerations

### CRITICAL WARNING

**Hooks execute arbitrary shell commands with your user privileges.**

**Risks include:**
- File modification or deletion
- Data exfiltration
- Credential access
- Network requests
- System-level changes

### Security Best Practices

1. **Validate and Sanitize Inputs**
   ```python
   # BAD - vulnerable to injection
   os.system(f"echo {user_input}")

   # GOOD - validated and quoted
   safe_input = re.sub(r'[^a-zA-Z0-9_-]', '', user_input)
   subprocess.run(['echo', safe_input])
   ```

2. **Quote Shell Variables**
   ```bash
   # BAD: cat $file_path
   # GOOD: cat "$file_path"
   ```

3. **Block Path Traversal**
   ```python
   if '../' in path or path.startswith('/'):
       sys.exit(2)  # Block
   ```

4. **Use Absolute Paths**
   ```bash
   # BAD: python script.py
   # GOOD: /usr/bin/python3 ~/.claude/hooks/script.py
   ```

5. **Skip Sensitive Files**
   ```python
   PROTECTED = ['.env', '.git/', 'credentials.json']
   if any(p in file_path for p in PROTECTED):
       sys.exit(2)
   ```

6. **Review All Hook Code**
   - Never use untrusted hook scripts
   - Audit plugin hooks before installation
   - Test in isolated environments first

### Disabling Hooks

Temporarily disable all hooks:

```json
{
  "disableAllHooks": true
}
```

## Advanced Topics

### Hook Input Structure

All hook events receive these common fields via stdin JSON:

```json
{
  "session_id": "abc123",
  "transcript_path": "/home/user/.claude/projects/.../transcript.jsonl",
  "cwd": "/home/user/my-project",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "ls -la"
  }
}
```

The `session_id` field provides a unique identifier for the current session. Access it from stdin JSON rather than as a shell environment variable.

**Additional fields added in 2026 (v2.1.69):**

| Field | Type | Description |
|-------|------|-------------|
| `agent_id` | string | Unique identifier of the agent running the hook |
| `agent_type` | string | Type of the agent (e.g., `"general-purpose"`, `"code-reviewer"`) |
| `worktree` | object (optional) | Present when running in a git worktree session; contains worktree path info |

**Event-specific additions:**

- `Stop` and `SubagentStop` — include `last_assistant_message` (string): the last message the assistant produced before stopping (v2.1.47)

### Hook Output

Command and HTTP hooks can return a JSON object to control behavior. There are three kinds of fields:

**Universal fields** (apply to all events):

| Field | Default | Description |
|-------|---------|-------------|
| `continue` | `true` | If `false`, Claude stops processing entirely after the hook runs |
| `stopReason` | none | Message shown to the user when `continue` is `false`. Not shown to Claude |
| `suppressOutput` | `false` | If `true`, hides stdout from verbose mode output |
| `systemMessage` | none | Warning message shown to the user |

**Top-level `decision` and `reason`** — used by `UserPromptSubmit`, `PostToolUse`, `PostToolUseFailure`, `Stop`, `SubagentStop`, and `ConfigChange` to block:

```json
{
  "decision": "block",
  "reason": "Test suite must pass before proceeding"
}
```

**`hookSpecificOutput`** — used by `PreToolUse` and `PermissionRequest` for richer control (allow, deny, or escalate to the user). Requires a `hookEventName` field set to the event name:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Destructive command blocked by hook"
  }
}
```

**`additionalContext`** (v2.1.9) — `PreToolUse` hooks only. A string injected into the model's context alongside the tool call. Use it to add guardrails, reminders, or supplementary information without blocking the action:

```json
{"additionalContext": "Remember: this file is auto-generated, avoid manual edits."}
```

To allow an action, omit `decision` from your JSON, or exit 0 without any JSON at all.

**Exit Codes (command hooks):**
- `0`: Allow operation, optionally parse stdout for JSON control output
- `2`: Block operation — stderr is shown to Claude as the reason
- Any other code: Non-blocking error, execution continues

> You must choose one approach per hook: either use exit codes alone for signaling, or exit 0 and print JSON for structured control. Claude Code only processes JSON on exit 0. If you exit 2, any JSON is ignored.

### Stopping Teammates via TeammateIdle / TaskCompleted (v2.1.69)

`TeammateIdle` and `TaskCompleted` hooks can return `continue: false` to stop the teammate immediately, rather than just blocking or allowing the default action:

```json
{"continue": false, "stopReason": "Task limit reached"}
```

When `continue` is `false`, the teammate is stopped and `stopReason` is shown to the user. Use this to enforce session budgets or task limits on team agents.

### Chaining Hooks

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "hook1.sh"},
          {"type": "command", "command": "hook2.py"}
        ]
      }
    ]
  }
}
```

Hooks within a matcher run in parallel. If any exits with code 2, the operation is blocked.

### Hook Environment Variables

Claude Code sets specific environment variables that hooks can use for reliable path resolution.

#### `$CLAUDE_PLUGIN_ROOT`

The absolute path to the plugin's root directory. Use this in plugin hooks to reference scripts bundled with the plugin, regardless of the working directory where Claude is invoked.

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/validate-skill-structure.sh"
      }]
    }]
  }
}
```

This is the pattern used in this plugin's `hooks/hooks.json`. The script reads the file path from stdin JSON via `jq -r '.tool_input.file_path'`.

#### `$CLAUDE_PROJECT_DIR`

The absolute path to the project root (the directory containing `.claude/`). Use this in project-scoped hooks to run scripts from `.claude/hooks/` regardless of cwd. Quote the variable to handle paths with spaces.

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

#### `$CLAUDE_ENV_FILE` (SessionStart only)

Available only in `SessionStart` hooks. Write `export VAR=value` lines to this file to persist environment variables for all subsequent Bash commands in the session.

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

#### `$CLAUDE_CODE_REMOTE`

Set to `"true"` in remote web environments. Not set in the local CLI. Use this to conditionally adjust hook behavior:

```bash
#!/bin/bash
if [ "$CLAUDE_CODE_REMOTE" = "true" ]; then
  # Skip desktop notifications in remote environments
  exit 0
fi
notify-send "Claude Code" "Task complete"
```

### More Advanced Topics

See @reference/advanced-topics.md for:
- Full hook type configuration fields
- MCP tool integration
- Conditional execution
- State management
- Performance optimization
- Integration patterns (CI/CD, monitoring)
- Testing hooks

## Related Documentation

- **Plugins**: How hooks integrate with plugins
- **Settings**: Full settings.json reference
- **Slash Commands**: `/hooks` command for configuration
- **Subagents**: Using SubagentStop hook
- **Security**: IAM and access control
