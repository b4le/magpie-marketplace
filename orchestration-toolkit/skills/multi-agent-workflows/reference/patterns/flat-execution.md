# Flat Execution Pattern

A single-agent orchestration pattern where one agent executes all phases sequentially **without spawning sub-agents**.

## When to Use

- Task is complex enough to benefit from phase structure (3+ phases)
- But context is manageable within a single agent (~50K tokens or less)
- Parallelism is not needed
- You want lower latency and cost (no sub-agent spawn overhead)
- Debugging is easier with single agent context
- Task requires consistent context across all phases (no handoff loss)

## When NOT to Use

- Task requires parallel execution (use delegated pattern instead)
- Context will exceed agent limits (use multi-agent-workflows)
- Different phases require different expertise/tools (use specialized agents)
- Very long-running tasks where resumption is critical

## Pattern Structure

```
Single Agent Execution Flow:

┌─────────────────────────────────────────────────┐
│              ORCHESTRATOR AGENT                  │
│                                                  │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐    │
│  │ Phase 1  │ → │ Phase 2  │ → │ Phase 3  │    │
│  │ Research │   │ Analysis │   │ Synthesis│    │
│  └──────────┘   └──────────┘   └──────────┘    │
│       ↓              ↓              ↓           │
│  [Direct Tool Use: Read, Edit, Write, Bash]    │
│                                                  │
│  NO Task tool usage → NO sub-agents spawned     │
└─────────────────────────────────────────────────┘
```

## Implementation

### Step 1: Initialize with Flat Mode

```
/orchestrate my-workflow --flat
```

Or manually set in workflow-state.yaml:

```yaml
workflow_id: my-workflow
execution_mode: flat  # Key indicator
status: in-progress

current_phase: research
phases:
  - name: research
    status: in-progress
  - name: analysis
    status: pending
  - name: synthesis
    status: pending
```

### Step 2: Agent Prompt Template

When launching a flat execution agent, use this prompt structure:

```markdown
You are executing a flat orchestration workflow.

## Critical Constraint
**DO NOT use the Task tool.** Execute all work directly using:
- Read: Read files and gather information
- Edit/Write: Create and modify files
- Bash: Run commands
- TodoWrite: Track progress
- AskUserQuestion: Get user input when needed

## Workflow
ID: my-workflow
Phases: research → analysis → synthesis

## Execution Instructions

1. **Use TodoWrite** to create todos for each phase
2. **Execute each phase sequentially** in your own context
3. **Save outputs** to .development/workflows/my-workflow/active/{phase}/
4. **Update workflow-state.yaml** after completing each phase
5. **Use AskUserQuestion** for any decisions requiring user input

## Phase Details

### Phase 1: Research
- Goal: [specific goal]
- Outputs: research/findings.md

### Phase 2: Analysis
- Goal: [specific goal]
- Inputs: Read research/findings.md
- Outputs: analysis/evaluation.md

### Phase 3: Synthesis
- Goal: [specific goal]
- Inputs: Read analysis/evaluation.md
- Outputs: synthesis/recommendations.md

## Progress Tracking

After each phase:
1. Mark phase complete in TodoWrite
2. Update workflow-state.yaml with phase status
3. Proceed to next phase

## Completion

When all phases complete:
1. Update workflow-state.yaml: status: completed
2. Summarize all outputs for user
```

### Step 3: Phase Transitions

Within the single agent, transition between phases using TodoWrite:

```
[Phase 1: Research - in_progress]
- Reading source documents...
- Creating findings.md...
- [COMPLETED]

[Phase 2: Analysis - in_progress]
- Reading findings.md from Phase 1...
- Evaluating options...
- Creating evaluation.md...
- [COMPLETED]

[Phase 3: Synthesis - in_progress]
- Reading evaluation.md from Phase 2...
- Creating recommendations...
- [COMPLETED]

Workflow complete.
```

### Step 4: User Input (Without Sub-Agents)

Use `AskUserQuestion` directly instead of pause/resume pattern:

```
[During Analysis phase]

Agent: "I've identified 3 strategic options. Which should I prioritize?"

[Uses AskUserQuestion tool with options]

User: "Option B"

Agent: "Proceeding with Option B analysis..."
```

## Comparison: Flat vs Delegated

| Aspect | Flat Execution | Delegated (Sub-Agents) |
|--------|----------------|------------------------|
| **Context** | Single, growing | Isolated per agent |
| **Latency** | Lower (no spawn) | Higher (spawn overhead) |
| **Cost** | Lower (fewer calls) | Higher (multiple agents) |
| **Parallelism** | None | Possible |
| **Max complexity** | ~50K tokens | Unlimited (handoffs) |
| **Debugging** | Easier (single thread) | Harder (multiple contexts) |
| **Context loss** | None | Possible at handoffs |

## Example: Strategic Planning (Flat)

```yaml
workflow_id: q1-strategy
execution_mode: flat
type: thinking

phases:
  - name: research
    status: completed
    output: research/market-analysis.md
  - name: analysis
    status: completed
    output: analysis/options-matrix.md
  - name: synthesis
    status: in-progress
  - name: recommendations
    status: pending
```

Agent execution (single context):

```
1. [Research] Read market reports → Created market-analysis.md
2. [Analysis] Read market-analysis.md → Created options-matrix.md
3. [Synthesis] Read options-matrix.md → AskUserQuestion: "Which option?" → User: "Growth"
4. [Recommendations] Based on "Growth" → Create final-plan.md
```

All in one agent, no spawning.

## Integration with /orchestrate Command

The `--flat` flag triggers flat execution mode:

```bash
/orchestrate my-project --flat
# Creates workflow with execution_mode: flat
# Agent prompt includes "DO NOT use Task tool" constraint

/orchestrate --think --flat strategy-review
# Non-engineering + flat execution
# Phases: research, analysis, synthesis, recommendations
# Single agent executes all
```

## Anti-Patterns

| Anti-Pattern | Why It's Bad | Correct Approach |
|--------------|--------------|------------------|
| Using flat for 100K+ token tasks | Context overflow | Use delegated pattern |
| Trying to parallelize in flat mode | Not possible | Use delegated pattern |
| Forgetting to save phase outputs | Loses progress | Always write to phase directories |
| Not using TodoWrite | No progress visibility | Track every phase transition |

## When to Switch Patterns

Start with flat execution, switch to delegated if:
- Context approaching 50K tokens
- Need parallel execution
- Phases require different specialized knowledge
- Task is taking too long in single context

```
Initial approach: /orchestrate --flat my-task
If context grows too large:
  → Archive current progress
  → Switch to delegated: /orchestrate my-task
  → Resume from archived state
```
