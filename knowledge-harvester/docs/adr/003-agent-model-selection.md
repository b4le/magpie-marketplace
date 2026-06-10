# ADR-003: Agent Model Selection

## Status
Accepted

## Context

Different stages of the knowledge-harvester funnel require different levels of reasoning capability:
- **Simple tasks** (enumerate, triage): Pattern matching, list filtering
- **Complex tasks** (extract, synthesize): Deep understanding, nuanced analysis
- **Validation tasks**: Quality checking, format verification

Claude offers multiple models with different cost/performance characteristics:
- **Haiku**: Fast, inexpensive, good for simple tasks
- **Sonnet**: Balanced performance, moderate cost, strong reasoning
- **Opus**: Highest capability, highest cost, best for complex tasks

Token costs vary by orders of magnitude between models, and the funnel architecture processes different data volumes at each stage.

## Decision

Use different models for different stages based on task complexity:

| Stage | Model | Rationale |
|-------|-------|-----------|
| 1. Enumerate | Haiku | Simple file listing, high volume |
| 2. Triage | Haiku | Pattern matching, rule application |
| 3. Harvest | None | Pure bash, no LLM needed |
| 4. Extract | Sonnet | Deep comprehension required |
| 5. Synthesize | Sonnet | Complex reasoning and writing |
| 6. Validate | Haiku | Format checking, simple verification |

Model selection criteria:
- Use Haiku for high-volume, low-complexity tasks
- Use Sonnet for tasks requiring understanding and reasoning
- Reserve Opus for user-facing interactions or critical decisions
- Use no model when deterministic logic suffices

## Consequences

### Positive
- **Cost optimization**: 70-90% cost reduction vs. using Sonnet for everything
- **Performance**: Haiku stages run 2-3x faster
- **Quality preservation**: Complex stages still get strong models
- **Scalability**: Can process larger source sets within budget
- **Flexibility**: Easy to upgrade specific stages if needed

### Negative
- **Quality variance**: Haiku may miss subtle patterns in triage
- **Integration complexity**: Different models have different prompting needs
- **Tuning overhead**: Each model requires specific prompt optimization
- **Upgrade path**: Moving between models requires prompt adjustments
- **Error patterns**: Different models fail in different ways

### Trade-offs Accepted
- Some triage accuracy for significant cost savings
- Model-specific prompt engineering for operational efficiency
- Complexity in model management for optimal resource usage
