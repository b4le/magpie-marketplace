# Reliable Fan-Out Pattern

Decompose work into N independent items, assign one agent per item with a fixed pipeline. This eliminates 79% of multi-agent failures by removing specification ambiguity (42%) and coordination overhead (37%).

## Model

The key insight: agents fail when they share state, negotiate ownership, or interpret vague instructions differently. Fan-out removes all three by giving each agent exactly one item, a list of owned files, and a deterministic pipeline to follow.

**Core constraint:** One agent owns one work item end-to-end. No shared files, no cross-agent dependencies during execution.

**Anti-patterns to avoid:**
- "Bag of agents" — multiple agents with overlapping scope and no ownership boundaries. Causes 17x error amplification vs single-agent baseline.
- Shared file races — agents editing the same files. Conflicts scale quadratically with agent count.
- Flexible instructions — "do what makes sense" leads to divergent approaches that can't be synthesized.

## Template

Use this structure when orchestrating parallel work. Adapt `{placeholders}` to the task.

```
### Phase 0: Pre-fetch (if MCP data needed)
Delegate all MCP queries to foreground sub-agents using the dual return pattern
defined in `~/.claude/rules/mcp-delegation.md`. The orchestrator must never call MCP tools directly.

### Phase 1: Decompose
Break the task into N independent work items. For each item, define:
- **Scope:** What this agent will produce (one sentence)
- **Owned files:** Exhaustive list of files this agent may create/edit (no overlaps)
- **Pipeline:** Ordered steps the agent must follow (read → implement → verify)
- **Inputs:** Paths to pre-fetched data and any shared context
- **Done criteria:** How to verify the item is complete (file exists, test passes, etc.)

### Phase 2: Spawn
Launch N agents in parallel (single message, multiple Agent tool calls):
- Each agent receives: its item scope, owned files, pipeline steps, input paths
- Use `isolation: "worktree"` when agents modify files in overlapping directories
- Cap at 5 agents — diminishing returns beyond this, coordination overhead grows
- Assign model tier per agent using `~/.claude/references/model-routing-criteria.md`

### Phase 3: Collect & Verify
After all agents return:
- **Tier 1 check:** Each expected output file exists and is non-empty
- **Tier 2 check:** Outputs are consistent with each other and the original goal
- Synthesize results (merge, summarize, or integrate as appropriate)
- Report any items that failed and need retry

### Loop Guards
- Max retries per agent: 3
- Token budget ceiling per agent: 50K tokens
- If agent's diff exceeds 500 lines, flag for human review
```

## When to Use

For the full decision tree across all four patterns (standard, MCP, team, sequential), see `~/.claude/references/fan-out-patterns.md`.

- 2+ independent work items, each completable by one agent
- Research tasks: "investigate N topics in parallel"
- Implementation tasks: "build N components with clear file ownership"
- Review tasks: "review from N different dimensions"

## When NOT to Use

- Tightly coupled work where agents need each other's output mid-task
- Single-item tasks (just use one agent)
- Exploratory work where the decomposition isn't clear upfront
- Tasks where file ownership can't be cleanly separated

## Guidance for Orchestrators

- **File ownership is cardinal.** One owner per file, no exceptions. If two items need to edit the same file, either merge them into one item or have Phase 3 handle the integration.
- **Fixed pipeline > flexible instructions.** Agents can't coordinate dynamically. Tell them exactly what to do in what order.
- **Pre-fetch everything known.** Delegate MCP fetching to foreground sub-agents before spawning work agents. See `~/.claude/rules/mcp-delegation.md`.
- **Use worktrees for overlapping trees.** When agents work in the same repo but different files, `isolation: "worktree"` prevents accidental conflicts.
- **Prefer fewer, focused agents.** 3 agents with clear scope outperform 6 agents with overlapping scope.
- **Model-match agents to work.** See `~/.claude/references/model-routing-criteria.md` for tier selection.

## Mapping to Team-Spawn Presets

| Preset | Fan-out item | Pipeline |
|--------|-------------|----------|
| `review` | One review dimension (security, perf, arch) | Read → analyze → report findings |
| `debug` | One hypothesis | Gather evidence → test → confirm/falsify |
| `feature` | One component with owned files | Read context → implement → test |
| `research` | One research question | Search → gather → distill → summarize |

For ad-hoc fan-out that doesn't match a preset, use the Agent tool directly with the template above.

## Rationale

Research from METR benchmarks shows task completion drops from 54% to 37% as orchestration complexity rises. The primary failure modes are specification ambiguity (agents interpret goals differently) and coordination overhead (agents block each other or produce conflicting outputs). The "N agents × 1 item × fixed pipeline" pattern from ccswarm eliminates both by construction. Spotify's Honk pattern validates this in production: deterministic gates between phases catch 25% of errors before they propagate.
