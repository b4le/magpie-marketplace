# Troubleshooting

## Command Not Found

1. **Check location**: Is the .md file in `.claude/commands/` or `~/.claude/commands/`?
2. **Check filename**: Should be `command-name.md`
3. **Restart**: Try restarting Claude Code
4. **Verify permissions**: Ensure file is readable

## Arguments Not Expanding

1. **Check syntax**: Use `$1`, `$2`, `$ARGUMENTS` (not `{1}`, `%1`, etc.)
2. **Provide arguments**: Some placeholders require arguments when invoking
3. **Quote complex arguments**: Use quotes for multi-word arguments

## File References Not Working

1. **Check path**: Use relative paths from working directory or absolute paths
2. **File exists**: Verify the referenced file exists
3. **Permissions**: Ensure file is readable
4. **Use @ prefix**: Must start with `@` symbol

## Bash Commands Not Executing

1. **Check syntax**: Must be in code fence with `bash` language
2. **Command available**: Verify command exists in PATH
3. **Permissions**: Ensure command has execute permissions
4. **Working directory**: Commands run from current working directory

## YAML Frontmatter Errors

Common errors:
- Missing closing `---`
- Unescaped special characters
- Invalid YAML syntax
- Incorrect indentation in arrays/objects

Validate with `yamllint` or online YAML validator.
