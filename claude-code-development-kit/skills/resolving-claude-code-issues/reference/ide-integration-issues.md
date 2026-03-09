# IDE Integration Issues

Troubleshooting JetBrains, VS Code, and other IDE integration problems.

## JetBrains on WSL2

**Problem**: Cannot connect to JetBrains IDE from WSL2

**Solutions**:

1. Configure Windows Firewall to allow connections
2. Or switch WSL networking mode:
```bash
# In .wslconfig
[wsl2]
networkingMode=mirrored
```

## ESC Key Issues in JetBrains

**Problem**: ESC key not working properly in terminal

**Solution**: Adjust terminal keyboard settings:
1. Settings → Tools → Terminal
2. Disable "Override IDE shortcuts"

## VS Code Integration

**Problem**: Claude Code not connecting to VS Code

**Solutions**:
1. Verify VS Code is running
2. Check extension is installed
3. Reload VS Code window
4. Check firewall settings
5. Review VS Code terminal settings

## Markdown Formatting Issues

### Missing Language Tags

**Problem**: Code blocks don't have language tags

**Solution**: Request explicitly:
```
Add proper language tags to all code blocks
```

### Inconsistent Spacing

**Problem**: Markdown has inconsistent spacing/formatting

**Solutions**:
1. Request corrections:
```
Fix markdown formatting inconsistencies
```

2. Use formatting tools:
```bash
npx prettier --write "**/*.md"
```
