---
name: harvest
description: Orchestrate multi-source knowledge harvesting with 6-stage funnel. Use when harvesting knowledge from multiple sources, extracting patterns from codebases, or synthesizing findings into structured documents.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
version: 0.1.0
tags:
  - knowledge
  - harvesting
  - orchestration
  - synthesis
---

# Knowledge Harvester

Multi-agent system that harvests, validates, and synthesizes knowledge from multiple sources.

## Quick Start

```bash
# With config file
/harvest --config=path/to/harvest-config.json

# Quick local harvest
/harvest --sources=local:~/.claude/plugins --topic="orchestration patterns"
```

## Architecture

6-stage funnel with progressive filtering:

| Stage | Cost | Agents | Purpose |
|-------|------|--------|---------|
| 1. Enumerate | Low | 1-3 | Discover candidates |
| 2. Triage | Medium | N×lenses | Score and filter |
| 3. Harvest | **Zero** | 0 (bash) | Copy files |
| 4. Extract | High | 1/source | Analyze content |
| 5. Validate | Medium | 3-5 | Cross-check (V2) |
| 6. Synthesize | Medium | 1 | Generate output |

## Orchestration Flow

```sql
1. Parse config (JSON or CLI args)
2. Create workspace: harvest-{name}-{timestamp}/
3. For each stage:
   a. Load previous stage output
   b. Dispatch agents (parallel where safe)
   c. Collect results
   d. Write stage output
   e. Checkpoint progress
4. Generate manifest.json
5. Report results
```

**Note:** V1 implementation skips Stage 5 (Validate). Extractions flow directly from Stage 4 to Stage 6.

## Stage Dispatch

### Stage 1: Enumerate

**Enumerate stage** - discovers candidate files from configured sources.

Input: config.sources
Output: candidates.json

### Stage 2: Triage

**Triage stage** - scores and filters candidates using configurable lenses.

Input: candidates.json, config.triage
Output: ranked.json

### Stage 3: Harvest
Bash commands only (cp, rclone, curl)
Input: ranked.json (harvest decisions)
Output: sources/ directory

### Stage 4: Extract

**Extract stage** - analyzes content of harvested sources in parallel.

Input: sources/
Output: extractions.jsonl

### Stage 5: Validate (V2 - Not Yet Implemented)

> **V2 Feature:** Cross-validation with multiple agents. In V1, findings go directly from Extract to Synthesize.

**Validate stage** - cross-checks findings across multiple agents. Not yet implemented; reserved for V2.

Input: extractions.jsonl
Output: validated.jsonl

### Stage 6: Synthesize

**Synthesize stage** - generates the final output document from extracted findings.

Input: extractions.jsonl (or validated.jsonl)
Output: output/synthesis.md, manifest.json

## Checkpoint System

The harvester uses automatic checkpointing to enable resumable harvests:

### Checkpoint Location
- Default: `~/.claude/harvests/<harvest_id>/checkpoint.json`
- Working directory: `./.harvest-checkpoint.json`
- Custom: `--checkpoint-dir <path>`

### Checkpoint Contents
- Current stage (1-6)
- Stage output file paths
- Progress within current stage
- Error history
- Metadata (source directory, config, filters)

### Resume Behavior
```bash
# Auto-detect last checkpoint
/harvest --resume

# Resume specific checkpoint
/harvest --resume path/to/checkpoint.json

# Force fresh start
/harvest --fresh --no-checkpoint
```

### Checkpoint Triggers
- **Automatic:** After each stage completion
- **Interruption:** Ctrl+C saves gracefully
- **Error:** Partial checkpoint on failures
- **Manual:** `--checkpoint-now` during execution

### Schema
See `schemas/checkpoint.schema.json` for full specification.
Documentation: `docs/checkpoint-format.md`

## Error Recovery

- Ctrl+C saves checkpoint automatically
- Resume with: `/harvest --resume`
- Per-stage timeouts configurable in config.limits
- Failed stages retry from beginning on resume
- Missing output files regenerate automatically

## Output

```text
output/
├── synthesis.md      # Main synthesized document
├── manifest.json     # Full execution record
└── sources/          # Harvested raw sources
```
