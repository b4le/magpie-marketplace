---
generated: 2026-02-26
project: .claude
pattern_types: [decision-framework, topology, workflow]
source_count: 66
---

# Orchestration Patterns

Decision frameworks, topology diagrams, and workflow patterns for Claude Code orchestration.

## Decision Framework

### Quick Decision Tree
```text
1-2 steps        → Direct execution (Bash, Read, Edit)
3+ independent   → Subagents (Task tool)
Agents discuss   → Agent Teams (experimental)
```

### Full Decision Flow
```bash
START: Task received
│
├─ Q1: Can I do this in 1-2 tool calls?
│   ├─ YES → Direct execution
│   └─ NO → Q2
│
├─ Q2: Are the subtasks independent?
│   ├─ YES → Q3
│   └─ NO (sequential dependencies) → Single subagent OR direct execution
│
├─ Q3: Do I need results before proceeding?
│   ├─ YES → Foreground subagents (run_in_background: false)
│   └─ NO → Background subagents (run_in_background: true)
│
├─ Q4: Do agents need to discuss/debate?
│   ├─ YES → Agent Teams
│   └─ NO → Parallel subagents with me bridging results
│
└─ Q5: How complex is coordination?
    ├─ Simple (1-3 agents) → Star topology
    ├─ Medium (4-6 agents) → Star with task list
    └─ Complex (7+ agents) → Phased workflows
```

---

## Topology Diagrams

### Star Topology (Subagents)
```bash
                    ┌─────────────┐
                    │  Orchestrator│
                    │   (Main)     │
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Subagent │    │ Subagent │    │ Subagent │
    │    A     │    │    B     │    │    C     │
    └──────────┘    └──────────┘    └──────────┘

    - No inter-agent communication
    - Results flow back to orchestrator
    - Lower token cost
    - Best for: parallel research, reviews, audits
```

### Mesh Topology (Agent Teams)
```bash
    ┌──────────┐         ┌──────────┐
    │  Agent   │◄───────►│  Agent   │
    │    A     │         │    B     │
    └────┬─────┘         └────┬─────┘
         │                    │
         │    ┌──────────┐    │
         └───►│  Agent   │◄───┘
              │    C     │
              └──────────┘

    - Full inter-agent messaging
    - Persistent team context
    - Higher token cost (N contexts)
    - Best for: debate, user testing, complex coordination
```

### Hierarchical Topology
```bash
                    ┌──────────┐
                    │  Lead    │
                    └────┬─────┘
                         │
              ┌──────────┼──────────┐
              │          │          │
              ▼          ▼          ▼
         ┌────────┐ ┌────────┐ ┌────────┐
         │Specialist│ │Specialist│ │Specialist│
         │    A    │ │    B    │ │    C    │
         └────────┘ └────────┘ └────────┘

    - Lead aggregates specialist reports
    - Specialists work independently
    - Lead synthesizes findings
    - Best for: expert reviews, audits
```

---

## Workflow Patterns

### Pattern: Parallel-then-Synthesize
```bash
Phase 1: Launch N agents in parallel
         ┌───────────────────────────┐
         │ Task() Task() Task() ...  │ ← Single message, multiple calls
         └───────────────────────────┘
                      │
Phase 2: Wait for all to complete
         ┌───────────────────────────┐
         │ run_in_background: false  │ ← Blocks until done
         └───────────────────────────┘
                      │
Phase 3: Synthesize findings
         ┌───────────────────────────┐
         │ Read all agent outputs    │
         │ Identify themes           │
         │ Resolve conflicts         │
         │ Produce unified result    │
         └───────────────────────────┘
```

### Pattern: Sequential Role Pipeline
```text
┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
│Analyst │───►│Creator │───►│Reviewer│───►│ Editor │
└────────┘    └────────┘    └────────┘    └────────┘
     │             │             │             │
     ▼             ▼             ▼             ▼
  Inventory    Content      Security      Polished
  + Findings   Draft        Report        Output
```

