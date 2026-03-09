# Slash Command Issues

Troubleshooting custom slash commands, arguments, and file references.

## Command Not Found

**Problem**: Custom slash command not working

**Diagnostics**:
```bash
# Check file exists
ls .claude/commands/my-command.md
ls ~/.claude/commands/my-command.md

# Check file permissions
ls -l .claude/commands/my-command.md
```

**Solutions**:
1. Verify file location
2. Check filename (must be .md)
3. Ensure readable permissions
4. Restart Claude Code
5. Check for naming conflicts

## Arguments Not Expanding

**Problem**: $1, $2, $ARGUMENTS not replaced

**Solutions**:
1. Check syntax: `$1` not `{1}` or `%1`
2. Provide arguments when invoking
3. Verify frontmatter is correct
4. Test with simple command first

## File References Not Working

**Problem**: @file references not loading

**Solutions**:
1. Verify file exists
2. Check path (relative to working directory)
3. Use absolute paths if needed
4. Ensure file is readable
5. Check @ syntax: `@path/to/file`

## Bash Commands Not Executing

**Problem**: Bash commands in command file don't run

**Solutions**:
1. Verify code fence syntax:
```markdown
\`\`\`bash
echo "test"
\`\`\`
```

2. Check command is in PATH
3. Verify permissions
4. Test command separately
