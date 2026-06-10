# Orchestration Decision Tree

When should you use which orchestration approach? Use this guide to choose.

**For comprehensive guidance:** See `skills/orchestration-guide/SKILL.md`

## The Key Question

> **"Do the agents need to discuss with each other, or just report back to you?"**

- **Report back** → Subagents (Task tool), Multi-agent-workflows
- **Discuss** → Agent Teams (TeamCreate)

This single question captures the fundamental distinction between orchestration patterns.

## Quick Decision Flow

```
START: Complex task received
│
├─→ How many steps/agents needed?
│   │
│   ├─→ 1-2 steps
│   │   └─→ ✅ Direct execution (no orchestration)
│   │       Use: Read, Edit, Write, Bash directly
│   │
│   ├─→ 3-5 steps
│   │   │
│   │   └─→ Need user approval mid-task?
│   │       │
│   │       ├─→ YES → ✅ iterative-agent-refinement
│   │       │        Pause/resume pattern with approval gates
│   │       │
│   │       └─→ NO → ✅ Direct sub-agent orchestration
│   │                Use: Task tool, no special framework
│   │
│   └─→ 5+ steps or distinct phases
│       │
│       └─→ Want single agent (no sub-agent spawning)?
│           │
│           ├─→ YES → ✅ Flat execution (/orchestrate --flat)
│           │        Single agent executes all phases sequentially
│           │        Lower latency, lower cost, no context handoff loss
│           │        Best for: <50K token tasks, no parallelism needed
│           │
│           └─→ NO → Need persistent context across agents?
│               │
│               ├─→ YES → ✅ multi-agent-workflows (delegated)
│               │        .development/ structure, phase management
│               │        │
│               │        └─→ Need approval gates within phases?
│               │            │
│               │            ├─→ YES → Compose with iterative-agent-refinement
│               │            └─→ NO → multi-agent-workflows alone
│               │
│               └─→ NO → ✅ Direct sub-agent orchestration
│                        Parallel Task calls, no file structure
│
└─→ New project from scratch?
    │
    └─→ YES → Use /orchestrate command to initialize
        ├─→ /orchestrate my-project (delegated, with sub-agents)
        └─→ /orchestrate --flat my-project (single agent, no spawning)
```

## Component Summary

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| **Direct execution** | Simple operations | 1-2 steps, single file |
| **Task tool** | Sub-agent delegation | 3-5 steps, parallel work, agents report back |
| **Agent Teams** | Collaborative agents | Agents need to discuss, debate, challenge each other |
| **iterative-agent-refinement** | Approval gates, pause/resume | Mid-execution user input needed |
| **multi-agent-workflows** | Large-scale orchestration | 5+ agents, multi-phase, hours/days, you bridge phases |
| **Flat execution** | Single-agent, no spawning | Phase structure needed, but <50K tokens, no parallelism |
| **/orchestrate** | Initialize workflow structure | New project, need .development/ setup |
| **/orchestrate --flat** | Initialize flat workflow | Single agent, no sub-agents, sequential phases |
| **/delegate** | Choose orchestration pattern | Unsure which approach to use |

## Triggering Criteria

### Agent Teams (TeamCreate)
- ✅ Agents need to discuss, debate, or challenge each other
- ✅ Multiple perspectives that should interact (not just collect results)
- ✅ Complex work requiring peer-to-peer collaboration
- ✅ Cross-layer coordination (frontend/backend/tests each owned by different teammate)
- ❌ Independent parallel tasks (use subagents instead)
- ❌ Work where only the final result matters (use subagents instead)
- ❌ Simple delegation (overhead exceeds benefit)

### iterative-agent-refinement
- ✅ User input needed mid-execution
- ✅ Approval gates before continuing
- ✅ Iterative refinement (design → feedback → refine)
- ✅ Checkpointing long operations
- ❌ Task fully specified upfront
- ❌ No decisions needed during execution

