---
name: synthesize
description: Stage 6 - Generate final synthesized document
internal: true
---

# Synthesize Stage

Creates the final output document from extracted findings.

## Input
- `extractions.jsonl` (or `validated.jsonl` in V2)
- Topic and goal
- Template file

## Process

1. Load all findings from JSONL
2. Dispatch synthesizer agent with full context

### Dispatch
```text
Task(
  subagent_type="knowledge-harvester:synthesizer",
  prompt=json.dumps({
    "findings_path": "extractions.jsonl",
    "topic": topic,
    "template_path": "templates/synthesis.md.hbs",
    "output_path": "output/synthesis.md"
  }),
  model="sonnet"
)
```

## Output
Write to `output/`:
- synthesis.md (main document)
- manifest.json (execution record)
- sources/ (copy of harvested sources)

## Error Handling
- Empty findings → generate minimal report
- Synthesis too long → chunk into sections
