---
name: resolving-claude-code-issues
description: "Comprehensive troubleshooting guide for Claude Code installation, authentication, performance, tools, skills, and MCP issues. Use when diagnosing problems, fixing errors, resolving installation failures, debugging tools, or investigating performance issues. Covers common error messages, diagnostic commands, and prevention strategies."
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
version: 1.0.0
created: 2025-11-20
last_updated: 2026-02-28
tags:
  - troubleshooting
  - debugging
  - issues
---

**Skill Type**: User-level
**Created**: 2025-11-18
**Source**: Migrated from `best-practices-reference/troubleshooting-guide.md`
**Version**: 1.0.0

## When to Use This Skill

Use this skill when:
- Diagnosing problems with Claude Code installation or authentication
- Fixing errors or resolving installation failures
- Debugging tool issues (Edit tool "old_string not found", etc.)
- Investigating performance issues
- Troubleshooting skills, commands, or MCP connections
- Understanding common error messages

### Do NOT Use This Skill When:
- No actual problem exists — do not invoke for preventative troubleshooting
- Issue is with code/project, not Claude Code itself — use standard debugging
- MCP-specific issues with configuration — use `integrating-mcps` first

---

## Diagnostic Quick Reference

Run these first to establish baseline state before diving into specific issues.

```bash
# Confirm Claude Code is installed and check version
claude --version

# Run built-in health check
/doctor

# List current configuration
claude config list

# Check for recent error logs
ls -lt ~/.claude/logs/ | head -20
cat ~/.claude/logs/$(ls -t ~/.claude/logs/ | head -1)
```

---

## Top 5 Issues: Inline Fixes

### 1. Edit Tool — "old_string not found"

**Cause**: The string provided does not exactly match the file content, including whitespace and indentation.

**Fix**:
1. Read the file immediately before editing — this is required, not optional
2. Copy the target string directly from the Read output, including all leading whitespace
3. Include 2-3 lines of surrounding context to make the match unique
4. If the string appears multiple times, use `replace_all: true` or add more context

```
# Pattern that works
old_string: "    const result = compute(\n      input\n    );"

# Pattern that fails (wrong indentation)
old_string: "const result = compute(input);"
```

See @skills/resolving-claude-code-issues/reference/tool-issues.md for full tool diagnostics.

---

### 2. Permission / Sandbox Errors

**Cause**: Claude Code's sandbox restricts certain file operations or commands. Common when running scripts, writing to system paths, or running tests that touch the build cache.

**Fix**:
1. Check the permission mode: `/permissions`
2. For Bash operations blocked by sandbox, verify the `dangerouslyDisableSandbox` option is explicitly set when needed (e.g., Go build cache, test runners)
3. Never use `sudo npm install -g` — fix npm permissions instead:

```bash
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
# Add to ~/.zshrc or ~/.bashrc:
export PATH=~/.npm-global/bin:$PATH
```

4. If permissions reset after restart, make the config file writable:

```bash
chmod 644 ~/.claude/config.json
```

See @skills/resolving-claude-code-issues/reference/auth-config-issues.md and @skills/resolving-claude-code-issues/reference/installation-issues.md.

---

### 3. MCP Connection Failures

**Cause**: Server not running, wrong URL, expired OAuth token, or firewall blocking the connection.

**Diagnosis**:
```bash
# Check if the MCP server process is running
ps aux | grep mcp

# Test HTTP server reachability
curl https://api.example.com/mcp

# Inspect config
cat .claude/mcp.json
```

**Fix**:
1. Confirm the server is running before connecting
2. Re-authenticate via `/mcp` to refresh OAuth tokens
3. To clear stored tokens and force re-auth:
```bash
rm ~/.claude/mcp-tokens.json
```
4. If a background subagent needs MCP access, run with `run_in_background: false` — background agents cannot access MCP tools

See @skills/resolving-claude-code-issues/reference/mcp-issues.md.

---

### 4. Skill Not Found / Not Loading

**Cause**: Misconfigured YAML frontmatter, incorrect file location, or a description too vague for automatic invocation.

**Fix**:
1. Confirm the skill file is in the correct location:
```bash
ls ~/.claude/skills/
ls .claude/skills/
```
2. Check file permissions:
```bash
chmod 644 skills/my-skill/SKILL.md
```
3. Validate the YAML frontmatter — unclosed quotes and missing indentation are common causes:
```bash
yamllint skills/my-skill/SKILL.md
```
4. Ensure `allowed-tools` uses list format, not inline:
```yaml
# Correct
allowed-tools:
  - Read
  - Grep

# Incorrect
allowed-tools: Read, Grep
```
5. Make the `description` field specific enough to trigger automatic selection. Vague descriptions cause Claude to skip the skill.
6. Restart Claude Code after making changes.

See @skills/resolving-claude-code-issues/reference/skill-issues.md.

---

### 5. Performance Degradation

**Cause**: Context window filling up, runaway background processes, or large numbers of files being loaded unnecessarily.

**Fix**:
1. Compact the context window: `/compact`
2. Check for runaway Claude processes:
```bash
ps aux | grep claude
```
3. Reduce context size — avoid loading large files or entire directories when a targeted read suffices
4. Restart Claude Code between unrelated large tasks
5. If responses are slow, check API status and reduce context before assuming a network issue

See @skills/resolving-claude-code-issues/reference/performance-issues.md.

---

## Reference Docs

Organized by category. Read the relevant file for detailed diagnostics and additional scenarios.

### Installation & Setup
@skills/resolving-claude-code-issues/reference/installation-issues.md

### Authentication & Configuration
@skills/resolving-claude-code-issues/reference/auth-config-issues.md

### Tool-Specific Issues (Read, Edit, Write, Glob, Grep, Bash)
@skills/resolving-claude-code-issues/reference/tool-issues.md

### Skill Loading & Execution
@skills/resolving-claude-code-issues/reference/skill-issues.md

### Plugin Issues
@skills/resolving-claude-code-issues/reference/plugin-issues.md

### MCP Connection Issues
@skills/resolving-claude-code-issues/reference/mcp-issues.md

### Performance
@skills/resolving-claude-code-issues/reference/performance-issues.md

### Memory & CLAUDE.md Issues
@skills/resolving-claude-code-issues/reference/memory-issues.md

### Agent & Subagent Issues
@skills/resolving-claude-code-issues/reference/agent-issues.md

### IDE Integration
@skills/resolving-claude-code-issues/reference/ide-integration-issues.md

### Slash Command Issues
@skills/resolving-claude-code-issues/reference/slash-command-issues.md

### General Debugging Techniques
@skills/resolving-claude-code-issues/reference/debugging-techniques.md