### multi-agent-workflows
- ✅ 5+ coordinated agents
- ✅ Distinct phases (research, design, execution, etc.)
- ✅ Context must persist across agents
- ✅ Long-running work (hours or days)
- ❌ Simple 1-3 agent tasks
- ❌ Tasks completable in under 30 minutes

### /orchestrate command
- ✅ New project needing structure
- ✅ Want standard phase layout
- ✅ Using --think for non-engineering work
- ❌ Working within existing workflow
- ❌ Quick prototyping without formality

### Flat execution (--flat flag)
- ✅ Task has distinct phases but manageable context (<50K tokens)
- ✅ Want lower latency (no sub-agent spawn overhead)
- ✅ Want lower cost (fewer API calls)
- ✅ Context consistency matters (no handoff loss)
- ✅ Easier debugging (single agent thread)
- ❌ Task requires parallelism
- ❌ Context will exceed 50K tokens
- ❌ Phases require different specialized expertise

**See:** `reference/patterns/flat-execution.md` for full pattern documentation.

## Domain-Specific Patterns

### Engineering Tasks

```
/orchestrate feature-auth
Phases: planning → execution → review
```

Common patterns:
- Feature implementation: planning, design, implementation, testing, review
- Bug investigation: investigation, root-cause, fix, validation
- Refactoring: audit, planning, migration, verification

### Non-Engineering Tasks (--think flag)

```
/orchestrate --think strategy-q1
Phases: research → analysis → synthesis → recommendations
```

Common patterns:
- Document analysis: collection, extraction, synthesis, validation
- Strategic planning: research, analysis, synthesis, recommendations
- Content creation: ideation, drafting, editing, publishing
- Decision support: context, options, evaluation, decision

## Composition Examples

### Example 1: Engineering with Approval Gates

```
Workflow: auth-system
│
├── Phase: planning
│   └── iterative-agent-refinement (get approval on plan)
│
├── Phase: implementation
│   └── Standard sub-agents (no approval needed)
│
└── Phase: review
    └── Standard sub-agents (final validation)
```

### Example 2: Strategic Planning with Checkpoints

```
Workflow: quarterly-strategy (--think)
│
├── Phase: research
│   └── Standard sub-agents (gather data)
│
├── Phase: analysis
│   └── iterative-agent-refinement (validate analysis approach)
│
├── Phase: synthesis
│   └── iterative-agent-refinement (approve draft recommendations)
│
└── Phase: recommendations
    └── Standard sub-agents (finalize deliverables)
```

### Example 3: Lightweight Approval (No Multi-Phase)

```
Task: "Design this API schema and get my approval"

No /orchestrate needed - use iterative-agent-refinement directly:
1. Launch design agent
2. PAUSE for user review
3. RESUME with feedback
4. Finalize
```

## Anti-Patterns

| Anti-Pattern | Why It's Bad | Correct Approach |
|--------------|--------------|------------------|
| Using multi-agent-workflows for 2-step task | Overhead exceeds benefit | Direct execution |
| Using iterative-agent-refinement when no input needed | Unnecessary pause | Standard sub-agent |
| Using /orchestrate for one-off quick task | Too much structure | Skip command, work directly |
| Not using approval gates for strategic decisions | Missing human judgment | Add iterative-agent-refinement |

## Quick Reference

```bash
# Direct execution (1-2 steps)
Read file → Edit file → Done

# Simple sub-agents (3-5 steps, no approval)
Task(subagent_type=general-purpose, prompt="...")

# Approval gates needed
Use iterative-agent-refinement pattern

# Large scale, multi-phase (with sub-agents)
/orchestrate my-project
→ Invokes multi-agent-workflows skill (delegated mode)

# Large scale, multi-phase (single agent, no spawning)
/orchestrate --flat my-project
→ Single agent executes all phases sequentially
→ DO NOT use Task tool

# Non-engineering workflow
/orchestrate --think my-analysis
→ Uses research/analysis/synthesis/recommendations phases

# Non-engineering + flat execution
/orchestrate --think --flat my-strategy
→ Single agent, research/analysis/synthesis/recommendations
```
