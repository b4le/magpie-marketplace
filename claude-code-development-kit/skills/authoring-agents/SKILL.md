---
name: authoring-agents
description: Guide for creating custom subagents in Claude Code using .claude/agents/ markdown files. Use when defining specialized agents with focused roles, configuring tool restrictions and model selection, building reusable agent types for plugins, or understanding agent anatomy, permission modes, and background execution.
allowed-tools:
  - Read
  - Write
  - Edit
version: 1.2.0
created: 2026-02-28
last_updated: 2026-03-09
categories:
  - agents
  - authoring
  - subagents
---

# Authoring Agents

## When to Use This Skill

Use this skill when:
- Creating a custom subagent with a specific role, persona, or tool set
- Configuring `tools`, model selection, or `max_turns` for an agent
- Bundling reusable agent definitions into a plugin
- Understanding the `.claude/agents/` file format and frontmatter fields
- Setting up background agents or understanding permission isolation

### Do NOT Use This Skill When:
- Writing the body prompts for agents → Use `authoring-agent-prompts` instead
- Spawning existing agents in a task → Reference the agent by name in your prompt
- Building Agent Teams (research preview) → See your CLAUDE.md Agent Orchestration section
- Configuring hooks that spawn agents → Use `understanding-hooks` instead
- General prompt engineering → Use `authoring-agent-prompts` instead

## Agent Anatomy

Custom agents are Markdown files stored in `.claude/agents/` (project-level) or `~/.claude/agents/` (personal/global). They share the same two-section structure as slash commands:

```
[frontmatter]      ← YAML between --- delimiters (optional but recommended)
[body]             ← System prompt / instructions for the agent
```

Full example:

```markdown
---
name: code-reviewer
description: Specialist for reviewing pull requests against style guides and security standards.
model: sonnet
tools:
  - Read
  - Glob
  - Grep
---

You are an expert code reviewer. Focus on:
- Security vulnerabilities and input validation
- Adherence to the project style guide at @CLAUDE.md
- Test coverage gaps
- Performance implications

Return findings as a structured list with severity: critical / warning / info.
```

## Agent Frontmatter Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `name` | **Yes** | string | Unique identifier using lowercase letters and hyphens. Defaults to filename without `.md` extension. |
| `description` | **Yes** | string | When Claude should delegate to this subagent. Used for automatic delegation decisions. |
| `model` | No | string | Model alias: `sonnet`, `opus`, `haiku`, or `inherit`. Defaults to `inherit` (same model as parent session). Shorthands always resolve to the latest in their family: `opus` → Claude Opus 4.6, `sonnet` → Claude Sonnet 4.6, `haiku` → Claude Haiku 4.5 (updated v2.1.32). Pinning to a specific version via frontmatter is not supported. **Note:** These resolutions are as of the last devkit sync date and may change with new Claude releases — run `devkit-maintain sync` to check for updates. |
| `model_rationale` | No | string | Human-readable explanation of why this model was chosen. |
| `maxTurns` | No | integer | Maximum number of agentic turns before the agent stops (1–100). No limit by default. |
| `permissionMode` | No | string | Controls how the agent handles permission prompts. Enum: `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`. |
| `tools` | No | list | Allowlist of tools the agent may use. Inherits all tools from parent session if omitted. |
| `allowed-tools` | No | list | Alias for `tools`. |
| `hooks` | No | object | Agent-scoped hooks. Same format as `hooks.json` — event names map to arrays of matcher/handler entries. Scoped to this agent's execution only. See [Agent Hooks](#agent-hooks) below. |
| `color` | No | string | UI color hint: `blue`, `cyan`, `green`, `yellow`, `magenta`, or `red`. |
| `version` | No | string | Semver string for the agent definition. |
| `user-invocable` | No | boolean | Whether the agent can be invoked directly by the user. Default: `true`. |
| `system_prompt` | No | string | Inline system prompt (alternative to placing instructions in the body). |

