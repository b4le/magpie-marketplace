# Plugin Issues

Troubleshooting plugin loading, commands, and version conflicts.

## Plugin Not Loading

**Problem**: Installed plugin not available

**Solutions**:
1. Verify installation:
```bash
/plugin list
```

2. Check plugin directory structure
3. Verify plugin.json is valid
4. Restart Claude Code
5. Reinstall:
```bash
/plugin uninstall my-plugin
/plugin install my-plugin@marketplace
```

## Plugin Commands Not Available

**Problem**: Plugin commands don't appear

**Solutions**:
1. Verify .md files in commands/
2. Check frontmatter syntax
3. Ensure files readable
4. Look for namespace conflicts
5. Restart Claude Code

## Plugin Version Conflicts

**Problem**: Plugin incompatible with Claude Code version

**Solutions**:
1. Update plugin:
```bash
/plugin update my-plugin
```

2. Update Claude Code:
```bash
claude update
```

3. Check engines in plugin.json
4. Contact plugin author
