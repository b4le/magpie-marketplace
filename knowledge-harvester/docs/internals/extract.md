---
name: extract
description: Stage 4 - Extract structured findings from harvested sources
internal: true
---

# Extract Stage

Dispatches extractor agents to analyze each harvested source.

## Input
- `sources/` directory from Stage 3
- Topic string
- Token budget

## Process

For each file in sources/:
1. Check file size vs token budget
2. If too large, truncate with warning
3. Dispatch extractor agent

### Dispatch (parallel, batch of 5)
```text
Task(
  subagent_type="knowledge-harvester:extractor",
  prompt=json.dumps({
    "source_path": file_path,
    "topic": topic,
    "max_findings": 10
  }),
  model="sonnet"
)
```

## Output
Append to `extractions.jsonl` (one line per source).

## Batching

The extract stage processes sources in batches to optimize throughput while managing memory usage:

### Configuration
- **Default batch size:** 5 sources
- **Memory-aware scaling:** Reduce batch size if available memory < 1GB
- **Token budget distribution:** Divide total budget equally across batch

### Implementation
```text
for batch in batches(sources, size=5):
    # Parallel dispatch within batch
    tasks = [
        Task(subagent_type="knowledge-harvester:extractor", ...)
        for source in batch
    ]

    # Collect results
    results = await gather(tasks)

    # Stream to output (avoid memory buildup)
    for result in results:
        append_to_jsonl("extractions.jsonl", result)

    # Optional checkpoint
    save_checkpoint(batch_end_index)
```

### Batch Size Tuning
- Small sources (<1000 tokens): batch_size = 8
- Medium sources (1000-5000 tokens): batch_size = 5
- Large sources (>5000 tokens): batch_size = 3

### Memory Management
- Monitor memory before each batch
- Reduce batch size dynamically if memory pressure detected
- Stream output to JSONL instead of accumulating in memory

## Error Handling
- Token budget exceeded → truncate, warn
- Malformed output → retry 1x, then skip
- Empty findings → log, continue
- Batch failure (>50% agents fail) → retry batch with size=1
