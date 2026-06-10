---
name: triage
description: Stage 2 - Score and filter candidates using configurable lenses
internal: true
---

# Triage Stage

Scores each candidate and filters to top-scoring sources.

## Input
- `candidates.json` from Stage 1
- Triage config (lenses, threshold, aggregation)
- Topic string

## Process

For each candidate, for each lens:
1. Dispatch triage-scorer agent
2. Collect score + reasoning
3. If lens.amount > 1, dispatch multiple and aggregate

### Dispatch (parallel)
```text
Task(
  subagent_type="knowledge-harvester:triage-scorer",
  prompt=json.dumps({
    "candidate": candidate,
    "lens": lens,
    "topic": topic,
    "threshold": threshold
  }),
  model="haiku"
)
```

## Aggregation
1. Within lens: median/mean/min/max of agent scores
2. Across lenses: weighted average
3. Decision: harvest if combined >= threshold

## Output
Write `ranked.json` with ranked candidates and excluded list with reasons.

## Parallel Scoring

The triage stage leverages parallel execution for efficient multi-lens, multi-agent scoring:

### Parallelism Strategy
- **Per-batch parallelism:** Process 5-10 candidates simultaneously
- **Per-candidate parallelism:** All lenses scored in parallel
- **Per-lens parallelism:** Multiple scorers (if lens.amount > 1) run concurrently

### Execution Pattern
```text
for batch in batches(candidates, size=10):
    batch_tasks = []

    for candidate in batch:
        for lens in lenses:
            # Multiple scorers per lens if configured
            for i in range(lens.amount):
                task = Task(
                    subagent_type="knowledge-harvester:triage-scorer",
                    prompt={"candidate": candidate, "lens": lens, ...}
                )
                batch_tasks.append(task)

    # Execute all tasks in parallel
    results = await gather(batch_tasks, timeout=30)

    # Aggregate scores
    process_batch_results(results)
```

### Concurrency Limits
- **Maximum parallel agents:** 5-10 (depends on model)
- **Haiku model:** Up to 10 parallel scorers
- **Sonnet model:** Up to 5 parallel scorers
- **Timeout per batch:** 30 seconds

### Score Aggregation Timing
- Collect all scores for a candidate before aggregating
- Process candidates in original order (maintain ranking stability)
- Write results incrementally to avoid memory buildup

### Optimization Tips
1. **Batch size selection:**
   - Many candidates (>50): Use batch_size=10
   - Few candidates (<20): Use batch_size=5
   - Single lens: Can increase batch size to 15

2. **Lens configuration:**
   - Critical lenses: Use amount=3 for robust scoring
   - Secondary lenses: Use amount=1 to save resources

3. **Rate limit avoidance:**
   - Monitor 429 responses
   - Reduce batch size if hitting limits
   - Implement exponential backoff between batches

## Error Handling
- Agent timeout → score as 0, log warning
- >30% failures → abort (quality concern)
- Batch failure → retry with reduced parallelism
- Persistent failures → fail gracefully with partial results
