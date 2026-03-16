# Agent Config Examples

Shows how `agent_config` fields from the plan JSON map to Agent tool call parameters.

## Field Mapping

| Plan JSON field | Agent tool parameter | Notes |
|---|---|---|
| `subagent_type` | `subagent_type` | Direct mapping |
| `skills` | Included in `prompt` | "Use the following skills: {skills}" |
| `model` | `model` | `"sonnet"`, `"opus"`, or `"haiku"` |
| `mode` | `mode` | Permission mode for the agent |
| `max_turns` | `max_turns` | Cap on agentic turns |
| `missing_specialist` | — | Informational only; logged as warning |

## Examples

### TypeScript Implementation Agent

Plan JSON:
```json
{
  "subagent_type": "typescript-pro",
  "skills": [],
  "model": "sonnet",
  "mode": "acceptEdits",
  "max_turns": 30,
  "missing_specialist": false
}
```

Agent tool call:
```json
{
  "name": "ts-impl-WI-1",
  "subagent_type": "typescript-pro",
  "description": "Implement login handler",
  "model": "sonnet",
  "mode": "acceptEdits",
  "max_turns": 30,
  "prompt": "## Work Item: WI-1 — Implement login handler\n\n..."
}
```

### Code Review Agent (Explore-based)

Plan JSON:
```json
{
  "subagent_type": "Explore",
  "skills": ["comprehensive-review"],
  "model": "opus",
  "mode": "default",
  "max_turns": 15,
  "missing_specialist": false
}
```

Agent tool call:
```json
{
  "name": "review-WI-1",
  "subagent_type": "Explore",
  "description": "Review login handler implementation",
  "model": "opus",
  "max_turns": 15,
  "prompt": "Use the comprehensive-review skill.\n\nReview the following files for...\n..."
}
```

### Fallback When Specialist Missing

Plan JSON:
```json
{
  "subagent_type": "general-purpose",
  "skills": [],
  "model": "sonnet",
  "mode": "acceptEdits",
  "max_turns": 30,
  "missing_specialist": true
}
```

The `missing_specialist: true` flag means the preferred agent (e.g., `python-pro`) was unavailable. The orchestrator should log:
```
⚠ WI-3: python-pro unavailable, using general-purpose as fallback
```

### Agent with Skills Layered

Plan JSON:
```json
{
  "subagent_type": "bash-pro",
  "skills": ["bash-defensive-patterns", "shellcheck-configuration"],
  "model": "sonnet",
  "mode": "acceptEdits",
  "max_turns": 20,
  "missing_specialist": false
}
```

Agent tool call — skills are prepended to the prompt:
```json
{
  "name": "bash-WI-5",
  "subagent_type": "bash-pro",
  "description": "Build registry script",
  "model": "sonnet",
  "mode": "acceptEdits",
  "max_turns": 20,
  "prompt": "Use these skills: bash-defensive-patterns, shellcheck-configuration.\n\n## Work Item: WI-5 — ...\n..."
}
```

### Isolation for Parallel Agents

When multiple agents work in the same repo:
```json
{
  "name": "impl-WI-1",
  "subagent_type": "typescript-pro",
  "isolation": "worktree",
  "prompt": "..."
}
```

Use `isolation: "worktree"` when:
- Multiple agents edit files in the same directory tree
- Agents might conflict on shared build artifacts
- The plan has `parallel: true` for the execution phase

Skip isolation when:
- Agents own completely separate directory trees
- Only one agent runs at a time (sequential phases)

## Naming Convention

Agent names follow: `{role}-{work_item_id}`
- `ts-impl-WI-1` — TypeScript implementation, work item 1
- `review-WI-1` — Review of work item 1
- `test-WI-3` — Test runner for work item 3
