---
name: harvest
description: Run knowledge harvesting pipeline
arguments:
  - name: config
    description: Path to harvest config JSON
    required: false
  - name: sources
    description: Quick source spec (type:path)
    required: false
  - name: topic
    description: Topic for triage relevance
    required: false
  - name: resume
    description: Resume from last checkpoint
    type: boolean
    required: false
  - name: workspace
    description: Workspace directory (default .harvest)
    required: false
---

# /harvest Command

Runs the knowledge harvesting pipeline.

## Usage

```bash
# With config file
/harvest --config=./my-harvest.json

# Quick mode (local only)
/harvest --sources=local:~/docs --topic="API patterns"

# Resume interrupted harvest
/harvest --resume

# Custom workspace
/harvest --config=./config.json --workspace=./my-harvest
```

## Pipeline Stages

The harvest command runs 6 stages:

1. **Enumerate** - Discover candidate files from configured sources
2. **Triage** - Score candidates and decide include/exclude/review
3. **Harvest** - Copy included files to workspace (zero LLM cost)
4. **Extract** - Extract findings from harvested content
5. **Synthesize** - Generate knowledge synthesis document
6. **Complete** - Validate and finalize outputs

## Behavior

1. **If `--resume`**: Load checkpoint, continue from last completed stage
2. **If `--config`**: Validate JSON against schema, use full configuration
3. **If `--sources`**: Build minimal config from CLI arguments
4. Run orchestrator through all 6 stages with checkpointing

## Quick Mode Defaults

When using `--sources` without full config:
- depth: 2
- include: ["*.md", "*.txt", "*.yaml"]
- exclude: ["node_modules", ".git", "__pycache__", ".DS_Store"]
- triage.threshold: 7
- triage.aggregation: "weighted_average"
- limits.max_candidates: 100
- limits.max_sources_harvested: 20

## Output Structure

```text
.harvest/
├── checkpoint.json       # Resume state
├── candidates.json       # Stage 1 output
├── ranked.json           # Stage 2 output
├── manifest.json         # Stage 3 output
├── extractions.jsonl     # Stage 4 output
├── sources/              # Harvested files
│   └── local-001/
│       └── file.md
└── output/
    ├── knowledge.md      # Final synthesis
    ├── synthesis.json    # Structured synthesis
    └── summary.json      # Harvest summary
```

## Example Config

```json
{
  "version": "1.0.0",
  "name": "my-knowledge-harvest",
  "description": "Harvest knowledge from project docs",
  "sources": {
    "local": [{
      "path": "~/projects/myapp/docs",
      "depth": 3,
      "include": ["*.md"],
      "exclude": ["node_modules", ".git"]
    }]
  },
  "triage": {
    "lenses": ["relevance", "freshness", "authority"],
    "threshold": 7,
    "aggregation": "weighted_average"
  },
  "limits": {
    "max_candidates": 100,
    "max_sources_harvested": 20
  }
}
```

## Execution

When invoked, the command:

1. Parses arguments and builds/loads configuration
2. Validates config against `schemas/harvest-config.schema.json`
3. Creates `HarvestOrchestrator` instance
4. Runs `orchestrator.run(resume=<resume_flag>)`
5. Reports progress and final output location

## Python API

```python
from lib.orchestrator import run_harvest

config = {
    "version": "1.0.0",
    "name": "api-harvest",
    "sources": {"local": [{"path": "~/docs"}]}
}

summary = run_harvest(config, workspace=".harvest", resume=False)
print(f"Output: {summary['outputs']['synthesis']}")
```
