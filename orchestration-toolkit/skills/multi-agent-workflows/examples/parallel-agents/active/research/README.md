# Research Phase: Microservices API Design Patterns

## Objective

Investigate best practices and design patterns for building robust, scalable microservices APIs across three critical domains:
1. Security patterns
2. Performance optimization
3. API versioning strategies

## Parallel Agent Strategy

This phase uses **3 independent agents running simultaneously** to maximize efficiency.

### Agent Assignments

| Agent | Research Domain | Output File | Scope |
|-------|----------------|-------------|-------|
| agent-001 | Security Patterns | `agent-001-security-patterns.md` | OAuth 2.1, API keys, mTLS, JWT, authorization |
| agent-002 | Performance Optimization | `agent-002-performance-optimization.md` | Caching, rate limiting, pagination, compression |
| agent-003 | Versioning Strategies | `agent-003-versioning-strategies.md` | URL versioning, header versioning, content negotiation |

### Conflict Prevention

**Topic Isolation**: Each agent has exclusive responsibility for their domain
- No overlapping research areas
- Clear boundaries between security, performance, and versioning
- Findings will be complementary, not redundant

**File Naming**: Unique output files per agent
- Pattern: `agent-{id}-{topic-slug}.md`
- No risk of concurrent write conflicts
- Clear ownership and traceability

**Independent Execution**: Agents don't need to communicate
- Each researches independently
- Orchestrator handles synthesis after all complete
- STATUS.yaml tracks progress centrally

## Coordination via STATUS.yaml

The `STATUS.yaml` file tracks all agent states:
- `active_agents`: Currently running agents
- `completed_agents`: Finished agents
- `pending_agents`: Not yet started

Orchestrator monitors STATUS.yaml to:
- Know when all agents have completed
- Identify any blocked or failed agents
- Trigger synthesis phase when all research complete

## Research Quality Guidelines

Each agent should provide:
- **Pattern descriptions**: What the pattern is and when to use it
- **Implementation examples**: Code snippets or architectural diagrams
- **Pros and cons**: Trade-offs and considerations
- **Best practices**: Industry-standard recommendations
- **Common pitfalls**: What to avoid
- **Real-world examples**: How major APIs implement these patterns

## Expected Timeline

- **T+0min**: All agents launch simultaneously
- **T+15min**: First agent completes (varies by research complexity)
- **T+25min**: All agents complete
- **T+30min**: Orchestrator synthesizes findings → `phase-summary.md`

## Success Criteria

- [ ] All 3 agents complete without conflicts
- [ ] Each output file contains unique, non-overlapping content
- [ ] Findings are comprehensive and actionable
- [ ] Combined recommendations form cohesive API design guide
- [ ] No duplicate research between agents

## Next Phase

After all agents complete, orchestrator will:
1. Read all 3 output files
2. Synthesize findings into `phase-summary.md`
3. Archive research phase outputs
4. Present unified recommendations to user
