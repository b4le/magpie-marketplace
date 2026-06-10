# Parallel Agent Coordination Example

## Scenario: Microservices API Design Research

This example demonstrates three agents running simultaneously in the research phase to investigate different aspects of microservices API design patterns.

### Why Parallel Execution?

When research topics are independent and non-overlapping, parallel execution provides:
- **3x faster completion**: All agents run simultaneously instead of sequentially
- **Better resource utilization**: Multiple research streams progress concurrently
- **Clear separation of concerns**: Each agent owns a distinct domain
- **Easy synthesis**: Non-overlapping findings combine naturally

### Task Breakdown

**Orchestrator Request**: "Research API design patterns for microservices architecture"

**Phase**: Research (all agents in parallel)

| Agent ID | Topic | Duration | Status File |
|----------|-------|----------|-------------|
| agent-001 | Security patterns (OAuth 2.1, API keys, mTLS) | 15 min | `agent-001-security-patterns.md` |
| agent-002 | Performance optimization (caching, rate limiting, pagination) | 25 min | `agent-002-performance-optimization.md` |
| agent-003 | API versioning strategies (URL, header, content negotiation) | 22 min | `agent-003-versioning-strategies.md` |

### Conflict Prevention Strategy

**Topic Isolation**: Each agent researches a distinct domain
- Agent-001: Security only
- Agent-002: Performance only
- Agent-003: Versioning only

**File Naming Convention**: `agent-{id}-{topic-slug}.md`
- Prevents write conflicts
- Clear ownership at a glance
- Easy to identify agent scope

**STATUS.yaml Coordination**:
- Tracks all active agents simultaneously
- Orchestrator monitors completion
- No agent needs to know about others

### Timeline Visualization

```
Time    | Orchestrator | Agent-001 (Security) | Agent-002 (Perf)     | Agent-003 (Versioning)
--------|--------------|----------------------|----------------------|------------------------
T+0min  | Launch 3     | [RESEARCHING...]     | [RESEARCHING...]     | [RESEARCHING...]
        | agents       |                      |                      |
T+5min  |              | OAuth 2.1 patterns   | Caching strategies   | URL vs header versions
        |              |                      |                      |
T+10min |              | mTLS investigation   | Rate limiting algos  | Content negotiation
        |              |                      |                      |
T+15min | Check STATUS | ✓ COMPLETE           | Pagination patterns  | Semver best practices
        |              |                      |                      |
T+20min |              |                      | Benchmarking data    | Deprecation policies
        |              |                      |                      |
T+22min | Check STATUS |                      | Writing summary...   | ✓ COMPLETE
        |              |                      |                      |
T+25min | Check STATUS |                      | ✓ COMPLETE           |
        |              |                      |                      |
T+30min | Synthesize → | phase-summary.md created with combined recommendations
        | Archive      |
```

**Total Time**: 30 minutes (including synthesis)
**vs Sequential**: Would take 67 minutes (15 + 25 + 22 + 5 synthesis)
**Efficiency Gain**: 2.2x faster

### Key Learning Points

1. **Parallel Task Identification**: Look for independent research domains
2. **STATUS.yaml as Coordination Hub**: Single source of truth for agent states
3. **Non-Overlapping Scopes**: Topic isolation prevents conflicts naturally
4. **File Naming**: Clear conventions enable parallel writes without coordination
5. **Synthesis Phase**: Orchestrator combines findings after all agents complete

### Example Files

```
parallel-agents/
├── README.md (this file)
├── workflow-state-initial.yaml
├── workflow-state-during.yaml
├── workflow-state-final.yaml
├── active/
│   └── research/
│       ├── README.md
│       ├── status-initial.yaml
│       ├── status-all-active.yaml
│       ├── status-partial.yaml
│       ├── status-final.yaml
│       ├── agent-001-security-patterns.md
│       ├── agent-002-performance-optimization.md
│       └── agent-003-versioning-strategies.md
└── archive/
    └── research-2025-11-24T14-30-00Z/
        └── phase-summary.md
```

### Usage

This example shows how to:
1. Decompose a broad research task into parallel sub-tasks
2. Launch multiple agents in a single orchestrator message
3. Track concurrent agent progress via STATUS.yaml
4. Prevent conflicts through topic isolation and naming conventions
5. Synthesize parallel findings into cohesive recommendations

**Next Steps**: See `phase-summary.md` for the final synthesis combining all three research streams.
