# Memory System Issues

Troubleshooting CLAUDE.md files, memory hierarchy, and file imports.

## Memory Not Loading

**Problem**: Changes to CLAUDE.md not reflected

**Solutions**:
1. Restart Claude Code
2. Check file location:
```bash
ls ./CLAUDE.md
ls ./.claude/CLAUDE.md
ls ~/.claude/CLAUDE.md
```

3. Verify filename is exactly `CLAUDE.md`
4. Check file permissions
5. Look for syntax errors

## Memory Hierarchy Confusion

**Problem**: Wrong memory taking precedence

**Remember hierarchy** (highest to lowest):
1. Enterprise policy
2. Project memory (./CLAUDE.md or ./.claude/CLAUDE.md)
3. User memory (~/.claude/CLAUDE.md)

Higher priority overrides lower.

## File Imports Not Working

**Problem**: @file imports in memory not loading

**Solutions**:
1. Verify file exists
2. Check relative path from CLAUDE.md location
3. Limit import depth (max 5 hops)
4. Ensure files are readable
5. Check @ syntax
