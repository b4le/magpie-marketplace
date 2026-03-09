# Debugging Techniques

Advanced diagnostic strategies, log analysis, and issue isolation methods.

## Using /doctor

```bash
/doctor
```

Checks:
- Installation health
- Configuration issues
- Common problems
- System compatibility

### Known Issue: /doctor Hangs (v1.0.95-1.0.96)

**Versions affected**: v1.0.95, v1.0.96

**Problem**: `/doctor` command hangs indefinitely

**Workaround**:
```bash
# Use verbose mode instead
claude --version
claude --verbose "test"

# Or update to newer version
claude update
```

**Fix**: Fixed in v1.0.97+. Update Claude Code if on affected version.

## Checking Logs

**Location varies by OS**:
```bash
# macOS
~/Library/Logs/Claude/

# Linux
~/.local/share/claude/logs/

# Windows
%APPDATA%\Claude\logs\
```

View recent logs:
```bash
tail -f ~/Library/Logs/Claude/main.log
```

## Verbose Mode

```bash
claude --verbose "your query"
```

Shows detailed operation logs.

## Isolating Issues

### Test in Clean Environment

```bash
# Temporarily rename config
mv ~/.claude ~/.claude.backup
# Test issue
# Restore
mv ~/.claude.backup ~/.claude
```

### Minimal Reproduction

1. Remove plugins
2. Clear memory files
3. Test with simple command
4. Add complexity incrementally

### Check Recent Changes

- What changed before issue started?
- New plugins installed?
- Config modifications?
- System updates?

## Systematic Diagnosis Process

1. **Identify the symptom**
   - What exactly is failing?
   - When did it start?
   - Is it consistent or intermittent?

2. **Gather information**
   - Run `/doctor`
   - Check logs
   - Review recent changes
   - Note error messages

3. **Isolate the cause**
   - Test in clean environment
   - Disable plugins one by one
   - Remove custom configurations
   - Test with minimal setup

4. **Test solutions**
   - Try one fix at a time
   - Document what you changed
   - Verify fix resolves issue
   - Check for side effects

5. **Prevent recurrence**
   - Document the solution
   - Update configurations
   - Add monitoring if needed
   - Share findings with team
