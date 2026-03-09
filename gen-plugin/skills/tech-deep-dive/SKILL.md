---
name: tech-deep-dive
description: Generate engineering-depth technical analysis. Use when documenting architecture, analyzing trade-offs, writing RFCs, or explaining systems to engineers.
version: 1.0.0
created: 2026-02-24
last_updated: 2026-02-24
---

# Technical Deep Dive Generator

Generate comprehensive technical analysis for engineering audiences.

## When to Use

- Documenting architectural decisions
- Analyzing implementation trade-offs
- Creating technical RFCs or design docs
- Explaining complex systems to engineers

## When NOT to Use

- **Non-technical audience**: Use `/gen:exec-brief` instead — leadership needs business impact, not code
- **Quick questions**: Just answer directly — not everything needs formal analysis
- **Brainstorming**: Use `/mode:creative` mode — deep dives are for analysis, not ideation
- **Presenting verbally**: Use `/gen:talking-points` — deep dives are reference docs, not speeches

## Output Format

**ALWAYS structure tech deep-dives like this:**

```
## Technical Analysis: [Topic]

**TL;DR:** [1-2 sentence summary for quick scanning]

### Context

[Background, constraints, and why this analysis matters]

### Implementation

```[language]
[Relevant code, pseudocode, or configuration]
```

### Trade-offs

| Consideration | This Approach | Alternative |
|--------------|---------------|-------------|
| Performance  | [X]           | [Y]         |
| Complexity   | [X]           | [Y]         |
| Maintenance  | [X]           | [Y]         |
| Scalability  | [X]           | [Y]         |

### Recommendation

[Clear statement of what to do and why]

### References

- [Link to relevant docs/code]
- [Related prior decisions]
```

## Constraints

- **Include code** — engineers want to see implementation details
- **Quantify trade-offs** — "2x faster" not "faster"
- **Link to sources** — reference relevant files, docs, or discussions
- **Consider alternatives** — always present at least one other approach

## Example

```
## Technical Analysis: Caching Strategy for User Profiles

**TL;DR:** Redis with 5-minute TTL balances freshness with load reduction.

### Context

User profile fetches account for 40% of database load. We need caching that handles 10K req/s with <100ms p99 latency.

### Implementation

```python
@cached(ttl=300, backend='redis')
async def get_user_profile(user_id: str) -> UserProfile:
    return await db.users.find_one({'_id': user_id})
```

### Trade-offs

| Consideration | Redis (recommended) | Local LRU | No cache |
|--------------|---------------------|-----------|----------|
| Latency p99  | 5ms                 | 1ms       | 50ms     |
| Consistency  | 5 min stale         | Instance-local | Always fresh |
| Complexity   | Medium              | Low       | None     |
| Cost         | $200/mo             | $0        | $0       |

### Recommendation

Use Redis with 5-minute TTL. The staleness window is acceptable for profile data, and cross-instance consistency is critical for our deployment model.

### References

- [Caching ADR](docs/adr/003-caching.md)
- [Redis config](infra/redis/config.yaml)
```

## Related Skills

| Skill | When to Use Instead |
|-------|---------------------|
| `/gen:exec-brief` | Non-technical audience, focus on business impact |
| `/gen:talking-points` | Preparing to present findings verbally |
| `/mode:creative` mode | Still exploring options before analysis |

Part of the **gen-plugin** output style system.

## Version History

### v1.0.0 (2026-02-24)
- Initial release with technical analysis format
- Added "When NOT to Use" guidance
- Added related skills cross-references
