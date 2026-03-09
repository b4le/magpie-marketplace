# ADR-006: Checkpoint System Design

## Status

Accepted

## Context

The knowledge harvesting pipeline consists of 6 stages that can take significant time to complete, especially when processing large source sets:
1. Discovery
2. Extraction
3. Transformation
4. Enrichment
5. Validation
6. Storage

Each stage may process hundreds or thousands of items. If the harvest is interrupted (system crash, user cancellation, error), all work is lost and must be repeated from the beginning. This wastes computational resources and user time.

We need a checkpoint system that:
- Tracks progress within individual stages, not just between them
- Allows resuming from the last successful checkpoint
- Maintains data integrity during checkpoint writes
- Is simple to implement and debug
- Has minimal external dependencies

Various checkpoint strategies exist with different tradeoffs:
- Database-backed checkpoints (SQLite, PostgreSQL)
- Event sourcing with append-only logs
- File-based JSON/YAML checkpoints
- External stores (Redis, etcd)

## Decision

We will implement a file-based JSON checkpoint system with the following characteristics:

### Storage Format
- Checkpoints stored as JSON in `.harvest/checkpoint.json` within the workspace
- Human-readable format for easy debugging and manual intervention if needed
- Single checkpoint file per harvest (no concurrent harvest support)

### Checkpoint Contents
Each checkpoint includes:
- Current stage and progress within that stage
- Outputs from completed stages
- Item-level progress counters (processed, remaining, failed)
- Error history with retry counts
- Timestamp and version information

### Write Strategy
- Use atomic write pattern: write to `.harvest/checkpoint.json.tmp`, then rename
- Write checkpoint after each stage completion
- Optionally write intra-stage checkpoints for long-running operations
- Validate checkpoint structure before writing

### Recovery Behavior
- On startup, check for existing checkpoint
- If found and valid, offer to resume or start fresh
- If corrupted, log warning and start fresh
- Preserve old checkpoint as `.harvest/checkpoint.json.backup` when starting new harvest

## Alternatives Considered

### 1. SQLite Database
**Pros:**
- ACID guarantees
- Efficient queries for progress tracking
- Built-in transaction support

**Cons:**
- Additional dependency
- Overkill for single-run state tracking
- More complex setup and migration handling
- Less transparent for debugging

### 2. Event Sourcing
**Pros:**
- Complete audit trail of all operations
- Can replay events to any point
- Natural fit for pipeline architecture

**Cons:**
- Significant implementation complexity
- Requires event store infrastructure
- Excessive for checkpoint use case
- Harder to manually inspect/modify

### 3. No Checkpoints
**Pros:**
- Simplest implementation
- No state management complexity
- No risk of checkpoint corruption

**Cons:**
- Complete data loss on interruption
- Frustrating user experience for long harvests
- Wasted computational resources

### 4. Redis/External Store
**Pros:**
- Fast in-memory operations
- Built-in expiration
- Could share state across instances

**Cons:**
- External service dependency
- Additional deployment complexity
- Unnecessary for local file processing
- Network overhead

## Consequences

### Positive
- **Zero dependencies**: No database or external services required
- **Human-readable**: JSON format allows manual inspection and editing
- **Easy debugging**: Can examine exact state at failure point
- **Atomic writes**: Prevent corruption from partial writes
- **Simple implementation**: Standard file I/O with well-understood patterns
- **Portable**: Checkpoint travels with workspace, easy to archive

### Negative
- **No concurrent harvests**: Single checkpoint file prevents parallel runs in same workspace
- **Large checkpoint files**: Big harvests may produce multi-MB checkpoint files
- **File system dependency**: Requires writable file system (not suitable for read-only containers)
- **Manual cleanup**: Old checkpoints must be explicitly removed

### Neutral
- **Recovery granularity**: Stage-level recovery may repeat some work within a stage
- **Schema evolution**: Future checkpoint format changes require migration logic

## Implementation Notes

The checkpoint system will be implemented in `internal/checkpoint/` with:
- `Manager` interface for checkpoint operations
- `FileCheckpoint` concrete implementation
- Atomic write helper using temp file + rename
- JSON schema validation
- Backward compatibility for checkpoint format versions

Example checkpoint structure:
```json
{
  "version": "1.0",
  "harvestId": "harvest-20240115-123456",
  "timestamp": "2024-01-15T12:34:56Z",
  "currentStage": "enrichment",
  "stages": {
    "discovery": {
      "status": "completed",
      "items": ["source1.md", "source2.md"],
      "duration": "2.5s"
    },
    "extraction": {
      "status": "completed",
      "processed": 2,
      "duration": "5.3s"
    },
    "transformation": {
      "status": "completed",
      "processed": 2,
      "duration": "1.2s"
    },
    "enrichment": {
      "status": "in_progress",
      "processed": 1,
      "remaining": 1,
      "errors": []
    }
  },
  "stageOutputs": {
    "discovery": ["path/to/source1.md", "path/to/source2.md"],
    "extraction": ["extracted_data_1.json", "extracted_data_2.json"],
    "transformation": ["transformed_1.json", "transformed_2.json"]
  }
}
```
