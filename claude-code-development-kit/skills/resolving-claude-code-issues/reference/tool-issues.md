# Tool Issues

Comprehensive troubleshooting for Claude Code tools: Read, Edit, Write, Glob, Grep, and Bash.

## Read Tool Failures

**Problem**: Cannot read file

**Diagnostics**:
```bash
# Check file exists
ls -la path/to/file

# Check permissions
ls -l path/to/file

# Verify path is absolute
pwd
```

**Solutions**:
1. Use absolute path, not relative
2. Check file permissions (must be readable)
3. Verify file exists
4. Check for special characters in path

## Edit Tool Failures

### "old_string not found"

**Problem**: Edit fails with "old_string not found"

**Solutions**:
1. Provide more context in old_string
2. Check for exact whitespace/indentation
3. Use replace_all if multiple occurrences
4. Verify reading file first (required)

### "old_string not unique"

**Problem**: Edit fails with "old_string not unique"

**Solutions**:
1. Include more surrounding code
2. Make the match unique
3. Use replace_all to change all instances

## Glob Tool Issues

**Problem**: Glob pattern not finding files

**Solutions**:
1. Check pattern syntax:
```
"**/*.js" - all JS files recursively
"src/**/*.tsx" - TSX files in src
"*.json" - JSON files in current dir
```

2. Verify path parameter
3. Check file permissions
4. Ensure files exist

## Grep Tool Issues

### Not Finding Expected Matches

**Problem**: Grep not finding expected matches

**Solutions**:
1. Check regex syntax (ripgrep syntax, not grep)
2. Use -i for case-insensitive
3. Check glob filter is correct
4. Verify path parameter
5. For literal braces: `interface\\{\\}`

### Too Many Results

**Problem**: Too many results

**Solutions**:
1. Make pattern more specific
2. Use glob to filter file types
3. Use type parameter for standard file types
4. Use head_limit to limit results

### Ripgrep Not Installed

**Problem**: Grep tool fails with "ripgrep not found"

**Cause**: The Grep tool uses ripgrep (rg) which may not be installed

**Installation**:

```bash
# macOS
brew install ripgrep

# Ubuntu/Debian
sudo apt-get install ripgrep

# Fedora
sudo dnf install ripgrep

# Arch Linux
sudo pacman -S ripgrep

# Windows (with Chocolatey)
choco install ripgrep

# Windows (with Scoop)
scoop install ripgrep

# Verify installation
rg --version
```

**Alternative**: Use Bash tool with grep command (less performant):
```bash
grep -r "pattern" .
```

## Bash Tool Issues

### Command Not Found

**Problem**: Command not found

**Solutions**:
1. Check command is in PATH:
```bash
which command-name
```

2. Install missing command
3. Use absolute path
4. Check spelling

### Permission Denied

**Problem**: Permission denied

**Solutions**:
1. Check file permissions
2. Add execute permission:
```bash
chmod +x script.sh
```

3. Run with appropriate user
4. Check directory permissions

### Command Times Out

**Problem**: Command times out

**Solutions**:
1. Increase timeout parameter
2. Run in background
3. Optimize command
4. Check for hangs/deadlocks