See @reference/agent-configuration.md for the full field reference including model selection and tool restriction patterns.

See @reference/isolation-and-permissions.md for sandbox behavior, worktree isolation, and permission inheritance details.

## Agent Hooks

Since v2.1.0, agents can define a `hooks` block in their frontmatter. These hooks are scoped to the agent's execution and do not affect the parent session. The format is identical to `hooks.json`: event names map to arrays of matcher/handler entries.

```yaml
---
name: careful-editor
description: Editor agent with pre-tool validation
tools: [Read, Write, Edit, Glob, Grep]
hooks:
  PreToolUse/Edit:
    - matcher: ""
      hooks:
        - type: prompt
          prompt: "Verify this edit preserves existing functionality"
---
```

## Background Agents

Control background execution at spawn time. Background agents execute in parallel with the main session, returning results when complete.

**Key constraints for background agents:**
- Cannot access MCP tools (known bugs #13254, #21560)
- Do not share the parent session's permission grants

**MCP delegation rule:** The orchestrator must never call MCP tools directly. Delegate all MCP fetching to foreground sub-agents (`run_in_background: false`) using the dual return pattern: sub-agent writes full results to `local-state/prefetch/{session}/` and returns a concise summary + file path. This keeps MCP bloat (~25KB+ per call) out of the orchestrator context.

## Agent Types

Claude Code includes built-in agent types for common tasks. You can also define custom types via `.claude/agents/` files.

See @reference/agent-types.md for a reference table of built-in types and guidance on when to use each.

## Custom Agent Types

Define a custom agent type by creating a `.md` file in `.claude/agents/`. The filename (without extension) becomes the type identifier. Plugin authors can bundle agents by placing them in the plugin's `agents/` directory — they are installed alongside the plugin.

**Important:** Subagents cannot spawn other subagents. The `Agent` tool (formerly `Task`) is only available to agents running as the main thread via `claude --agent`, not to subagents. Do not include `Task` or `Agent` in a subagent's `tools` list expecting it to delegate further.

Plugin-bundled agents use a namespaced form: `plugin-name:agent-name`.

## @path Imports

Use `@path` references in the agent body to import file content at load time:

```markdown
Follow the coding standards at @CLAUDE.md.
Use the API schema defined in @src/types/api.ts.
```

Paths are resolved relative to the project root. This is a static import — the content is embedded when the agent prompt is constructed.

## Supporting Documentation

### Detailed References
@reference/agent-configuration.md - Full frontmatter field reference, memory configuration, model selection
@reference/agent-types.md - Built-in types, custom types, and when to use each
@reference/isolation-and-permissions.md - Sandbox behavior, tool restrictions, permission inheritance

### Templates
@templates/custom-agent-template.md - Copy-paste template for new agents

### Examples
@examples/researcher-agent.md - Read-only research agent with focused instructions

## Version History

### v1.2.0 (2026-03-09)
- Added `hooks` frontmatter field and Agent Hooks section (devkit v2.1.0+)
- Added model resolution note to `model` field: current targets for `opus`, `sonnet`, `haiku` shorthands

### v1.1.0 (2026-03-01)
- Fixed field names: `max-turns` → `max_turns`
- Changed `name` and `description` from "Recommended" to Required
- Aligned frontmatter table to schema ground truth: removed non-existent fields (`disallowedTools`, `skills`, `mcpServers`, `hooks`, `memory`, `background`, `isolation`), added valid fields (`model_rationale`, `color`, `version`, `user-invocable`, `system_prompt`, `allowed-tools`, `permissionMode`)
- Fixed model values to use aliases (`sonnet`, `opus`, `haiku`, `inherit`) not full model IDs
- Added note that subagents cannot spawn other subagents (no `Task`/`Agent` tool in subagents)

### v1.0.0 (2026-02-28)
- Initial skill creation
- Covers agent anatomy, frontmatter fields, permission modes, background agents, and custom types
- Progressive disclosure via reference, templates, and examples
