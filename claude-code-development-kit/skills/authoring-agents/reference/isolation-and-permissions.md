# Isolation and Permissions

## Sandbox Behavior

Each subagent runs in an isolated context. It does not share in-memory state with the parent session or with other agents running in parallel. Isolation applies to:

- **Conversation history**: The agent starts with a fresh context containing only its system prompt (from the agent file body) and the Task `prompt` you provide.
- **Tool approvals**: Permission grants made interactively in the parent session are not automatically inherited. The agent's permissions come from its `tools` list and the session's permission mode.
- **Environment**: The agent uses the same working directory (`$CLAUDE_PROJECT_DIR`) as the parent, so file paths are consistent.

## Tool Restrictions via `tools`

The `tools` field in the agent frontmatter is the primary control for what an agent can do. When set, it acts as an allowlist — the agent can only invoke tools in the list.

```yaml
# This agent can only read and search; it cannot write, run commands, or fetch URLs
tools:
  - Read
  - Glob
  - Grep
```

If `tools` is omitted entirely, the agent inherits all tools that are available in the parent session. This means a parent with `Bash` enabled will produce an agent with `Bash` enabled unless you explicitly restrict it.

**Best practice:** Always specify `tools` for agents that will be distributed in plugins or used in automated workflows. Explicit restrictions make the agent's behavior predictable regardless of the calling context.

## Read-Only Pattern

The most common restriction pattern. Grant only `Read`, `Glob`, and `Grep` to create an agent that can explore and analyze without modifying anything:

```yaml
tools:
  - Read
  - Glob
  - Grep
```

Use read-only agents for:
- Code analysis and audit tasks
- Documentation generation inputs (agent reads, parent writes)
- Research and summarization
- Any task where the output is a report, not a file change

## Worktree Isolation

Claude Code supports Git worktrees for parallel agent work. When an agent is assigned to a worktree, it operates in an isolated checkout of the repository. Changes in the worktree do not affect the main working tree until explicitly merged.

This is useful for running multiple `implementation-agent` instances on independent features without file conflicts. Each agent owns its worktree and all files within it.

The `WorktreeCreate` and `WorktreeRemove` hook events fire when worktrees are created or removed, allowing you to automate setup and cleanup.

## Permission Inheritance from Parent Sessions

Agents do not automatically inherit interactive permission grants from the parent session. Specifically:

- **One-time approvals** (e.g., "allow this Bash command once") are not passed to subagents
- **Session-level approvals** apply only within the session that granted them
- **`tools` in the agent file always takes precedence** over what the parent session has permitted

### Implications for Plugin Authors

When bundling agents in a plugin, document the `tools` requirements clearly. Users running your plugin in a restricted environment (e.g., a CI runner with no `Bash` access) may see different behavior if your agent relies on tools that are not universally available.

### MCP Tool Access

Background agents cannot access MCP tools due to known platform bugs (#13254, #21560). MCP tools such as Groove and Aika require foreground execution. When spawning an agent via the Agent tool, set `run_in_background` to `false` to ensure MCP access works:

```
Agent tool — subagent_type: "general-purpose", run_in_background: false
Prompt: "Use the Groove MCP to look up issue COCAM-1234."
```

Global MCP servers (configured in `~/.claude/mcp.json`) work correctly. Project-scoped MCP servers may not work with custom subagent types (#13898).

## Checklist for Safe Agent Design

- [ ] Specify `tools` explicitly rather than relying on inheritance
- [ ] Use read-only tool sets for analysis and reporting agents
- [ ] Document which MCP tools the agent needs and whether foreground execution is required
- [ ] Test agent behavior in a restricted session to verify `tools` works as expected
- [ ] When distributing via plugin, note tool and permission requirements in the plugin README
