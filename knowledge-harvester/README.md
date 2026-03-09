# Knowledge Harvester

> Multi-agent knowledge harvesting pipeline that discovers, scores, and synthesizes knowledge from local files.

**Version:** 0.1.0

Knowledge Harvester is a Claude Code plugin that implements a 6-stage funnel pipeline for automated knowledge extraction. It discovers candidate sources, scores them using configurable triage lenses, harvests relevant files with zero LLM cost, extracts validated findings in parallel, and synthesizes the results into a comprehensive knowledge document. The pipeline supports checkpoint/resume for interrupted harvests and enforces security-first input validation throughout.

## Features

- **6-Stage Funnel Pipeline**: Enumerate, Triage, Harvest, Extract, Synthesize, Complete
- **Checkpoint/Resume**: Automatically saves progress; resume interrupted harvests with `--resume`
- **Parallel Extraction**: ThreadPoolExecutor with configurable workers (default: 5)
- **Security-First**: Path traversal prevention, command injection blocking, Unicode attack mitigation
- **Zero LLM Cost Harvesting**: Stage 3 uses bash-only file operations
- **JSON Schema Validation**: Validated inputs/outputs at each pipeline stage
- **Configurable Triage**: 5 scoring lenses with multiple aggregation methods
- **Comprehensive Test Plan**: Security, integration, E2E, and performance test coverage (planned)

## Quick Start

```bash
# Harvest from a local directory with a topic filter
/harvest --sources=local:~/docs --topic="orchestration patterns"

# Use a configuration file
/harvest --config=./harvest-config.json

# Resume an interrupted harvest
/harvest --resume
```

## Skills

| Skill | Description | Invoke |
|-------|-------------|--------|
| `harvest` | Run knowledge harvesting pipeline | `/knowledge-harvester:harvest` |

## Commands

| Command | Description | Invoke |
|---------|-------------|--------|
| `harvest` | CLI entry point for harvest pipeline | `/harvest` |

## Installation

### Via Marketplace

```bash
claude plugin install knowledge-harvester@content-platform-marketplace
```

### Manual Installation

Clone or copy the plugin directory into `~/.claude/plugins/knowledge-harvester/` and ensure `plugin.json` is present. The plugin registers the `harvest` skill, the `/harvest` command, and four agents: `local-enumerator`, `triage-scorer`, `extractor`, and `synthesizer`.

## Architecture

```text
                    +------------------+
                    |  Configuration   |
                    |  (JSON/CLI args) |
                    +--------+---------+
                             |
                             v
+----------------------------------------------------------------------------+
|                           PIPELINE STAGES                                  |
+----------------------------------------------------------------------------+
|                                                                            |
|  Stage 1: ENUMERATE          Stage 2: TRIAGE           Stage 3: HARVEST   |
|  +------------------+        +------------------+      +------------------+|
|  | os.walk          |        | Score candidates |      | bash cp/copy    ||
|  | Pattern matching | -----> | 5 lenses         | ---> | Zero LLM cost   ||
|  | candidates.json  |        | ranked.json      |      | manifest.json   ||
|  +------------------+        +------------------+      +------------------+|
|         |                           |                         |            |
|         | Low cost                  | Medium cost             | Zero cost  |
|                                                                            |
|  Stage 4: EXTRACT            Stage 5: SYNTHESIZE       Stage 6: COMPLETE  |
|  +------------------+        +------------------+      +------------------+|
|  | Parallel workers |        | Generate output  |      | Finalize        ||
|  | ThreadPoolExec   | -----> | Categorize       | ---> | Summary JSON    ||
|  | extractions.jsonl|        | knowledge.md     |      | summary.json    ||
|  +------------------+        +------------------+      +------------------+|
|         |                           |                         |            |
|         | High cost                 | Medium cost             | Low cost   |
|                                                                            |
+----------------------------------------------------------------------------+
                             |
                             v
                    +------------------+
                    |    Checkpoint    |
                    | (checkpoint.json)|
                    +------------------+
```

## Output Structure

