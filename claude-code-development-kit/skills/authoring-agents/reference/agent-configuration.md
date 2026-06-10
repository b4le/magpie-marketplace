# Agent Configuration Reference

Complete reference for all frontmatter fields available in `.claude/agents/*.md` files.

## All Frontmatter Fields

```yaml
---
name: my-agent
description: One-sentence description of the agent's purpose and when to use it.
model: sonnet
model_rationale: Balanced tasks with moderate reasoning depth.
maxTurns: 20
tools:
  - Read
  - Glob
  - Grep
  - Bash
color: blue
version: 1.0.0
user-invocable: true
system_prompt: Optional inline system prompt override.
---
```

### `name`

**Type:** string
**Required:** Yes (defaults to filename without `.md` extension if omitted)

The identifier used when referencing the agent. Use lowercase with hyphens. Must be unique within the agents directory scope (project vs. global).

```yaml
name: security-auditor
```

### `description`

**Type:** string
**Required:** Yes

Shown in agent discovery and used by Claude to select the right agent automatically when delegating work. Write it as a one-sentence specialist description including the domain and key capability. Front-load action words.

```yaml
description: Reviews code for security vulnerabilities, injection risks, and authentication flaws.
```

Avoid vague descriptions like "a helpful agent" — they reduce auto-selection accuracy.

### `model`

**Type:** string
**Required:** No (defaults to `inherit`)

Override the model used for this specific agent. Use model aliases, not full model IDs.

| Alias | Use Case |
|-------|----------|
| `haiku` | Fast, lightweight analysis, classification, extraction |
| `sonnet` | Balanced tasks, code generation, general implementation |
| `opus` | Complex reasoning, deep review, architectural decisions |
| `inherit` | Use the same model as the main conversation (default) |

```yaml
model: haiku   # For high-volume, fast tasks
model: opus    # For complex architecture decisions
```

Do not use full model IDs (e.g., `claude-sonnet-4-5`) — these may not be recognized and can break when models are updated. Use the aliases above.

### `maxTurns`

**Type:** integer (1–100)
**Required:** No (no limit by default)

Sets a hard cap on the number of agentic turns the agent may take before stopping. Prevents runaway execution on bounded tasks where you know approximately how many steps are needed.

```yaml
maxTurns: 10   # For a focused lookup task
maxTurns: 50   # For a multi-file refactor with verification
```

When the limit is reached, the agent returns its current state. Design the agent body to produce useful partial output in case it hits the limit.

### `tools`

**Type:** list of strings
**Required:** No (inherits parent session tools when omitted)

Allowlist of tools the agent may use. When specified, the agent cannot use any tool not listed, regardless of what the parent session permits. This is the primary mechanism for creating read-only or scoped agents.

```yaml
# Read-only research agent
tools:
  - Read
  - Glob
  - Grep

# File author (no network, no shell)
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep

# Full file + shell access
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
```

**Available tool names (common):**

| Tool | Purpose |
|------|---------|
| `Read` | Read file contents |
| `Write` | Create or overwrite files |
| `Edit` | Make targeted edits to files |
| `Bash` | Run shell commands |
| `Glob` | Find files by pattern |
| `Grep` | Search file contents |
| `WebFetch` | Fetch a URL |

**Note:** Do not include `Task` or `Agent` in a subagent's `tools` list. Subagents cannot spawn other subagents — only agents running as the main thread via `claude --agent` can do that.

### `allowed-tools`

**Type:** list of strings
**Required:** No

Alias for `tools`. Both fields are accepted; prefer `tools` for consistency.

```yaml
allowed-tools:
  - Read
  - Glob
  - Grep
```

### `color`

**Type:** string
**Required:** No

UI color hint for the agent. Accepted values: `blue`, `cyan`, `green`, `yellow`, `magenta`, `red`.

```yaml
color: cyan
```

### `version`

**Type:** string (semver)
**Required:** No

Semantic version of the agent definition. Useful for tracking changes when agents are bundled in plugins.

```yaml
version: 1.2.0
```

### `user-invocable`

**Type:** boolean
**Required:** No (default: `true`)

Controls whether the agent can be directly invoked by the user. Set to `false` for internal-use-only agents that should only be delegated to programmatically.

```yaml
user-invocable: false
```

### `system_prompt`

**Type:** string
**Required:** No

Inline system prompt for the agent. An alternative to writing the prompt in the body of the Markdown file. If both are present, this field takes precedence.

```yaml
system_prompt: "You are a security auditor. Focus only on authentication and authorization flows."
```

### `model_rationale`

**Type:** string
**Required:** No

Human-readable explanation of why a specific model was chosen for this agent. Used for documentation and audit purposes.

```yaml
model_rationale: Uses opus because architectural decisions require multi-step reasoning.
```

## Context Configuration

Agents do not maintain memory across separate invocations by default. Each invocation creates a fresh context for the agent (only its system prompt plus the prompt you provide at spawn time).

**Passing context into an agent:**
- Use `@path` imports in the agent body for static project context
- Pass dynamic context in the prompt at spawn time
- Write results to files for the parent session to read back

**Pattern for stateful workflows:**
```
# In prompt:
"Review src/auth/*.ts. Write your findings to /tmp/auth-findings.md, then return."

# Parent session reads:
Read("/tmp/auth-findings.md")
```

## Tool Restriction Patterns

### Principle of Least Privilege

Give agents only the tools they need for their defined role. This limits blast radius if the agent acts unexpectedly.

```yaml
# Bad: over-permissioned for a read-only analysis task
tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep

# Good: scoped to what the task actually requires
tools:
  - Read
  - Glob
  - Grep
```

### Combining Restrictions with Model Selection

Pair tool restrictions with an appropriate model. A fast model (Haiku) with read-only tools is cost-effective for high-volume analysis:

```yaml
model: haiku
max_turns: 15
tools:
  - Read
  - Glob
  - Grep
```

## Model Selection Guidance

- **haiku**: Use for classification, extraction, summarization, or any task where throughput matters more than depth. Best with `max_turns: 5-20`.
- **sonnet**: Use for general implementation tasks, code generation, and balanced analysis. Default choice when model is unspecified.
- **opus**: Use for complex reasoning, architectural decisions, security audits requiring multi-step inference, or tasks where accuracy is critical and cost is secondary.
