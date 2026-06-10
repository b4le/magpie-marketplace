# Plugin Troubleshooting Guide

## Plugin Not Loading

**Problem**: Plugin installed but components not available

**Symptoms**:
- Commands don't appear
- Skills not invoked
- Hooks don't trigger

**Solutions**:

1. **Verify plugin.json is valid JSON**
   ```bash
   cat .claude-plugin/plugin.json | jq .
   ```

2. **Check plugin directory structure**
   ```bash
   ls -la .claude-plugin/
   ls -la commands/
   ls -la skills/
   ```

3. **Restart Claude Code**
   - Exit and restart the application
   - Plugins load at startup

4. **Reinstall plugin**
   ```bash
   /plugin uninstall <n>
   /plugin install <n>@<marketplace>
   ```

5. **Check for naming conflicts**
   - Verify no other plugin uses same name
   - Check namespace collisions

## Commands Not Appearing

**Problem**: Plugin commands not showing up

**Symptoms**:
- `/plugin:command` returns "command not found"
- Commands missing from autocomplete

**Solutions**:

1. **Verify .md files in commands/ directory**
   ```bash
   ls -la commands/
   ```

2. **Check frontmatter syntax**
   ```markdown
   ---
   description: Command description
   argument-hint: [arg-name]
   ---
   ```

3. **Ensure files are readable**
   ```bash
   chmod 644 commands/*.md
   ```

4. **Check namespace properly**
   - Avoid conflicts with built-in commands
   - Use subdirectories for organization

## Skills Not Invoked

**Problem**: Plugin skills not being used

**Symptoms**:
- Skills don't appear in skill list
- Claude doesn't invoke skill when appropriate

**Solutions**:

1. **Check SKILL.md YAML frontmatter**
   ```yaml
   ---
   name: skill-name
   description: When to use this skill
   ---
   ```

2. **Verify description is specific and clear**
   - Describe WHEN to use the skill
   - Include trigger phrases

3. **Ensure SKILL.md in correct directory**
   ```
   skills/
   └── skill-name/
       └── SKILL.md
   ```

4. **Test skill directly**
   ```bash
   /skill skill-name
   ```

## Hooks Not Triggering

**Problem**: Hooks not executing

**Symptoms**:
- Pre-commit doesn't run
- Hook events ignored

**Solutions**:

1. **Verify execute permissions**
   ```bash
   chmod +x hooks/*.sh
   ```

2. **Check shebang line**
   ```bash
   #!/bin/bash
   ```
   Must be first line of script

3. **Test hook manually**
   ```bash
   ./hooks/pre-commit.sh
   echo $?  # Should be 0 for success
   ```

4. **Check hook exit codes**
   - Exit 0 for success
   - Exit non-zero to block operation

5. **Verify hooks.json configuration**
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-commit.sh"
             }
           ]
         }
       ]
     }
   }
   ```

## Version Conflicts

**Problem**: Plugin version incompatibility

**Symptoms**:
- "Version not compatible" error
- Features missing
- Unexpected behavior

**Solutions**:

1. **Update plugin**
   ```bash
   /plugin update <n>
   ```

2. **Update Claude Code**
   - Check for Claude Code updates
   - Install latest version

4. **Contact plugin author**
   - Report compatibility issue
   - Request updated version

## Validation Errors

**Problem**: Plugin validation fails

**Common Errors**:

| Error | Cause | Fix |
|-------|-------|-----|
| Missing required field "version" | plugin.json incomplete | Add version field |
| Invalid YAML frontmatter | Syntax error in SKILL.md | Fix YAML syntax |
| Hook script not found | Path incorrect | Verify script location |
| Invalid hook configuration | Missing required field | Add required `type` and `command` fields to handler object |

**Validation Command**:
```bash
claude plugin validate /path/to/plugin
```

**Fix validation errors before publishing.**

## Installation Failures

**Problem**: Plugin fails to install

**Solutions**:

1. **Check marketplace accessibility**
   ```bash
   /plugin marketplace list
   ```

2. **Verify plugin name and marketplace**
   ```bash
   /plugin install correct-name@correct-marketplace
   ```

3. **Check dependency conflicts**
   - Review plugin.json dependencies
   - Ensure compatible versions

4. **Check disk space**
   ```bash
   df -h ~/.claude/plugins
   ```

## Configuration Issues

**Problem**: Plugin settings not working

**Solutions**:

1. **Verify environment variables set**
   ```bash
   echo $API_ENDPOINT
   ```

2. **Check .claude/settings.json**
   ```json
   {
     "enabledPlugins": ["my-plugin"]
   }
   ```

3. **Validate config in plugin.json**
   ```json
   {
     "config": {
       "apiEndpoint": "${API_ENDPOINT}"
     }
   }
   ```

## Debug Checklist

Use this checklist when troubleshooting:

- [ ] Plugin appears in `/plugin list`
- [ ] Plugin enabled in settings.json
- [ ] plugin.json is valid JSON
- [ ] Commands have .md extension
- [ ] Skills have SKILL.md in subdirectory
- [ ] Hooks have execute permissions
- [ ] Dependencies installed
- [ ] No naming conflicts
- [ ] Restarted Claude Code
- [ ] Validated with `claude plugin validate`

## Getting Help

If issues persist:

1. **Check plugin documentation**
   - README.md
   - GitHub issues

2. **Validate plugin structure**
   ```bash
   claude plugin validate /path/to/plugin
   ```

3. **Review plugin logs**
   - Check Claude Code logs for errors

4. **Contact plugin author**
   - Report issue with details
   - Include error messages

5. **Check Claude Code documentation**
   - Official plugin guide
   - Community forums