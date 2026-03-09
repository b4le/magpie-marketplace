---
name: iterative-agent-refinement
description: >
  Pattern for orchestrating tasks with pause/resume capability and approval gates.
  Use when tasks require mid-execution user input, iterative refinement, or checkpoints.
  Works standalone for simple approval flows OR composes with multi-agent-workflows
  for approval gates within larger workflows. Lightweight alternative when full
  workflow infrastructure isn't needed.
version: 2.0.0
created: 2025-11-21
last_updated: 2025-12-06
tags:
  - orchestration
  - patterns
  - iterative-refinement
  - sub-agents
  - workflow
  - approval-gates
---

# Iterative Agent Refinement

## Overview

A pattern for orchestrating complex multi-step tasks using specialized sub-agents with pause/resume capability, enabling iterative refinement and user input collection during execution.

## Choosing the Right Pattern

**Not sure if this is the right skill?** Start with `skills/orchestration-guide/SKILL.md` for the central decision framework.

**The key question:** Do you need approval gates or user input mid-execution?
- **Yes** → This pattern (iterative-agent-refinement)
- **No** → Use standard sub-agents or multi-agent-workflows

## When to Use This Pattern

Use this pattern when:
- **Complex task requires multiple specialized steps** that benefit from focused sub-agents
- **User input may be needed mid-execution** to clarify ambiguities or make decisions
- **Long-running analysis** where partial results should be reviewed before continuing
- **Iterative refinement** where sub-agent findings inform next steps

**Do NOT use when:**
- Simple single-step tasks that complete in one execution
- No user input needed during execution
- Task can be completed with direct tool usage

## Related Skills

**For decision guidance:** See `skills/orchestration-guide/SKILL.md` (central entry point)

**When to use multi-agent-workflows instead**:
- Task requires 5+ coordinated agents
- Multi-phase workflow with persistent file structure
- Context must persist across agents in .development/ folder
- Long-running work (hours/days)

**When to use Agent Teams instead**:
- Agents need to discuss, debate, or challenge each other
- Multiple perspectives that should interact (not just collect results)

**Composing with multi-agent-workflows**:

This pattern can be used **within** a multi-agent-workflows phase:

```
Multi-Agent Workflow: feature-implementation
└── Phase: design
    └── iterative-agent-refinement pattern
        ├── Agent creates draft design
        ├── PAUSE → User reviews design
        ├── User provides feedback
        ├── RESUME → Agent refines design
        └── Continue to next phase
```

Example: A strategic planning workflow uses `multi-agent-workflows` for phases (research → analysis → synthesis → recommendations) but uses `iterative-agent-refinement` within the synthesis phase to get user approval on draft recommendations before finalizing.

See `skills/multi-agent-workflows/SKILL.md` for large-scale orchestration.
See `skills/multi-agent-workflows/reference/decision-tree.md` for choosing between patterns.

## Pattern Structure

### Step 1: Launch Initial Sub-Agent

```markdown
Launch specialized sub-agent with clear mission:
- Define specific outcome expected
- Specify what to return (findings, questions, agent ID)
- Instruct to mark completion with "COMPLETE - Agent ID: {id}"
- Indicate questions are optional (only if genuine ambiguity)
```

**Example:**
```
Task tool with subagent_type=general-purpose:
"Analyze the restructuring prompt and provide strategic recommendations.

Your Mission: [specific task]

Output Requirements:
1. Comprehensive analysis report
2. Questions for Alignment (OPTIONAL - only if genuine ambiguity)
3. Agent ID for resume

When complete, state: 'ANALYSIS COMPLETE - Agent ID: [your-agent-id]'"
```

### Step 2: Track Agent ID

When sub-agent completes:
- **Extract agent ID** from completion message
- **Store in todo list** or orchestrator context
- **Review findings** and questions (if any)

**Example:**
```
Sub-agent returns: "ANALYSIS COMPLETE - Agent ID: product-brief-restructuring-strategic-analyzer-20251121"

Store: agentId_analysis = "product-brief-restructuring-strategic-analyzer-20251121"
```

### Step 3: Collect User Input (If Needed)