```bash
.harvest/
├── checkpoint.json        # Pipeline state for resume
├── candidates.json        # Stage 1 output: discovered files
├── ranked.json            # Stage 2 output: scored candidates
├── manifest.json          # Stage 3 output: harvest record
├── extractions.jsonl      # Stage 4 output: extracted findings
├── sources/               # Harvested source files
│   └── {id}/
│       └── {filename}
└── output/
    ├── knowledge.md       # Final synthesized document
    ├── synthesis.json     # Structured synthesis data
    └── summary.json       # Harvest summary
```

## Configuration

### Configuration File Example

```json
{
  "version": "1.0.0",
  "name": "my-harvest",
  "description": "Extract orchestration patterns from docs",
  "sources": {
    "local": [
      {
        "path": "~/docs",
        "depth": 3,
        "include": ["*.md", "*.txt"],
        "exclude": ["node_modules", ".git"]
      }
    ]
  },
  "triage": {
    "lenses": ["relevance", "freshness", "authority", "depth", "uniqueness"],
    "threshold": 7,
    "aggregation": "weighted_average"
  },
  "limits": {
    "max_candidates": 100,
    "max_sources_harvested": 20,
    "max_tokens_per_source": 50000,
    "timeout_minutes": 30
  }
}
```

### Configuration Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `version` | string | `"1.0.0"` | Schema version (semver) |
| `name` | string | required | Unique harvest name |
| `description` | string | - | Human-readable description |
| `sources.local[].path` | string | required | Directory path (supports `~`) |
| `sources.local[].depth` | int | `3` | Max traversal depth |
| `sources.local[].include` | array | `[]` | Glob patterns to include |
| `sources.local[].exclude` | array | `[]` | Glob patterns to exclude |
| `triage.lenses` | array | `["relevance"]` | Scoring lenses to apply |
| `triage.threshold` | int | `7` | Min score for inclusion (0-10) |
| `triage.aggregation` | string | `"weighted_average"` | Score aggregation method |
| `limits.max_candidates` | int | `100` | Max candidates to enumerate |
| `limits.max_sources_harvested` | int | `20` | Max sources after triage |
| `limits.max_tokens_per_source` | int | `50000` | Token limit per source |
| `limits.timeout_minutes` | int | `30` | Pipeline timeout |

### Triage Scoring

**Lenses** (each scores 0-10):
| Lens | Weight | Description |
|------|--------|-------------|
| `relevance` | 0.30 | Topic relevance to harvest goal |
| `freshness` | 0.20 | Recency of content |
| `authority` | 0.20 | Source credibility |
| `depth` | 0.15 | Content depth/detail |
| `uniqueness` | 0.15 | Non-duplicate content |

**Aggregation Methods**:
- `weighted_average` - Weighted sum using lens weights (default)
- `minimum` - Use lowest lens score
- `maximum` - Use highest lens score
- `product` - Multiply normalized scores

**Triage Decisions**:
- `include`: score >= threshold
- `review`: threshold-1 <= score < threshold
- `exclude`: score < threshold-1

## Python API

```python
from lib.orchestrator import run_harvest, HarvestOrchestrator

# Simple usage
config = {
    "version": "1.0.0",
    "name": "api-harvest",
    "sources": {
        "local": [{"path": "~/docs", "include": ["*.md"]}]
    }
}
summary = run_harvest(config, workspace=".harvest")

# Advanced usage with orchestrator
orchestrator = HarvestOrchestrator(config, workspace_dir=".harvest")
orchestrator.setup_workspace()

# Run individual stages
candidates = orchestrator.run_enumerate()
ranked = orchestrator.run_triage(candidates)
manifest = orchestrator.run_harvest(ranked)
findings = orchestrator.run_extract(manifest, ranked)
synthesis = orchestrator.run_synthesize(findings, ranked)
summary = orchestrator.run_complete()
```

### Checkpoint Manager

```python
from lib.checkpoint import CheckpointManager

# Load existing checkpoint
manager = CheckpointManager(workspace=".harvest", harvest_id="abc-123")
if manager.load():
    print(f"Resuming from stage {manager.current_stage}")

# Check stage completion
if manager.is_stage_complete(2):
    print("Triage already done")

# Record progress
manager.record_stage_start(3)
manager.record_stage_complete(3, output_path="manifest.json")
manager.save()
```

