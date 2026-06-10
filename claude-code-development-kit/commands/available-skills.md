---
name: available-skills
description: Display all available skills from the Claude Code Development Kit plugin
version: 1.0.0
---

# Claude Code Development Kit - Available Skills

*Total: 14 skills organized by category*

---

## Getting Started

**`using-tools`**
Guide for Read/Edit/Write/Glob/Grep/Bash selection
- Use when: choosing tools, deciding parallel vs sequential execution

**`using-commands`**
Understanding and using slash commands
- Use when: learning slash commands, discovering available commands

**`best-practices-reference`**
Quick triage guide for choosing the right tool, skill, or feature
- Use when: unsure which approach to take, looking for established patterns

**`understanding-auto-memory`**
Guide to Claude Code's automatic memory system
- Use when: learning how automatic memory loading works, diagnosing unexpected memory behavior

---

## Building Skills

**`authoring-skills`**
Create Claude Code skills with YAML frontmatter and best practices
- Use when: creating new skills, writing SKILL.md files

**`authoring-agent-prompts`**
Craft effective prompts for agents and tasks
- Use when: improving prompt quality, debugging agent behaviors

**`authoring-agents`**
Guide to creating custom agents for Claude Code
- Use when: defining agent roles, building agent-based workflows, creating agent definitions

**`authoring-output-styles`**
Define output styles for skills and document templates
- Use when: creating consistent output formats, designing templates

---

## Building Plugins

**`creating-plugins`**
Create, test, publish plugins to Git/npm/team marketplaces
- Use when: building plugins, publishing to marketplaces

**`creating-commands`**
Build custom slash commands
- Use when: creating /commands with frontmatter and arguments

**`integrating-mcps`**
Guide to connecting MCP servers with Claude Code
- Use when: setting up MCP tools, configuring server connections

---

## Operations

**`managing-memory`**
CLAUDE.md files and @path imports
- Use when: organizing project memory, implementing @path imports

**`understanding-hooks`**
Guide to event-driven automation with hooks
- Use when: automating workflows, triggering actions on Claude Code events

**`resolving-claude-code-issues`**
Troubleshooting guide for common Claude Code problems
- Use when: something isn't working, debugging unexpected behavior

---

## How to Use Skills

**Invoke a skill:**
```
Use the [skill-name] skill
```

**Read skill details:**
```
Read the skill at ./skills/[skill-name]/SKILL.md
```

---

## Decision Guides

**Building something for Claude Code?**
- Single skill -> `authoring-skills`
- Single command -> `creating-commands`
- Complete plugin package -> `creating-plugins`
- Custom agent -> `authoring-agents`

**Need prompt help?**
- Agent/task prompts -> `authoring-agent-prompts`
- Output formatting -> `authoring-output-styles`

**Understanding Claude Code?**
- Tool selection -> `using-tools`
- Slash commands -> `using-commands`
- Memory files -> `managing-memory`
- Automatic memory loading -> `understanding-auto-memory`

**Something not working?**
- Common problems -> `resolving-claude-code-issues`
- Which approach to use -> `best-practices-reference`

**Extending Claude Code's capabilities?**
- Connect external tools -> `integrating-mcps`
- Automate on events -> `understanding-hooks`

---

*Run `/available-skills` anytime to see this list.*