If sub-agent returned questions:
- **Present questions to user** using AskUserQuestion tool or direct communication
- **Gather decisions/clarifications**
- **Prepare context for resume**

**Example:**
```
Sub-agent asked:
Q1: Should we reorder phases? (YES/NO with rationale)
Q2: Skill granularity approach? (Option A/B/C)

User answers:
A1: YES - reorder to prevent deprecated pattern propagation
A2: Option A - minimize complexity
```

### Step 4: Resume Sub-Agent with New Context

Launch new Task with **resume parameter**:
- **Use same agent ID** from Step 2
- **Provide user answers** and any additional context
- **Specify next steps** based on findings

**Example:**
```
Task tool with subagent_type=general-purpose, resume="{agentId_analysis}":
"Continue analysis with user decisions:

User Decisions:
1. Phase reordering: YES (apply standardization between terminology and artifacts)
2. Skill granularity: Option A (one skill per agent, no splitting)
3. Validation depth: Option C (parallel agents with full validation)

Your Mission:
Based on these decisions, create implementation plan for:
- Phase description updates
- Input manifest system
- Two-stage validation framework

Return: Implementation plan + any new questions + agent ID"
```

### Step 5: Iterate or Complete

Based on resumed sub-agent output:
- **If more questions** → Repeat Steps 3-4
- **If implementation needed** → Launch new specialized sub-agents (Steps 1-2)
- **If complete** → Proceed with implementation or next phase

## Key Design Principles

### 1. Specialized Sub-Agents

Each sub-agent should have **narrow focus**:
- ✅ "Analyze restructuring prompt design" (focused)
- ❌ "Analyze prompt and implement all changes" (too broad)

**Benefits:**
- Deeper analysis within focused domain
- Easier to resume (smaller context)
- Parallel execution possible

### 2. Clear Completion Markers

Sub-agents must signal completion:
```
"ANALYSIS COMPLETE - Agent ID: {id}"
"IMPLEMENTATION COMPLETE - Agent ID: {id}"
"VALIDATION COMPLETE - Agent ID: {id}"
```

**Benefits:**
- Orchestrator knows when to proceed
- Agent ID extraction is unambiguous
- Resume point clearly marked

### 3. Optional Questions

Questions should be **genuinely optional**:
- Sub-agent proceeds with reasonable defaults if no questions
- Questions indicate true ambiguity (not laziness)
- User can skip answering if defaults acceptable

**Bad example:**
```
Q: What file should I analyze? (required)
```
This should be specified in initial prompt, not asked mid-execution.

**Good example:**
```
Q: Phase 4 could run after 3.1 or after all of Phase 3. Recommend after 3.1 to prevent pattern propagation. Agree? (optional - will proceed with recommendation if no answer)
```

### 4. Context Preservation

When resuming:
- **Load previous transcript** automatically (Claude Code feature)
- **Provide NEW context only** (decisions, clarifications, next steps)
- **Don't repeat** what sub-agent already knows

**Example:**
```
Resume agent-123:
"User decisions: [new info]
Next steps: [what to do now]"

NOT:
"You previously analyzed X and found Y. Here's what you said: [long recap]. Now user says Z."
```
The agent already has its transcript, no need to repeat.

### 5. Token Efficiency

Sub-agents should return **tiered reports**:
- **Summary:** Key findings, metrics, questions (<1000 tokens)
- **Detail:** Full analysis, methodology (loaded on-demand)

Orchestrator loads summaries, details only when needed.

## When Resume IS Valuable

### Non-Engineering Examples

**Document Review with Approval:**
```
Launch document-analyzer agent:
"Analyze the quarterly reports and extract key findings.
After identifying top 5 insights, pause for review.
Return agent ID."

User reviews insights, selects which to prioritize.

Resume with feedback:
"User prioritized insights 1, 3, 5. Expand on these and create executive summary."
```

**Strategic Decision Support:**
```
Launch strategy-agent:
"Analyze market options and recommend approach.
Present 3 options with trade-offs. Pause for decision.
Return agent ID."

User selects preferred option.

Resume with decision:
"User chose Option B (aggressive growth). Create implementation roadmap."
```

### Scenario 1: Exploratory Analysis with Checkpoints