## Security

Knowledge Harvester implements defense-in-depth security measures:

### Input Validation (`lib/sanitize.py`)

| Function | Purpose |
|----------|---------|
| `sanitize_path()` | Canonicalize paths, block traversal attacks |
| `validate_glob_pattern()` | Ensure glob patterns are shell-safe |
| `quote_for_shell()` | POSIX-compliant shell argument quoting |

### Protection Against

- **Path Traversal** (CWE-22): Resolves `../`, symlinks to absolute paths
- **Command Injection** (CWE-78): Blocks shell metacharacters (`;|&$\``)
- **Null Byte Injection**: Rejects `\x00` in all inputs
- **Unicode Attacks**: Blocks bidirectional text overrides (RLO, LRO)
- **Variable Expansion**: Prevents `${}` and `$()` patterns

### Usage Example

```python
from lib.sanitize import sanitize_path, quote_for_shell

# Safe path handling
safe_path = sanitize_path(user_input)  # Raises ValueError if dangerous

# Safe shell command construction
safe_arg = quote_for_shell(user_input)
cmd = f"find {safe_arg} -type f"
```

For comprehensive security documentation, see [`docs/security.md`](docs/security.md).

## Testing

The planned test suite covers 13 test files:

| Test File | Coverage |
|-----------|----------|
| `test_sanitize.py` | Input validation, injection prevention |
| `test_security.py` | Security edge cases |
| `test_enumerate_local.py` | File discovery |
| `test_triage_scoring.py` | Scoring and decisions |
| `test_extract.py` | Finding extraction |
| `test_synthesize.py` | Synthesis generation |
| `test_orchestrator.py` | Pipeline orchestration |
| `test_checkpoint_schema.py` | Checkpoint validation |
| `test_config_schema.py` | Config validation |
| `test_stage_contracts.py` | Stage I/O contracts |
| `test_agent_behaviors.py` | Agent behavior verification |
| `test_integration.py` | Cross-stage integration |
| `test_e2e_pipeline.py` | Full pipeline E2E |
| `test_performance.py` | Performance benchmarks |

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=lib --cov-report=html

# Run specific test file
pytest tests/test_sanitize.py -v

# Run security tests only
pytest tests/test_sanitize.py test_security.py -v

# Run performance tests
pytest tests/test_performance.py -v
```

## Project Structure

```text
knowledge-harvester/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── skills/
│   └── harvest/
│       └── SKILL.md      # Main skill documentation
├── lib/
│   ├── orchestrator.py   # Pipeline orchestrator
│   ├── enumerate.py      # Stage 1: File discovery
│   ├── triage.py         # Stage 2: Scoring
│   ├── extract.py        # Stage 4: Extraction
│   ├── synthesize.py     # Stage 5: Synthesis
│   ├── checkpoint.py     # Checkpoint management
│   └── sanitize.py       # Security utilities
├── schemas/
│   ├── harvest-config.schema.json
│   ├── candidates.schema.json
│   ├── ranked.schema.json
│   ├── extractions.schema.json
│   └── checkpoint.schema.json
├── docs/
│   ├── security.md       # Security documentation
│   ├── checkpoint-format.md
│   ├── concurrency.md
│   └── adr/              # Architecture Decision Records
└── agents/               # Agent configurations
```

## Contributing

1. **Security**: All user input must pass through `lib/sanitize.py` functions
2. **Testing**: Add tests for new functionality
3. **Schemas**: Update JSON schemas when modifying data structures
4. **Documentation**: Update ADRs for architectural changes

### Code Review Checklist

- [ ] User input passes through appropriate sanitization
- [ ] Shell commands use `quote_for_shell()` for arguments
- [ ] File operations verify paths are within expected boundaries
- [ ] Tests include malicious input cases
- [ ] JSON schemas updated if data structures changed

## License

MIT

## Version History

| Version | Description |
|---------|-------------|
| 0.1.0 | Initial release with 6-stage harvest pipeline, checkpoint/resume, parallel extraction, and security-first input validation |