### Pattern: Phased with Checkpoints
```text
┌─────────┐     ┌──────────┐     ┌───────────┐
│ Phase 1 │────►│Checkpoint│────►│  Phase 2  │
│ (Auto)  │     │ (User)   │     │  (Auto)   │
└─────────┘     └──────────┘     └───────────┘
     │               │                 │
     ▼               ▼                 ▼
  Findings      Approval          Implementation
  + Questions   + Guidance        + Deliverables
```

---

## Task List Coordination

### Creating Tasks with Dependencies
```javascript
TaskCreate({
  subject: "Implement feature A",
  description: "...",
  owner: "agent-1"
})
// Returns taskId: "1"

TaskCreate({
  subject: "Test feature A",
  description: "...",
  addBlockedBy: ["1"]  // Blocked until task 1 completes
})
```

### Task Status Updates
```javascript
// Start work
TaskUpdate({ taskId: "1", status: "in_progress" })

// Complete work
TaskUpdate({ taskId: "1", status: "completed" })

// Check for next task
TaskList()  // Returns available tasks
```

---

## State Persistence Patterns

### File-Based State (Crash-Resilient)
```yaml
# STATUS.yaml
workflow_id: notification-system-20251124
status: execution
current_phase:
  name: execution
  progress_percent: 50
active_agents:
  - id: agent-004-backend-services
    status: in-progress
work_completed:
  - websocket-service.md
  - push-notification-service.md
work_in_progress:
  - email-service-INCOMPLETE.md
work_pending:
  - sms-service-TODO.md
```

### Filename Conventions
```text
file.md              → Complete
file-INCOMPLETE.md   → Partial (resume here)
file-TODO.md         → Not started (placeholder)
```

---

## Cost Analysis

### Token Cost by Pattern
```text
Pattern              │ Agents │ Context Windows │ Relative Cost
─────────────────────┼────────┼─────────────────┼──────────────
Direct execution     │ 0      │ 1 (main)        │ 1x
Single subagent      │ 1      │ 2               │ 2x
Parallel subagents   │ N      │ N+1             │ (N+1)x
Agent team           │ N      │ N+1             │ (N+1)x + messaging
```

### When to Use Each
```text
Token Budget Tight:
  → Fewer agents, more direct execution
  → Sequential over parallel
  → Summarize aggressively

Token Budget Available:
  → More parallel agents
  → Specialist subagent types
  → Thorough exploration
```

---

## Anti-Patterns

### DON'T: Sleep/Poll for Completion
```javascript
// WRONG
Task({ ..., run_in_background: true })
Bash("sleep 30")  // Wasteful!
// Check if done somehow
```

```javascript
// RIGHT
Task({ ..., run_in_background: false })  // Blocks until done
// Continue with results
```

### DON'T: Parallel Dependent Tasks
```javascript
// WRONG - race condition
Task({ description: "Create database schema" })
Task({ description: "Insert seed data" })  // May run before schema!
```

```javascript
// RIGHT - sequential
Task({ description: "Create database schema" })  // Wait
Task({ description: "Insert seed data" })         // Then this
```

### DON'T: Over-Orchestrate
```text
Simple task (2 files, clear action)
  → Direct execution, NOT subagents

Complex research (10+ files, uncertain scope)
  → Subagents appropriate
```

---

## Operational Practices

### Context Rotation Threshold
```text
At 75% context (approx 100K tokens):
1. Request work summary from agent
2. Send shutdown_request
3. Spawn fresh agent with summary
```

### Parallel Launch Syntax
```javascript
// Single message, multiple Task calls = parallel execution
Task({ description: "Research A", subagent_type: "Explore" })
Task({ description: "Research B", subagent_type: "Explore" })
Task({ description: "Research C", subagent_type: "Explore" })
// All three launch simultaneously
```

### MCP Tool Limitation
```bash
Background agents CANNOT access MCP tools.

Affected: Groove, Aika, code-search, Slack, Google Drive

Solution: Use run_in_background: false for MCP-dependent work
```
