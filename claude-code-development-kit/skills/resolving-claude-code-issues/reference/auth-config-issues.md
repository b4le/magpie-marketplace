# Authentication & Configuration Issues

Troubleshooting authentication, API key conflicts, and permission settings.

## Authentication Issues

### Repeated Login Prompts

**Problem**: Asked to login repeatedly

**Solutions**:
1. Clear auth tokens:
```bash
rm ~/.claude/auth.json
```

2. Logout and re-authenticate:
```bash
/logout
# Restart Claude Code
```

3. Check file permissions:
```bash
chmod 600 ~/.claude/auth.json
```

### Cannot Authenticate

**Problem**: Authentication fails or hangs

**Solutions**:
1. Check internet connection
2. Verify firewall isn't blocking authentication
3. Try different browser for OAuth flow
4. Check system time is correct
5. Clear browser cookies for claude.ai
6. Contact support if persistent

## ANTHROPIC_API_KEY Conflicts

**Problem**: Authentication fails or uses wrong account despite logging in

**Cause**: Environment variable `ANTHROPIC_API_KEY` overrides Claude Code authentication

**Diagnosis**:
```bash
# Check if ANTHROPIC_API_KEY is set
echo $ANTHROPIC_API_KEY

# Check shell config files
grep ANTHROPIC_API_KEY ~/.bashrc ~/.zshrc ~/.bash_profile
```

**Solution**:
```bash
# Unset the variable
unset ANTHROPIC_API_KEY

# Remove from shell config files
# Edit ~/.bashrc, ~/.zshrc, etc. and remove:
# export ANTHROPIC_API_KEY=sk-...

# Reload shell config
source ~/.bashrc  # or ~/.zshrc

# Re-authenticate with Claude Code
/logout
# Restart Claude Code and login again
```

**Note**: If you need `ANTHROPIC_API_KEY` for other tools, use project-specific `.env` files instead of shell config.

## Permission Prompts

### Too Many Permission Prompts

**Problem**: Constantly asked for permission approvals

**Solution**: Configure permission mode:

```bash
/permissions
```

Options:
- **Ask (default)**: Prompt for each operation
- **Allow all**: Auto-approve (use carefully!)
- **Custom**: Configure specific permissions

### Permissions Reset

**Problem**: Permission settings reset after restart

**Solution**: Ensure config file is writable:
```bash
chmod 644 ~/.claude/config.json
```
