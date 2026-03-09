# Hook Implementation Examples

Detailed, real-world examples of implementing Claude Code hooks for the primary hook handler types.

## 1. Logging Shell Commands

**Goal**: Track all bash commands executed by Claude Code

**Configuration**:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '\"\\(.tool_input.command) - \\(.tool_input.description // \\\"No description\\\")\"' >> ~/.claude/bash-command-log.txt"
          }
        ]
      }
    ]
  }
}
```

**Prerequisites**: Install `jq` (`brew install jq` on macOS)

**Result**: All bash commands logged to `~/.claude/bash-command-log.txt`

---

## 2. Automatic Code Formatting

**Goal**: Auto-format TypeScript files when written/edited

**Configuration**:
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

**Prerequisites**: Prettier installed in project (`npm install --save-dev prettier`)

**Result**: All `.ts` files automatically formatted on save

---

## 3. File Protection

**Goal**: Block edits to sensitive files (`.env`, `package-lock.json`, `.git/`)

**Configuration**:
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

**Result**: Edits to protected files are blocked (hook exits with code 2)

---

## 4. Desktop Notifications

**Goal**: Get notified when Claude Code awaits input

**Configuration**:
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

**Prerequisites**: `notify-send` (Linux) or equivalent (`terminal-notifier` on macOS)

**Result**: Desktop notification when Claude needs input

---

## 5. Command Validation (Python)

**Goal**: Validate bash commands against best practices

**Hook Script** (`~/.claude/hooks/validate_bash.py`):
```python
#!/usr/bin/env python3
import json
import re
import sys

VALIDATION_RULES = [
    (
        r"\bgrep\b(?!.*\|)",
        "Use 'rg' (ripgrep) instead of 'grep' for better performance"
    ),
    (
        r"rm\s+-rf\s+/",
        "DANGER: Recursive delete from root - blocked"
    )
]

def validate_command(command: str) -> list[str]:
    issues = []
    for pattern, message in VALIDATION_RULES:
        if re.search(pattern, command):
            issues.append(message)
    return issues

# Read hook input
data = json.load(sys.stdin)
command = data.get('tool_input', {}).get('command', '')

# Validate
issues = validate_command(command)
if issues:
    print("\n".join(issues), file=sys.stderr)
    sys.exit(2)  # Block execution

sys.exit(0)  # Allow execution
```

**Configuration**:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/validate_bash.py"
          }
        ]
      }
    ]
  }
}
```

**Result**: Bash commands validated before execution, dangerous commands blocked

---

## 6. Prompt Hook — Task Completion Gate

**Goal**: Prevent Claude from stopping until a Claude model confirms all tasks are complete

**Configuration**:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "You are reviewing whether Claude Code has completed all requested tasks.\n\nContext: $ARGUMENTS\n\nExamine the conversation transcript and determine:\n1. Were all user-requested tasks completed?\n2. Are there any errors that need addressing?\n3. Is there any follow-up work mentioned but not done?\n\nRespond with JSON only:\n- {\"ok\": true} if all tasks are complete\n- {\"ok\": false, \"reason\": \"describe what still needs to be done\"} if not",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**How it works**:
- When Claude attempts to stop, this prompt is sent to a fast Claude model
- The model evaluates the transcript context (provided as `$ARGUMENTS`)
- If `"ok": false`, Claude receives the `reason` and continues working
- No shell execution required

**Result**: Claude cannot stop until a second model confirms work is complete

---

## 7. Agent Hook — Verify Tests Pass Before Stopping

**Goal**: Run the test suite and inspect output before allowing Claude to finish

**Configuration**:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Before allowing Claude to stop, verify that the test suite passes.\n\nContext: $ARGUMENTS\n\n1. Find the test configuration (package.json, pytest.ini, Makefile, etc.)\n2. Identify the test command\n3. Run the tests using the Bash tool\n4. Read the output\n\nRespond with:\n- {\"ok\": true} if all tests pass\n- {\"ok\": false, \"reason\": \"X tests failing: [summary]\"} if any fail",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

**How it works**:
- A subagent is spawned with access to Read, Bash, Grep, and Glob tools
- The agent discovers and runs the project's test command
- After up to 50 turns, it returns a structured decision
- The `timeout` (120 seconds) gives the test suite time to complete

**Prerequisites**: Test runner installed in project (Jest, pytest, etc.)

**Result**: Claude cannot mark work complete until tests actually pass — verified by running them, not just by asking Claude to check

---

## 8. command hook — Prompt Injection via UserPromptSubmit

**Goal**: Inject project context into every user prompt automatically at session

**Hook Script** (`~/.claude/hooks/inject-context.py`):
```python
#!/usr/bin/env python3
import json
import sys
import os
from pathlib import Path

data = json.load(sys.stdin)

# Look for a context file in the project
cwd = data.get('cwd', '')
context_file = Path(cwd) / '.claude' / 'context.md'

if context_file.exists():
    context = context_file.read_text()
    # stdout is added as context Claude can see (for UserPromptSubmit)
    print(f"Project context:\n{context}")

sys.exit(0)
```

**Configuration**:
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/inject-context.py"
          }
        ]
      }
    ]
  }
}
```

**How it works**:
- `UserPromptSubmit` fires before Claude processes each prompt
- stdout from the hook is added as context Claude can read
- Place project-specific context in `.claude/context.md`

**Result**: Claude receives up-to-date project context with every prompt, without you having to repeat it