```
Launch analyzer agent:
"Analyze codebase structure. After exploring 3-5 key files, pause and ask:
- Should I go deeper into X?
- Should I explore Y area?
Return agent ID for resume."

Resume based on answers:
"User wants deeper dive into X, skip Y. Continue analysis."
```

### Scenario 2: Iterative Design

```
Launch design agent:
"Design API schema. Present draft and ask:
- Field naming conventions acceptable?
- Missing any required fields?
Return agent ID."

Resume with feedback:
"User wants 'snake_case' not 'camelCase'. user_id field missing. Revise."
```

### Scenario 3: Long-Running Implementation with Approval Gates

```
Launch implementation agent:
"Implement features 1-5. After each feature, report completion and ask to continue.
Return agent ID."

Resume per feature:
"Feature 1 approved. Proceed to Feature 2."
"Feature 2 approved. Proceed to Feature 3."
```

## Anti-Patterns

### ❌ Resuming for Simple Continuation

**Don't:**
```
Agent 1: Analyze file A
Resume Agent 1: Now analyze file B
```

**Do:**
```
Launch new agent: Analyze files A and B in parallel
OR
Agent 1: Analyze files A, B, C in single execution
```

**Why:** Resume adds overhead. Use for genuine pause/input needs, not sequential tasks.

### ❌ Over-Questioning

**Don't:**
```
Agent asks 10 questions mid-execution covering obvious decisions
```

**Do:**
```
Agent makes reasonable defaults, asks 1-3 questions only for true ambiguities
```

**Why:** Sub-agents should be autonomous. Questions indicate ambiguity, not laziness.

### ❌ Resume Without Context

**Don't:**
```
Resume agent-123: "Continue"
```

**Do:**
```
Resume agent-123: "User approved approach A. Reject approach B due to X. Proceed with implementation focusing on Y."
```

**Why:** Agent needs NEW information to proceed, not vague instruction.

## Template for Orchestrator

```markdown
## Orchestration Plan with Resume Support

### Phase 1: Initial Analysis
1. Launch {specialized-agent} with clear mission
2. Instruct to return: findings + questions (optional) + agent ID
3. Track agent ID: `agentId_phase1`

### Phase 2: User Input (Conditional)
IF agent returned questions:
  4. Present questions to user
  5. Collect answers
ELSE:
  6. Proceed with agent's recommendations

### Phase 3: Resume or New Agent (Decision Point)
IF need same agent to continue:
  7. Resume with agent ID: `Task(resume=agentId_phase1, prompt="[new context]")`
ELSE IF need different specialization:
  8. Launch new specialized agent with Phase 1 findings as input

### Phase 4: Implementation
9. Launch implementation agents (may be parallel)
10. Each returns completion + agent ID
11. Track all IDs for potential resume

### Phase 5: Validation
12. Review implementation
13. IF issues found → Resume relevant agent with fixes
14. ELSE → Complete
```

## Benefits of This Pattern

1. **Iterative Refinement:** Sub-agents can pause, get feedback, improve
2. **User Control:** Decisions made at checkpoints, not blindly executed
3. **Token Efficiency:** Resume loads transcript, orchestrator adds only new context
4. **Fault Tolerance:** If agent fails, resume from checkpoint instead of restart
5. **Specialization:** Each sub-agent focused on narrow domain (deeper expertise)

## Limitations

1. **Resume overhead:** Each resume creates new API call (latency)
2. **Context growth:** Transcript grows with each resume (token cost)
3. **Complexity:** Orchestrator must track multiple agent IDs
4. **Not always needed:** Many tasks complete in single execution (don't over-engineer)

## When NOT to Use

- **Simple tasks:** Direct tool usage faster than sub-agent orchestration
- **No user input needed:** Launch agent with complete context, let it finish
- **Independent parallel work:** Multiple agents better than serial resume
- **Deterministic execution:** No ambiguity → no need for pause/ask/resume

## Conclusion

The sub-agent resume pattern is powerful for **complex, iterative tasks requiring user input**. However, many tasks complete successfully in single execution without resume. Use resume when **genuine pause points** exist (ambiguity, approval gates, checkpoints), not as default orchestration strategy.

