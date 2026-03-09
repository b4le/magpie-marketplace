# Knowledge Harvester: Core Pipeline Implementation Plan

**Created**: 2026-02-27
**Status**: Ready for implementation
**Estimated effort**: 4-6 agent sessions

## Context

The knowledge-harvester plugin has complete infrastructure but no runnable code:
- 5 JSON schemas (all with semver 1.0.0)
- 251 tests passing
- 7 ADRs documenting architectural decisions
- Security hardening (sanitize.py with 79 tests)
- Agent YAML configs (4 agents defined)

## Goal

Implement the 6-stage harvest pipeline so `/harvest` command actually works.

## Architecture (from ADR-001)

```text
Stage 1: Enumerate  →  Stage 2: Triage  →  Stage 3: Harvest
    ↓                      ↓                    ↓
candidates.json      ranked.json          .harvest/sources/

Stage 4: Extract  →  Stage 5: Synthesize  →  Stage 6: Validate (V2)
    ↓                      ↓
extractions.jsonl    output/knowledge.md
```

## Implementation Tasks

### Phase 1: Core Agents (parallel)

#### Agent 1: local-enumerator
**Files to create:**
- `lib/enumerate.py`

**Responsibilities:**
- Parse local source configs from harvest-config.json
- Execute `find` command with depth/include/exclude filters
- Output candidates.json matching candidates.schema.json
- Use lib/sanitize.py for path validation

**Reference:**
- Schema: `schemas/candidates.schema.json`
- Agent config: `agents/local-enumerator.yaml`
- Tests: `tests/test_enumerate_local.py`

#### Agent 2: triage-scorer
**Files to create:**
- `lib/triage.py`

**Responsibilities:**
- Read candidates.json
- Score each candidate on configured lenses (relevance, freshness, authority, etc.)
- Apply aggregation method (weighted_average, minimum, maximum, product)
- Apply threshold to determine include/exclude/review
- Output ranked.json matching ranked.schema.json

**Reference:**
- Schema: `schemas/ranked.schema.json`
- Agent config: `agents/triage-scorer.yaml`
- Tests: `tests/test_triage_scoring.py`
- Concurrency: See `docs/concurrency.md` for batching (5-10 per batch)

#### Agent 3: harvester (bash-only, ADR-002)
**Files to create:**
- `lib/harvest.sh`

**Responsibilities:**
- Read ranked.json, filter to "include" decisions
- Copy files to `.harvest/sources/` workspace
- Zero token cost (pure bash)
- Create manifest of harvested files

**Reference:**
- ADR: `docs/adr/002-bash-only-harvest.md`

#### Agent 4: extractor
**Files to create:**
- `lib/extract.py`

**Responsibilities:**
- Read harvested files from `.harvest/sources/`
- Extract findings (facts, concepts, patterns, insights, etc.)
- Output extractions.jsonl (one JSON per line)
- Include confidence scores, citations, categories

**Reference:**
- Schema: `schemas/extractions.schema.json`
- Agent config: `agents/extractor.yaml`
- Tests: `tests/test_agent_behaviors.py::TestExtractor`
- Batching: See `skills/internals/extract.md`

#### Agent 5: synthesizer
**Files to create:**
- `lib/synthesize.py`

**Responsibilities:**
- Read extractions.jsonl
- Group by category, detect conflicts
- Generate output/knowledge.md using templates/synthesis.md.hbs
- Create output/manifest.json

**Reference:**
- Agent config: `agents/synthesizer.yaml`
- Template: `templates/synthesis.md.hbs`
- Tests: `tests/test_agent_behaviors.py::TestSynthesizer`

### Phase 2: Orchestrator

**Files to create:**
- `lib/orchestrator.py`
- Update `commands/harvest.md`

**Responsibilities:**
- Parse harvest config (validate against schema)
- Create workspace directory structure
- Execute stages sequentially (with checkpoint after each)
- Handle resume from checkpoint
- Report progress and errors

**Reference:**
- Checkpoint: `schemas/checkpoint.schema.json`, `docs/checkpoint-format.md`
- Config: `schemas/harvest-config.schema.json`
- Skill: `skills/internals/harvest.md`

### Phase 3: Integration Testing

- Run full pipeline end-to-end
- Verify checkpoint/resume works
- Test with sample-sources fixture
- Validate all outputs against schemas

## Model Selection (from ADR-003)

| Stage | Model | Rationale |
|-------|-------|-----------|
| Enumerate | haiku | Simple file listing |
| Triage | haiku | Scoring is straightforward |
| Harvest | none | Pure bash |
| Extract | sonnet | Complex reasoning needed |
| Synthesize | sonnet | Coherent output generation |

## File Structure After Implementation

```text
lib/
├── __init__.py
├── sanitize.py        # EXISTS
├── enumerate.py       # NEW
├── triage.py          # NEW
├── harvest.sh         # NEW
├── extract.py         # NEW
├── synthesize.py      # NEW
└── orchestrator.py    # NEW
```

## How to Start Next Session

```bash
/clear

I'm implementing the knowledge-harvester core pipeline.

Read the implementation plan:
~/.claude/plugins/knowledge-harvester/docs/IMPLEMENTATION-PLAN.md

Then implement Phase 1 using parallel sub-agents with file ownership:
- Agent 1: lib/enumerate.py (local-enumerator)
- Agent 2: lib/triage.py (triage-scorer)
- Agent 3: lib/harvest.sh (harvester)
- Agent 4: lib/extract.py (extractor)
- Agent 5: lib/synthesize.py (synthesizer)

After Phase 1, implement Phase 2 (orchestrator), then Phase 3 (integration).

Use test-driven development - run existing tests as you implement.
```

## Key Files to Reference

| Purpose | Path |
|---------|------|
| Schemas | `schemas/*.json` |
| Agent configs | `agents/*.yaml` |
| Security | `lib/sanitize.py` |
| Tests | `tests/test_*.py` |
| ADRs | `docs/adr/*.md` |
| Concurrency | `docs/concurrency.md` |
| Checkpoint | `docs/checkpoint-format.md` |
| Skills | `skills/internals/*.md` |

## Success Criteria

1. All 251+ tests pass
2. `/harvest` command executes full pipeline
3. Output matches schemas
4. Checkpoint/resume works
5. Security validation applied throughout
