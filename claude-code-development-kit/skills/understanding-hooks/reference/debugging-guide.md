# Debugging Claude Code Hooks

Comprehensive guide to troubleshooting and debugging hook configurations.

## Enable Debug Mode

Run Claude Code with debug flag:
```bash
claude --debug
```

## Debug Output

Debug mode shows:
- Hook execution timing
- Hook command and arguments
- Exit codes and errors
- Hook input/output data
- Matcher evaluation results

## Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| Hook doesn't fire | Matcher doesn't match tool | Check matcher pattern, use `""` for all tools |
| Hook times out | Command runs too long | Increase `timeout` in config or optimize command |
| Permission denied | Script not executable | Run `chmod +x script.sh` |
| Command not found | PATH not set correctly | Use absolute paths in commands |
| JSON parsing error | Invalid hook JSON syntax | Validate JSON with `yamllint` or `jq` |
| Wrong tool matched | Matcher pattern too broad | Use specific tool names (e.g., `"Bash"` not `""`) |
| Hook blocks incorrectly | Exit code logic error | Verify exit codes: 0=success, 2=blocking error, other=non-blocking error |
| Input data missing | Accessing wrong JSON path | Check `tool_input` structure with debug mode |

## Testing Hooks Manually

Test hook commands outside of Claude Code:

```bash
# Simulate hook input
echo '{"tool_input":{"file_path":"test.ts","command":"ls -la"}}' | python3 ~/.claude/hooks/my_hook.py

# Check exit code
echo $?  # 0=success, 2=block
```

## Debugging PreToolUse Hooks

```bash
# Create test input
cat > /tmp/test_input.json <<EOF
{
  "tool_name": "Bash",
  "hook_event_name": "PreToolUse",
  "tool_input": {
    "command": "ls -la",
    "description": "List files"
  }
}
EOF

# Test hook
cat /tmp/test_input.json | python3 ~/.claude/hooks/validate_bash.py
```

## Debugging PostToolUse Hooks

```bash
# Test with file path
echo '{"tool_input":{"file_path":"/path/to/test.ts"}}' | \
  jq -r '.tool_input.file_path' | \
  { read file_path; echo "Processing: $file_path"; }
```

## Logging Hook Activity

Add logging to hook scripts:

```python
#!/usr/bin/env python3
import json
import sys
from datetime import datetime

# Log to file
with open('/tmp/hook_debug.log', 'a') as f:
    f.write(f"{datetime.now()}: Hook started\n")
    data = json.load(sys.stdin)
    f.write(f"  Input: {json.dumps(data)}\n")

    # Your hook logic here
    result = process(data)

    f.write(f"  Result: {result}\n")
    f.write(f"  Exit code: {exit_code}\n")

sys.exit(exit_code)
```

## Checking Hook Configuration

Verify hooks are loaded:

```bash
# Check settings file syntax
jq '.' ~/.claude/settings.json

# Check specific hook configuration
jq '.hooks.PreToolUse' ~/.claude/settings.json
```

## Testing Matcher Patterns

```bash
# Test regex patterns
echo "Edit" | grep -E "Edit|Write"  # Should match
echo "Read" | grep -E "Edit|Write"  # Should NOT match
```

## Troubleshooting Plugin Hooks

```bash
# Verify plugin root path
echo $CLAUDE_PLUGIN_ROOT

# Check plugin hooks file
cat ~/.claude/plugins/my-plugin/hooks/hooks.json | jq '.'

# Test plugin hook script
~/.claude/plugins/my-plugin/scripts/my-hook.sh
```

## Performance Debugging

Check hook execution time:

```bash
# Add timing to hook
time python3 ~/.claude/hooks/my_hook.py < test_input.json

# Optimize slow hooks
# - Reduce external command calls
# - Cache repeated operations
# - Use compiled binaries instead of interpreted scripts
```

## Security Debugging

Test hook with malicious input:

```bash
# Test path traversal protection
echo '{"tool_input":{"file_path":"../../etc/passwd"}}' | \
  python3 ~/.claude/hooks/validate_path.py

# Test command injection protection
echo '{"tool_input":{"command":"ls; rm -rf /"}}' | \
  python3 ~/.claude/hooks/validate_bash.py
```

## Common Patterns

### Silent Failure Pattern
Hook exits 0 but doesn't do what you expect:
- Add logging to verify hook is executed
- Check command output redirection
- Verify file paths are correct

### Permission Issues
Hook can't write to log files or execute scripts:
- Check file ownership: `ls -la ~/.claude/hooks/`
- Fix permissions: `chmod 755 ~/.claude/hooks/`
- Check directory permissions

### Environment Issues
Hook works in terminal but not in Claude Code:
- Claude Code may have different PATH
- Use absolute paths for all commands
- Set environment variables explicitly in hook

## Advanced Debugging

### Trace Hook Execution

```bash
# Enable shell tracing
bash -x ~/.claude/hooks/my_hook.sh

# Python tracing
python3 -m trace -t ~/.claude/hooks/my_hook.py
```

### Network Debugging

For hooks that make network requests:

```bash
# Test with curl
curl -v https://api.example.com/hook

# Check network access
nc -zv api.example.com 443
```

## Getting Help

If debugging doesn't resolve your issue:

1. Check hook logs: `~/.claude/hooks.log` (if configured)
2. Review Claude Code debug output: `claude --debug`
3. Validate JSON syntax: `jq '.' settings.json`
4. Test hook script standalone
5. Consult hooks documentation
6. Check for known issues in Claude Code releases
