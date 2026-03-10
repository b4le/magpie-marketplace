# Orchestration Toolkit

**Version:** 3.0.0

Agent orchestration patterns for Claude Code - subagents, parallel agents, phased workflows, and collaborative agent teams.

## Features

- Central decision guide for choosing the right orchestration pattern
- Multi-phase workflow framework with persistent context storage across agents
- Agent Teams support for collaborative, discussion-based work
- Pause/resume capability and approval gates via iterative refinement
- `/delegate` command to interactively choose a delegation pattern
- `/orchestrate` command — composable pipeline: detect input → brainstorm (opt-in) → decompose → dispatch agents

## Installation

### Via Marketplace

```bash
claude plugin install orchestration-toolkit@content-platform-marketplace
```

### Manual Installation

Clone the repository and copy the `orchestration-toolkit/` directory into your Claude plugins folder.

## Quick Start

1. Run `/delegate` to get an interactive recommendation for your task:
   ```
   /delegate build a feature with planning, implementation, and review phases
   ```

2. Use `/orchestrate` with a goal — it decomposes and dispatches agents automatically:
   ```
   /orchestrate "build a user authentication feature"
   ```

3. Load `orchestration-guide` when you are unsure which pattern to use:
   ```
   /orchestration-toolkit:orchestration-guide
   ```

## Skills

| Skill | Description | Invoke |
|-------|-------------|--------|
| `decompose` | Turn a goal into structured work items with agent assignments and phases | `/orchestration-toolkit:decompose` |
| `orchestration-guide` | Central decision guide for choosing orchestration patterns | `/orchestration-toolkit:orchestration-guide` |
| `multi-agent-workflows` | **Deprecated (v2.0)** — `.development/workflows/` pattern; use `/orchestrate` for new work | `/orchestration-toolkit:multi-agent-workflows` |
| `developing-with-agent-teams` | Spawn and coordinate agent teams for complex projects | `/orchestration-toolkit:developing-with-agent-teams` |
| `iterative-agent-refinement` | Pattern for pause/resume capability and approval gates | `/orchestration-toolkit:iterative-agent-refinement` |

## Commands

| Command | Description | Invoke |
|---------|-------------|--------|
| `delegate` | Choose the right agent delegation pattern | `/delegate` |
| `orchestrate` | Composable pipeline: goal → decompose → dispatch agents | `/orchestrate` |

## Quick Reference

| Task Type | Recommended Pattern | Command/Action |
|-----------|---------------------|----------------|
| Simple edit or fix | Direct execution | Use tools directly |
| Research 3 topics in parallel | Parallel sub-agents | Multiple Task calls |
| Review PR from multiple angles | Agent Team | Natural language request |
| Build feature with phases | Composable pipeline (v3.0) | `/orchestrate "build feature"` |
| Design needing user feedback | Iterative refinement | Add approval gates |
| Single agent, phased work | Sequential mode | `/orchestrate --flat task` |

## Decision Flow

```
START: Task received
|
|-- Q1: Need delegation at all?
|   |-- NO -> Direct execution
|   |-- YES -> Q2
|
|-- Q2: One task or multiple?
|   |-- ONE -> Single sub-agent
|   |-- MULTIPLE INDEPENDENT -> Parallel Task calls
|   |-- MULTIPLE NEEDING COORDINATION -> Q3
|
|-- Q3: Do agents need to DISCUSS with each other?
|   |-- YES (debate, challenge) -> Agent Teams
|   |-- NO (you bridge results) -> Q4
|
|-- Q4: Complex multi-phase with persistent context?
|   |-- YES -> /orchestrate (composable pipeline: decompose → dispatch)
|   |-- NO -> Parallel Task calls
|
|-- Q5: Need approval gates mid-execution?
    |-- YES -> Add iterative-agent-refinement
    |-- NO -> Proceed without pause/resume
```

## Templates

The multi-agent-workflows skill includes legacy v2.0 templates for the `.development/workflows/` pattern (deprecated — use `/orchestrate` + `decompose` for new work):

| Template | Purpose |
|----------|---------|
| `workflow-state.yaml` | Persistent workflow state tracking (deprecated v2.0) |
| `phase-readme.md` | Phase instructions for sub-agents |
| `agent-output.md` | Standard single-file agent output |
| `STATUS.yaml` | Phase status tracking |
| `phase-summary.md` | Archival summary format |
| `read-first.md` | Multi-file output index |

## Examples

The plugin includes complete workflow examples:

- **simple-workflow/** - Basic 3-phase engineering task
- **multi-phase-workflow/** - Complex engineering with 5+ phases
- **document-analysis/** - Non-engineering document analysis
- **strategic-planning/** - Strategy development workflow
- **parallel-agents/** - Running multiple agents concurrently
- **workflow-interruption/** - Handling interruptions and resumption

## Best Practices

1. **Start with the key question**: Do agents need to discuss with each other?
2. **Use /delegate when unsure**: It will guide you to the right pattern
3. **Avoid over-orchestrating**: Simple tasks do not need frameworks
4. **Archive completed phases promptly**: Keeps context clean
5. **Use flat execution for smaller tasks**: Lower overhead when parallelism is not needed

## Related Resources

- See `skills/orchestration-guide/SKILL.md` for the full decision framework
- See `skills/decompose/SKILL.md` for the 7-phase plan generation skill
- See `commands/orchestrate.md` for the v3.0 composable pipeline command spec
- See `skills/developing-with-agent-teams/SKILL.md` for agent teams with TeamCreate
- See `skills/multi-agent-workflows/` for the v2.0 `.development/workflows/` pattern (deprecated)

## Troubleshooting

**Agent Teams commands not working**
Ensure `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set in your environment. Agent Teams is an experimental feature and requires this variable to be enabled.

**`/orchestrate` prompts interactively instead of running**
Running `/orchestrate` with no arguments is intentional — it prompts for a goal. Pass the goal directly: `/orchestrate "build feature X"` or point to a spec file: `/orchestrate ~/specs/feature.md`.

**Subagents cannot write files**
Subagents do not automatically inherit project permissions. Verify that sandbox settings allow file writes before spawning agents that need to produce output.

**MCP tools unavailable in background agents**
The orchestrator must never call MCP tools directly — delegate all MCP fetching to foreground sub-agents using the dual return pattern (write raw results to disk, return summary + path). Background agents cannot access MCP tools at all. See `references/mcp-prefetch-pattern.md` for the full protocol.

## Contributing

Contributions are welcome. Please follow the existing skill and command structure when adding new patterns. Test any new orchestration patterns against the evals in `evals/` before submitting.

## License

MIT

## Version History

See `plugin.json` for the full version history. Summary:

- **3.0.0** - Composable pipeline: `/orchestrate` rewritten as thin router (detect → brainstorm → decompose → dispatch). Plans live at `~/.claude/decompose/plans/`. `.development/workflows/` pattern deprecated. Added `decompose` skill.
- **2.0.0** - Added `developing-with-agent-teams` skill and aligned commands to marketplace conventions
- **1.0.0** - Initial release with `orchestration-guide`, `multi-agent-workflows`, and `iterative-agent-refinement` skills
