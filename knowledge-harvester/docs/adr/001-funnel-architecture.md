# ADR-001: Funnel Architecture

## Status
Accepted

## Context

The knowledge-harvester plugin needs to process potentially large numbers of source files and directories across multiple repositories and documentation sources. A naive approach of processing everything with LLMs would be prohibitively expensive in terms of token usage and processing time.

Key challenges:
- Source enumeration can yield thousands of files
- Most files may not contain relevant knowledge
- Different processing stages require different levels of intelligence
- Token costs scale linearly with content processed
- Need to maintain quality while optimizing for cost

## Decision

Implement a 6-stage progressive filtering architecture that narrows down content at each stage:

1. **Enumerate** - List all potential sources (low intelligence, haiku model)
2. **Triage** - Filter to relevant sources only (medium intelligence, haiku model)
3. **Harvest** - Copy selected files locally (no LLM, pure bash)
4. **Extract** - Pull knowledge from files (high intelligence, sonnet model)
5. **Synthesize** - Combine into final format (high intelligence, sonnet model)
6. **Validate** - Quality check output (medium intelligence, haiku model)

Each stage reduces the data volume for the next stage, creating a "funnel" effect where expensive operations only run on pre-filtered, relevant content.

## Consequences

### Positive
- **Cost optimization**: Token usage scales with relevance, not raw volume
- **Clear boundaries**: Each stage has a single responsibility
- **Parallel processing**: Stages can be optimized independently
- **Debugging**: Easy to inspect intermediate outputs at each stage
- **Flexibility**: Stages can use different models based on task complexity

### Negative
- **Complexity**: More moving parts than a single-pass approach
- **Coordination overhead**: Managing data flow between stages
- **Storage requirements**: Intermediate files need temporary storage
- **Error propagation**: Mistakes in early stages affect all downstream processing
- **Development effort**: Each stage needs separate implementation and testing

### Trade-offs Accepted
- Architectural complexity for operational efficiency
- Multiple processing passes for reduced token costs
- Intermediate storage for better observability
