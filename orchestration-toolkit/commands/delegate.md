---
name: delegate
description: Choose the right agent delegation pattern for your task
argument-hint: "[task-description]"
version: 1.0.0
---

Help the user choose the right agent delegation pattern for their task.

## Arguments

- **$ARGUMENTS** (optional): Brief description of the task. If omitted, ask for clarification.

---

## Instructions

### Step 1: Understand the Task

If `$ARGUMENTS` is provided, analyze it. Otherwise, ask:

"What task do you need help with? A brief description is enough."

### Step 2: Assess Delegation Needs

Based on the task, determine:

1. **Complexity**: How many distinct steps?
2. **Independence**: Are steps independent or sequential?
3. **Collaboration**: Do agents need to discuss with each other?
4. **Approval**: Is user input needed mid-execution?

### Step 3: Present Options

Based on assessment, present the relevant options (not all options apply to every task):

**For simple tasks (1-2 steps):**
```
This task is simple enough for direct execution. I can handle it myself.
Want me to proceed?
```

**For moderate tasks (3-5 steps, independent work):**
```
I can approach this a few ways:

1. **Me doing it sequentially** - I work through each step, you see all my work
2. **Parallel sub-agents** - Multiple agents work independently, I synthesize results

Which approach do you prefer?
```

**For complex tasks where agents could benefit from discussion:**
```
I can approach this a few ways:

1. **Me doing it** - I work through everything directly
2. **Parallel sub-agents** - Agents work independently, I synthesize their results
3. **Agent Team** - Agents work together AND discuss/debate with each other

Key question: Do the agents need to challenge each other's findings?

- If YES (competing hypotheses, multiple perspectives) → Agent Team
- If NO (independent research, just need results) → Parallel sub-agents
```

**For multi-phase projects:**
```
This looks like a multi-phase project. Options:

1. **Phased workflow** (/orchestrate) - Structured phases with .development/ folder
2. **Agent Team** - Collaborative agents with shared task list
3. **Direct execution** - I work through it phase by phase

Which structure fits your needs?
```

### Step 4: Offer Approval Gates

If the task involves decisions or the user might want checkpoints:

```
Do you want approval gates mid-execution?

- **Yes** - I'll pause at key points for your input (iterative-agent-refinement)
- **No** - Proceed continuously until complete
```

### Step 5: Confirm and Proceed

Summarize the chosen approach and confirm before proceeding:

```
Configuration:
- Approach: [chosen approach]
- Agents: [number if applicable]
- Approval gates: [yes/no]

Ready to start?
```

---

## Quick Reference

| Task Type | Recommended | Why |
|-----------|-------------|-----|
| Simple edit or fix | Direct execution | Overhead exceeds benefit |
| Research 3 topics | Parallel sub-agents | Independent work, you synthesize |
| Review PR multiple angles | Agent Team | Reviewers can challenge each other |
| Build feature | /orchestrate | Distinct phases, persistent context |
| Design needing feedback | + Approval gates | User input mid-execution |

### When to use `/orchestrate` vs `/delegate`

| Situation | Command | Notes |
|-----------|---------|-------|
| Task requires decomposition + parallel execution | `/orchestrate` | Use when the work needs to be broken into a structured plan and dispatched to multiple agents across phases |
| Single delegation to one agent | `/delegate` | `/delegate` handles this directly — no need for a full pipeline |
| Task matches a team preset | `/team-spawn` or `/orchestrate` | `/delegate` can suggest either; `/team-spawn` for preset team configs, `/orchestrate` for pipeline work with a decompose plan |

**Rule of thumb:** If the task is a single clear instruction to one agent, stay in `/delegate`. If it needs decomposing into work items and executing in parallel or phases, hand off to `/orchestrate`.

---

## Related Commands

- `/orchestrate` - Initialize multi-phase workflow
- `/orchestrate --flat` - Single agent, no sub-agents

## Related Skills

- `orchestration-guide` - Full decision framework
- `multi-agent-workflows` - Phased workflow details
- `iterative-agent-refinement` - Approval gate pattern
