# ADR-004: JSONL Intermediate Format

## Status
Accepted

## Context

The knowledge-harvester funnel architecture requires passing data between stages. Each stage needs to:
- Read output from the previous stage
- Process items independently
- Write output for the next stage
- Support partial processing and recovery

Format options considered:
- **JSON array**: Single file with all items in an array
- **JSONL**: One JSON object per line
- **CSV**: Tabular format with defined columns
- **YAML**: Human-readable structured format
- **SQLite**: Embedded database

Key requirements:
- Streaming-friendly (process without loading entire file)
- Appendable (add items without rewriting)
- Debuggable (human-readable)
- Recoverable (partial processing support)
- Simple parsing (minimal dependencies)

## Decision

Use JSONL (JSON Lines) format for all intermediate stage outputs:
- One JSON object per line
- No commas between objects
- Each line is independently valid JSON
- Files named: `stage-N-{name}.jsonl`

Example Stage 4 (Extract) output:
```jsonl
{"file": "README.md", "type": "overview", "content": "Main documentation", "metadata": {...}}
{"file": "src/index.js", "type": "code", "content": "Entry point", "metadata": {...}}
{"file": "docs/api.md", "type": "api", "content": "API reference", "metadata": {...}}
```

Implementation details:
- Read with line-by-line streaming
- Write with append mode
- Parse each line independently
- Skip malformed lines with logging
- Support partial file recovery

## Consequences

### Positive
- **Streaming**: Process files line-by-line without loading all into memory
- **Appendable**: Add new items without modifying existing content
- **Parallel-friendly**: Multiple processes can write to separate files
- **Recovery**: Can resume from last successfully processed line
- **Debugging**: Each line is readable, can use `grep`, `head`, `tail`
- **Universal**: Supported by all languages and tools

### Negative
- **No schema validation**: Cannot validate entire structure at once
- **Redundancy**: Field names repeated in every object
- **Line length**: Very large objects create long lines
- **No comments**: Cannot add inline documentation
- **Relationship loss**: No explicit connections between objects

### Trade-offs Accepted
- Schema validation complexity for streaming simplicity
- Storage efficiency for processing efficiency
- Structural richness for operational robustness
