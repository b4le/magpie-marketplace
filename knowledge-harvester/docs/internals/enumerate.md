---
name: enumerate
description: Stage 1 - Discover candidate sources from configured paths
internal: true
---

# Enumerate Stage

Discovers all candidate sources from config without reading content.

## Input
- Config JSON with sources section
- Workspace directory

## Process

### For Local Sources
1. For each local source in config:
   - Expand path (~ → $HOME)
   - Run find with depth/include/exclude
   - Collect metadata (size, mtime)
   - Get preview (first 500 chars)

### Dispatch
```text
Task(
  subagent_type="knowledge-harvester:local-enumerator",
  prompt="{source_config_json}",
  model="haiku"
)
```

## Output
Write `candidates.json`:
```json
{
  "harvest_id": "{name}-{date}",
  "generated_at": "{timestamp}",
  "candidates": [...]
}
```

## Error Handling
- Path not found → log warning, continue
- Zero candidates → abort with clear message
- Permission denied → log, skip file
