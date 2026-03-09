# Orchestration Toolkit

**Version:** 2.0.0

Agent orchestration patterns for Claude Code - subagents, parallel agents, phased workflows, and collaborative agent teams.

## Features

- Central decision guide for choosing the right orchestration pattern
- Multi-phase workflow framework with persistent context storage across agents
- Agent Teams support for collaborative, discussion-based work
- Pause/resume capability and approval gates via iterative refinement
- `/delegate` command to interactively choose a delegation pattern
- `/orchestrate` command to initialize structured multi-agent workflows

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

2. Use `/orchestrate` to initialize a structured workflow:
   ```
   /orchestrate my-feature
   ```

3. Load `orchestration-guide` when you are unsure which pattern to use:
   ```
   /orchestration-toolkit:orchestration-guide
   ```

## Skills

| Skill | Description | Invoke |
|-------|-------------|--------|
| `orchestration-guide` | Central decision guide for choosing orchestration patterns | `/orchestration-toolkit:orchestration-guide` |
| `multi-agent-workflows` | Framework for managing complex multi-phase workflows | `/orchestration-toolkit:multi-agent-workflows` |
| `developing-with-agent-teams` | Spawn and coordinate agent teams for complex projects | `/orchestration-toolkit:developing-with-agent-teams` |
| `iterative-agent-refinement` | Pattern for pause/resume capability and approval gates | `/orchestration-toolkit:iterative-agent-refinement` |

## Commands

| Command | Description | Invoke |
|---------|-------------|--------|
| `delegate` | Choose the right agent delegation pattern | `/delegate` |
| `orchestrate` | Initialize orchestrated multi-agent workflow | `/orchestrate` |

## Quick Reference

| Task Type | Recommended Pattern | Command/Action |
|-----------|---------------------|----------------|
| Simple edit or fix | Direct execution | Use tools directly |
| Research 3 topics in parallel | Parallel sub-agents | Multiple Task calls |
| Review PR from multiple angles | Agent Team | Natural language request |
| Build feature with phases | Multi-agent-workflows | `/orchestrate feature-name` |
| Design needing user feedback | Iterative refinement | Add approval gates |
| Single agent, phased work | Flat execution | `/orchestrate --flat task` |

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
|   |-- YES -> /orchestrate (multi-agent-workflows)
|   |-- NO -> Parallel Task calls
|
|-- Q5: Need approval gates mid-execution?
    |-- YES -> Add iterative-agent-refinement
    |-- NO -> Proceed without pause/resume
```

## Templates

The multi-agent-workflows skill includes templates for:

| Template | Purpose |
|----------|---------|
| `workflow-state.yaml` | Persistent workflow state tracking |
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
- See `skills/multi-agent-workflows/reference/decision-tree.md` for detailed decision tree
- See `skills/multi-agent-workflows/reference/orchestrator-guide.md` for orchestrator workflows
- See `skills/multi-agent-workflows/reference/subagent-guide.md` for sub-agent perspective
- See `skills/developing-with-agent-teams/SKILL.md` for agent teams with TeamCreate

## Troubleshooting

**Agent Teams commands not working**
Ensure `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set in your environment. Agent Teams is an experimental feature and requires this variable to be enabled.

**`/orchestrate` creates no directory structure**
The command requires a workflow ID as the first argument. Run `/orchestrate my-workflow-name` rather than `/orchestrate` alone.

**Subagents cannot write files**
Subagents do not automatically inherit project permissions. Verify that sandbox settings allow file writes before spawning agents that need to produce output.

**MCP tools unavailable in background agents**
Background agents cannot access MCP tools. Use `run_in_background=False` for tasks that require MCP access (e.g., your organization's MCP servers).

## Contributing

Contributions are welcome. Please follow the existing skill and command structure when adding new patterns. Test any new orchestration patterns against the evals in `evals/` before submitting.

## License

MIT

## Version History

See `plugin.json` for the full version history. Summary:

- **2.0.0** - Added `developing-with-agent-teams` skill and aligned commands to marketplace conventions
- **1.0.0** - Initial release with `orchestration-guide`, `multi-agent-workflows`, and `iterative-agent-refinement` skills
