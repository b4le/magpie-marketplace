---
generated: 2026-02-26
project: .claude
pattern_types: [agent-team]
source_count: 13
---

# Agent Team Prompts

Prompts and configurations for agent teams (mesh topology with full inter-agent communication).

## Team Creation Pattern

### User Testing Team
```javascript
TeamCreate({
  team_name: "article-user-testing",
  description: "User testing team for agent orchestration article and case studies. Simulates Content Platform user/engineer walkthrough with UX research, content strategy, and PM coordination.",
  agent_type: "pm-coordinator"
})
```

### Kickoff Broadcast
```javascript
SendMessage({
  type: "broadcast",
  content: `Team kickoff for user testing session.

## Key Rules (from CLAUDE.md)
- NO "CoCaM" - use "content and catalog management team" (lowercase)
- NO "quarterly" - use "biannual" or "spring/fall"
- NO sensitive content references by name

## Your Mission
Simulate a walkthrough of the case studies as if you were:
1. A new engineer onboarding to Content Platform
2. A PM evaluating orchestration patterns

Report: What's confusing? What's missing? What needs more context?`,
  summary: "Team kickoff with rules and mission"
})
```

---

## Team Communication Patterns

### Task Assignment (Targeted Message)
```javascript
SendMessage({
  type: "message",
  recipient: "case-study-researcher-01",
  content: "Great progress! Please send me the full differentiation report with your findings and specific edit recommendations for CS-03 and CS-07.",
  summary: "Request differentiation report"
})
```

### Follow-Up Check
```javascript
SendMessage({
  type: "message",
  recipient: "case-study-researcher-01",
  content: "Did you receive Task #11 (Audit CS-01 and CS-02)? Please proceed with that audit.",
  summary: "Check task receipt"
})
```

### Shutdown Request
```javascript
SendMessage({
  type: "shutdown_request",
  recipient: "designer",
  content: "Task complete, wrapping up the session"
})
```

---

## Team Compositions

### Animation Studio Team (4 agents)
```yaml
team_name: animation-studio-v2
members:
  - team-lead: Coordination, synthesis, final decisions
  - creative-director: Vision, aesthetic direction
  - visual-designer: UI mockups, visual assets
  - animation-specialist: Motion specs, easing functions
coordination: Hierarchical (lead aggregates)
shutdown: Sequential (lead sends to all)
```

### Marketplace Audit Team (5+ agents)
```yaml
team_name: marketplace-phase3
members:
  - team-lead: Orchestration, review aggregation
  - skill-author-1: Skill creation, expert review
  - skill-author-2: Skill creation, integration review
  - qa-tester: Testing, bug identification
  - docs-writer: Documentation updates
coordination: Parallel partitioned (file ownership)
shutdown: After all reviews pass
```

### Ship V13 Team (4 agents)
```yaml
team_name: ship-v13
members:
  - team-lead: Task assignment, priority management
  - feature-eng: Feature implementation
  - ux-designer: UI/UX improvements
  - qa-tester: Post-implementation testing
coordination: Task blocking + sequential dispatch
shutdown: After QA pass
```

---

## Message Types Reference

### shutdown_request
Sent by team lead to gracefully terminate an agent.
```json
{
  "type": "shutdown_request",
  "requestId": "shutdown-1771950709666@animation-specialist",
  "from": "team-lead",
  "reason": "Session ending. Motion specs documented.",
  "timestamp": "2026-02-24T16:31:49.666Z"
}
```

### shutdown_approved
Agent acknowledges shutdown.
```json
{
  "type": "shutdown_approved",
  "requestId": "shutdown-1771950709666@animation-specialist",
  "from": "animation-specialist",
  "timestamp": "2026-02-24T16:31:49.666Z"
}
```

### idle_notification (Heartbeat)
Automatic state tracking every 30-60 seconds.
```json
{
  "type": "idle_notification",
  "from": "capability-porter-2",
  "idleReason": "available",
  "timestamp": "2026-02-24T00:43:27.549Z"
}
```

### task_assignment
Structured task delegation with dependencies.
```json
{
  "type": "task_assignment",
  "taskId": "4",
  "subject": "Commit and finalize Phase 3",
  "description": "After review fixes are complete:\n1. Stage files\n2. Create commit\n3. Verify status\n4. Report completion\n\nBlocked by: review task",
  "assignedBy": "team-lead"
}
```

---

## Coordination Sequences

### Sequence 1: Parallel Work + Aggregation
```bash
1. team-lead requests specs from all teammates in parallel
2. creative-director, visual-designer, animation-specialist work independently
3. Each sends findings back to team-lead
4. team-lead synthesizes and sends shutdown_requests
5. Each agent approves shutdown
```

### Sequence 2: Review + Correction Cycle
```bash
1. skill-author-1 and skill-author-2 create work independently
2. skill-author-1 performs expert review (identifies 19 issues)
3. skill-author-2 performs integration review (identifies 12 issues)
4. Both apply fixes in coordinated rounds
5. Final verification before shutdown
```

### Sequence 3: Task Blocking + Sequential Dispatch
```bash
1. team-lead assigns P0-1, P0-2, P0-3 with dependencies
2. feature-eng and ux-designer work in parallel
3. qa-tester performs post-implementation testing
4. Bug report triggers fix cycle
5. Shutdown after all P0s complete
```

---

## Critical Operational Details

### Context Rotation
```text
"Context rotation at 75% usage - summarize and spawn fresh teammate"

When agent approaches 100K tokens:
1. Request summary of work completed
2. Send shutdown_request
3. Spawn fresh agent with summary as context
```

### Delegate Mode
Team lead should operate in coordination-only mode:
- Use Shift+Tab to enter delegate mode
- Do NOT execute tasks directly
- Only orchestrate, synthesize, and communicate

### MCP Limitation
Background agents cannot access MCP tools (bugs #13254, #21560).
- Use `run_in_background: false` for any work requiring MCP
- Affects: Groove, Aika, code-search, Slack, Google Drive
