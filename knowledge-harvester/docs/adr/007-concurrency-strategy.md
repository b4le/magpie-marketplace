# ADR-007: Concurrency and Batching Strategy

## Status

Accepted

## Context

The knowledge harvesting pipeline consists of multiple stages that process source documents. Some stages (particularly triage and extraction) can process multiple items independently, presenting opportunities for parallelization. However, we must balance several competing concerns:

- **LLM API constraints**: Rate limits and per-call costs require careful management of concurrent requests
- **Resource consumption**: Memory and CPU usage scale with parallelism
- **Throughput requirements**: Users expect reasonable processing times for large document sets
- **Pipeline dependencies**: Some stages require complete results from previous stages (e.g., synthesis needs all extractions)
- **Error handling**: Parallel processing complicates error recovery and partial failure scenarios

The system must provide predictable performance while avoiding rate limit violations and cost spikes.

## Decision

We will implement a **batch-based concurrency model** with the following parameters:

### Batch Configuration
- **Batch size**: 5-10 candidates per triage agent (configurable)
- **Parallel agents**: Maximum 3-5 concurrent agents to avoid rate limiting
- **Processing pattern**: Fan-out/fan-in for parallel stages
- **Sequential stages**: Synthesize stage executes sequentially (requires global context)

### Implementation Details

1. **Triage Stage**
   - Divide candidate sources into batches of 5-10 items
   - Spawn up to 5 parallel agents, each processing one batch
   - Collect results as agents complete
   - Merge results with timestamp-based ordering

2. **Extraction Stage**
   - Process accepted sources from triage in batches
   - Same parallel agent limits (3-5 agents)
   - Each agent processes its batch independently
   - Results merged into extraction store

3. **Synthesis Stage**
   - Executes sequentially after all extractions complete
   - Single agent with access to complete extraction set
   - No parallelization to maintain coherent synthesis

4. **Result Merging**
   - Timestamp-based ordering for deterministic results
   - Deduplication by source identifier
   - Preserve extraction metadata for traceability

### Configuration Schema
```yaml
concurrency:
  batch_size: 10          # Items per batch
  max_parallel_agents: 5  # Maximum concurrent agents
  rate_limit_delay: 100   # Milliseconds between API calls
  timeout_per_batch: 300  # Seconds before batch timeout
```

## Alternatives Considered

### 1. No Parallelism
**Description**: Process all sources sequentially through each stage.

**Pros**:
- Simplest implementation
- Predictable resource usage
- Easy debugging and error handling

**Cons**:
- 5-10x slower for large harvests
- Poor user experience for bulk processing
- Underutilizes available compute resources

### 2. Unlimited Parallelism
**Description**: Process all sources in parallel without limits.

**Pros**:
- Maximum theoretical throughput
- Minimal processing time

**Cons**:
- Guaranteed rate limit violations
- Unpredictable cost spikes
- Resource exhaustion risk
- Complex error recovery

### 3. Work-Stealing Queue
**Description**: Dynamic work distribution with agents claiming tasks from shared queue.

**Pros**:
- Optimal load balancing
- Handles heterogeneous workloads well

**Cons**:
- Complex implementation
- Marginal benefit over batch approach
- Harder to reason about performance
- More difficult testing

### 4. Fixed Thread Pool
**Description**: Pre-allocated worker threads processing from shared queue.

**Pros**:
- Standard concurrency pattern
- Good resource control

**Cons**:
- Less flexible than batch-based approach
- Harder to tune for varying workloads
- Thread management overhead

## Consequences

### Positive

- **Predictable resource usage**: Fixed upper bounds on concurrent operations
- **Rate limit compliance**: Controlled parallelism avoids API violations
- **Tunable performance**: Batch size easily adjusted based on empirical data
- **Simple mental model**: Batch processing is easy to understand and debug
- **Graceful degradation**: Can reduce parallelism under load without code changes
- **Cost control**: Predictable API call patterns prevent billing surprises

### Negative

- **Suboptimal for edge cases**: Very small harvests have unnecessary overhead; very large harvests could use more parallelism
- **Batch boundary inefficiency**: Natural data groupings may not align with batch boundaries
- **Latency for small requests**: Batch collection adds minimal delay even for single items
- **Complex failure handling**: Partial batch failures require careful state management
- **Memory overhead**: Multiple agents hold intermediate results simultaneously

### Mitigation Strategies

1. **Dynamic batch sizing**: Adjust batch size based on total item count
2. **Adaptive parallelism**: Scale agents based on current rate limit headroom
3. **Smart batching**: Group related sources in same batch when possible
4. **Incremental processing**: Stream results as batches complete rather than waiting for all

## Implementation Notes

The concurrency strategy will be implemented in the orchestrator module, with configuration exposed through the plugin's settings file. Monitoring and metrics will track:

- Average batch processing time
- Rate limit proximity
- Resource utilization per agent
- Queue depths at each stage

Future iterations may introduce more sophisticated scheduling based on observed performance characteristics.
