# Claude Code Plugin Hook Configurations

## Overview

Hooks in Claude Code plugins provide powerful mechanisms for extending and customizing behavior during various stages of plugin and project interactions.

## Security Warning

⚠️ **IMPORTANT**: Hooks execute arbitrary code on your system. Only use hooks from trusted sources.

## Example Hook Scripts

### 1. Pre-Commit Hook

```bash
#!/bin/bash
# File: hooks/pre-commit.sh

# Run linters
echo "Running linters..."
npm run lint

# Run tests
echo "Running tests..."
npm test

# Prevent commit if tests or linting fail
if [ $? -ne 0 ]; then
  echo "Pre-commit checks failed. Fix errors before committing."
  exit 1
fi
```

### 2. Post-Edit Hook

```bash
#!/bin/bash
# File: hooks/post-edit.sh

# Log file edits
echo "File edited: $CLAUDE_EDITED_FILE"

# Optional: Trigger additional actions
if [[ "$CLAUDE_EDITED_FILE" == *.js ]]; then
  echo "JavaScript file edited. Running type checks..."
  npx tsc --noEmit
fi
```

### 3. Pre-Push Hook

```bash
#!/bin/bash
# File: hooks/pre-push.sh

# Run comprehensive test suite
echo "Running pre-push checks..."
npm run test:ci
npm run build

# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
  echo "Uncommitted changes detected. Please commit or stash changes."
  exit 1
fi
```

## Hook Configuration File

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-commit.sh",
            "timeout": 60
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/post-edit.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate-prompt.js"
          }
        ]
      }
    ]
  }
}
```

## Environment Variables

- `${CLAUDE_PLUGIN_ROOT}`: Plugin installation directory
- `${CLAUDE_PROJECT_DIR}`: Current working project directory
- `${CLAUDE_EDITED_FILE}`: Path of recently edited file (in post-edit hooks)

## Best Practices

1. Keep hooks lightweight and fast
2. Use absolute paths
3. Handle errors gracefully
4. Log important events
5. Set reasonable timeouts
6. Make hooks executable: `chmod +x hooks/*.sh`

## Configuration Options

Each event key maps to an array of matcher/hooks entry objects:

| Field     | Type    | Description                                              | Required |
|-----------|---------|----------------------------------------------------------|----------|
| `matcher` | String  | Tool name or glob pattern (e.g., `"Bash"`, `"Write\|Edit"`). Omit to match all. | No |
| `hooks`   | Array   | Array of handler objects to execute                      | Yes      |

Each handler object in the `hooks` array has a `type` field selecting one of four handler types: `command`, `http`, `prompt`, or `agent`. For `command` handlers:

| Field     | Type    | Description                                  | Default  |
|-----------|---------|----------------------------------------------|----------|
| `type`    | String  | `"command"`                                  | Required |
| `command` | String  | Shell command or script path to execute      | Required |
| `timeout` | Number  | Maximum execution time in seconds (1–600)    | 600      |
| `async`   | Boolean | Run hook asynchronously                      | false    |

## Example Complex Hook

```bash
#!/bin/bash
# Advanced pre-commit validation

# Check code quality
npm run lint
npm run typecheck

# Run tests with coverage
npm run test:coverage

# Block commit if coverage below threshold
COVERAGE=$(npm run test:coverage:report)
if (( $(echo "$COVERAGE < 80" | bc -l) )); then
  echo "Code coverage below 80%. Commit blocked."
  exit 1
fi

# Security scan
npm audit

# Prevent commits to protected branches
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" == "main" || "$BRANCH" == "production" ]]; then
  echo "Direct commits to $BRANCH are not allowed."
  exit 1
fi
```

## Troubleshooting

- Verify hook script permissions
- Check shebang lines
- Test hooks manually
- Review error logs
- Ensure dependencies are installed