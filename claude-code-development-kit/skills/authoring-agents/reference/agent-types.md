# Agent Types Reference

## Built-in Agent Types

Claude Code provides several built-in agent types accessible via the `subagent_type` parameter in Agent tool calls (formerly Task, renamed in v2.1.63 — the `Task` alias still works). These do not require a `.claude/agents/` file — they are provided by the runtime.

| Type | Role | Best For |
|------|------|----------|
| `general-purpose` | Full-capability agent with no specialization | Default for most delegated tasks when no specialized type fits |
| `Explore` | Codebase exploration and discovery | Understanding an unfamiliar repo, mapping dependencies, finding relevant files |
| `Plan` | Task decomposition and planning | Breaking down complex work into sequenced steps before implementation |

### When to Use Built-in Types

**`general-purpose`** — Use when the task requires broad capability and you have not defined a more specific custom agent. Inherits all tools from the parent session.

**`Explore`** — Use at the start of a workflow when you need to map a codebase before delegating implementation work. Returns a structured summary the main session can act on.

**`Plan`** — Use before multi-step implementation to generate a sequenced task list. Particularly useful before spawning multiple parallel implementation agents.

## Specialized Domain Types

Domain-specific subagent types are available when the corresponding plugin is installed. These combine a model configuration with a domain-focused system prompt.

Examples (from installed plugins):

| Domain | subagent_type | Use Case |
|--------|---------------|----------|
| Cloud | `cloud-infrastructure:cloud-architect` | AWS/Azure/GCP, IaC, cost optimization |
| Security | `security-scanning:security-auditor` | DevSecOps, vulnerability assessment |
| Backend | `api-scaffolding:backend-architect` | API design, microservices |
| Frontend | `application-performance:frontend-developer` | React, Next.js, performance |
| Data | `data-engineering:data-engineer` | Pipelines, Spark, dbt |

See your installed plugins (`/available-skills`) for the current list.

## Custom Agent Types

### Creating a Custom Type

Create a Markdown file in `.claude/agents/` (project) or `~/.claude/agents/` (global). The filename without the `.md` extension becomes the type identifier.

```
.claude/agents/
  security-auditor.md    → subagent_type: "security-auditor"
  api-designer.md        → subagent_type: "api-designer"
  doc-writer.md          → subagent_type: "doc-writer"
```

### Plugin-Bundled Agent Types

When distributing agents via a plugin, place the `.md` files in the plugin's `agents/` directory. Installed agents are referenced with a `plugin-name:agent-name` namespace:

```
subagent_type: "my-toolkit:security-auditor"
```

### Choosing Between Built-in and Custom

Use a built-in type when:
- The task fits a general category (explore, plan, implement, test)
- You want the default model and tool set
- No specialized prompt is needed

Create a custom type when:
- The agent needs a domain-specific system prompt
- You want to restrict tools or set a specific model
- The agent will be reused across many tasks or shared with a team
- You are distributing it as part of a plugin

## Adding Skills to General-Purpose Agents

Load skills at task-start to give a `general-purpose` agent domain context without creating a dedicated agent file. When using the Agent tool, include a skill-load instruction at the top of the prompt:

```
Agent tool — subagent_type: "general-purpose"
Prompt:
  Load this skill before starting:
  /claude-code-development-kit:authoring-agents

  Then create a new agent definition for a documentation specialist.
```
