# Knowledge Harvester: Agent Team Prompts

> **Prerequisites:** Agent teams enabled via `.claude/settings.local.json`
>
> Restart Claude Code after enabling, then run from `~/.claude/plugins/knowledge-harvester/`

---

## P0: Critical Fixes (Before Production)

**Estimated time:** 30-45 minutes
**Team size:** 3 agents
**Risk:** Low (isolated fixes with tests)

### Spawn Command

```text
/team-spawn custom --teammates "threshold-fixer,input-sanitizer,e2e-tester" --lead-prompt "P0-lead"
```

### Team Lead Prompt (P0-lead)

```markdown
# P0: Critical Fixes for Knowledge Harvester

You are the team lead coordinating 3 critical fixes before production.

## Context
- Working directory: ~/.claude/plugins/knowledge-harvester/
- All 39 existing tests must continue to pass
- Changes require commits with conventional commit messages

## Team Members & Assignments

### 1. threshold-fixer
**Ownership:** Schema and agent threshold consistency
**Files:**
- MODIFY: `schemas/harvest-config.schema.json` (change threshold from 0-1 to 0-10 scale)
- MODIFY: `agents/triage-scorer.yaml` (ensure threshold parameter documented)
- MODIFY: `tests/test_config_schema.py` (update threshold tests)

**Task:**
The schema currently uses 0-1 scale (default 0.5) but the triage-scorer agent uses 0-10 scale (default 7). Standardize on 0-10 throughout:
1. Update schema threshold to type integer, min 0, max 10, default 7
2. Update any tests that validate threshold range
3. Verify triage-scorer agent prompt is consistent
4. Run tests: `pytest tests/test_config_schema.py tests/test_triage_scoring.py -v`

### 2. input-sanitizer
**Ownership:** Security hardening for path inputs
**Files:**
- CREATE: `~/.claude/plugins/knowledge-harvester/lib/sanitize.py`
- MODIFY: `agents/local-enumerator.yaml` (add pre-validation section)
- CREATE: `tests/test_sanitize.py`

**Task:**
Add input sanitization layer to prevent command injection:
1. Create `lib/sanitize.py` with functions:
   - `sanitize_path(path: str) -> str` - canonicalize, reject traversal
   - `validate_glob_pattern(pattern: str) -> bool` - reject dangerous patterns
   - `quote_for_shell(value: str) -> str` - proper shell escaping
2. Add tests covering: path traversal attempts, shell metacharacters, null bytes
3. Update local-enumerator.yaml to reference validation requirements
4. Run tests: `pytest tests/test_sanitize.py -v`

### 3. e2e-tester
**Ownership:** End-to-end integration test
**Files:**
- CREATE: `tests/test_e2e_pipeline.py`
- MODIFY: `tests/fixtures/` (add sample content files)

**Task:**
Create minimal E2E test covering enumerate→triage→harvest→extract→synthesize:
1. Create test fixtures with actual markdown content (3-5 files)
2. Write test that:
   - Creates a test config
   - Simulates enumerate stage (mock or real bash)
   - Validates candidates.json structure
   - Simulates triage scoring
   - Validates ranked.json structure
   - Simulates harvest (file copy)
   - Validates sources/ directory
3. Run: `pytest tests/test_e2e_pipeline.py -v`

## Coordination

1. **threshold-fixer** and **input-sanitizer** can work in parallel (no file overlap)
2. **e2e-tester** depends on threshold-fixer completing first (uses updated schema)
3. All agents report when done; lead runs full test suite before completion:
   ```bash
   pytest tests/ -v
   ```

## Success Criteria
- [ ] Threshold consistently 0-10 in schema and agents
- [ ] sanitize.py with 100% test coverage
- [ ] E2E test covering 5 pipeline stages
- [ ] All 39+ tests pass
```

---

## P1: Quality Improvements (Before V2)

**Estimated time:** 1-2 hours
**Team size:** 4 agents
**Risk:** Medium (new test infrastructure)

### Spawn Command

```text
/team-spawn custom --teammates "agent-tester,checkpoint-designer,contract-formalizer,security-hardener" --lead-prompt "P1-lead"
```

### Team Lead Prompt (P1-lead)

```markdown
# P1: Quality Improvements for Knowledge Harvester

You are the team lead coordinating quality improvements before V2.

## Context
- Working directory: ~/.claude/plugins/knowledge-harvester/
- P0 fixes are complete (threshold, sanitization, E2E test)
- Focus on robustness and maintainability

## Team Members & Assignments

### 1. agent-tester
**Ownership:** Agent behavior test suite
**Files:**
- CREATE: `tests/test_agent_behaviors.py`
- CREATE: `tests/fixtures/agent-test-data/`

**Task:**
Create behavior tests for all 4 agents (mocked, not live):
1. **local-enumerator**: Test bash command generation for various inputs
   - Normal paths, paths with spaces, unicode filenames
   - Exclusion patterns applied correctly
   - JSON output structure validation
2. **triage-scorer**: Test scoring logic
   - Threshold boundary cases (6.9 vs 7.0 vs 7.1)
   - Multi-lens aggregation simulation
   - Invalid input handling
3. **extractor**: Test JSONL output
   - Finding structure validation
   - Confidence score ranges
   - Category assignment logic
4. **synthesizer**: Test output structure
   - Template data shape validation
   - Conflict detection simulation
   - Empty findings handling

### 2. checkpoint-designer
**Ownership:** Resume/checkpoint specification
**Files:**
- CREATE: `schemas/checkpoint.schema.json`
- MODIFY: `SKILL.md` (add checkpoint format documentation)
- CREATE: `docs/checkpoint-format.md`

**Task:**
Formalize the checkpoint/resume mechanism:
1. Design JSON schema for checkpoint files:
   ```json
   {
     "version": "1.0",
     "harvest_id": "...",
     "created_at": "ISO8601",
     "current_stage": 1-6,
     "stage_outputs": {
       "enumerate": "path/to/candidates.json",
       "triage": "path/to/ranked.json"
     },
     "progress": { "completed": N, "total": M },
     "errors": []
   }
   ```
2. Document how resume works (which stage to start from, how to skip completed)
3. Add checkpoint reference to SKILL.md

### 3. contract-formalizer
**Ownership:** Inter-stage data contracts
**Files:**
- CREATE: `schemas/candidates.schema.json`
- CREATE: `schemas/ranked.schema.json`
- CREATE: `schemas/extractions.schema.json`
- CREATE: `tests/test_stage_contracts.py`

**Task:**
Create JSON schemas for intermediate pipeline files:
1. candidates.json (Stage 1 → 2)
2. ranked.json (Stage 2 → 3)
3. extractions.jsonl line format (Stage 4 → 5/6)
4. Write tests that validate each schema
5. Cross-reference with agent output specifications

### 4. security-hardener
**Ownership:** Credential and path security
**Files:**
- MODIFY: `agents/local-enumerator.yaml` (add path validation rules)
- CREATE: `docs/security.md`
- MODIFY: `skills/internals/harvest.md` (add rclone credential guidance)

**Task:**
Document and implement security measures:
1. Add explicit path validation requirements to local-enumerator
2. Create security.md documenting:
   - How paths are validated
   - How credentials should be managed for rclone
   - What inputs are trusted vs untrusted
3. Update harvest.md with credential management for V2 gdrive support
4. No hardcoded credentials ever

## Coordination

1. **agent-tester** and **contract-formalizer** work in parallel
2. **checkpoint-designer** works independently
3. **security-hardener** coordinates with agent-tester on validation tests
4. Lead integrates all work and runs full test suite

## Success Criteria
- [ ] Agent behavior tests for all 4 agents
- [ ] Checkpoint schema with documentation
- [ ] 3 inter-stage contract schemas with tests
- [ ] Security documentation complete
- [ ] All tests pass
```

---

## P2: Nice to Have (Future Polish)

**Estimated time:** 2-3 hours
**Team size:** 3 agents
**Risk:** Low (documentation and optimization)

### Spawn Command

```text
/team-spawn custom --teammates "adr-writer,perf-tester,concurrency-designer" --lead-prompt "P2-lead"
```

### Team Lead Prompt (P2-lead)

```markdown
# P2: Polish and Documentation for Knowledge Harvester

You are the team lead coordinating documentation and performance work.

## Context
- Working directory: ~/.claude/plugins/knowledge-harvester/
- P0 and P1 are complete
- Focus on long-term maintainability and performance

## Team Members & Assignments

### 1. adr-writer
**Ownership:** Architecture Decision Records
**Files:**
- CREATE: `docs/adr/`
- CREATE: `docs/adr/001-funnel-architecture.md`
- CREATE: `docs/adr/002-bash-only-harvest.md`
- CREATE: `docs/adr/003-agent-model-selection.md`
- CREATE: `docs/adr/004-jsonl-intermediate-format.md`

**Task:**
Document key architectural decisions:
1. **ADR-001**: Why funnel architecture with 6 stages?
   - Context: Need to minimize token usage
   - Decision: Progressive filtering
   - Consequences: Complexity vs efficiency tradeoff
2. **ADR-002**: Why bash-only for harvest stage?
   - Context: File copying doesn't need LLM
   - Decision: Zero context cost via bash
   - Consequences: Platform-specific code
3. **ADR-003**: Why haiku for enumerate/triage, sonnet for extract/synthesize?
   - Context: Cost vs quality tradeoff
   - Decision: Match model to task complexity
4. **ADR-004**: Why JSONL for extractions?
   - Context: Need streaming-friendly format
   - Decision: JSONL over JSON array

### 2. perf-tester
**Ownership:** Performance test suite
**Files:**
- CREATE: `tests/test_performance.py`
- CREATE: `tests/fixtures/large-dataset/` (100+ files)

**Task:**
Create performance benchmarks:
1. Generate large test fixture (100+ markdown files)
2. Test enumerate performance (should handle 1000+ candidates)
3. Test token budget enforcement
4. Measure and document baseline timings
5. Add pytest markers for slow tests: `@pytest.mark.slow`

### 3. concurrency-designer
**Ownership:** Parallel dispatch patterns
**Files:**
- CREATE: `docs/concurrency.md`
- MODIFY: `skills/internals/extract.md` (formalize batching)
- MODIFY: `skills/internals/triage.md` (add concurrency guidance)

**Task:**
Document and standardize concurrent execution:
1. Define batching pattern for parallel agent dispatch
2. Document how many agents can run in parallel safely
3. Add rate limiting guidance for API considerations
4. Update extract.md with formal batching specification
5. Update triage.md with parallel scoring guidance

## Coordination

All three agents work independently - no file overlap.

## Success Criteria
- [ ] 4 ADRs documenting key decisions
- [ ] Performance tests with large dataset
- [ ] Concurrency documentation complete
- [ ] All tests pass
```

---

## Quick Reference

| Priority | Focus | Agents | Est. Time |
|----------|-------|--------|-----------|
| **P0** | Critical fixes | threshold-fixer, input-sanitizer, e2e-tester | 30-45 min |
| **P1** | Quality | agent-tester, checkpoint-designer, contract-formalizer, security-hardener | 1-2 hrs |
| **P2** | Polish | adr-writer, perf-tester, concurrency-designer | 2-3 hrs |

## Running Teams

1. Restart Claude Code (to pick up agent teams setting)
2. `cd ~/.claude/plugins/knowledge-harvester`
3. Copy the team lead prompt for your priority level
4. Run: `/team-spawn custom --teammates "..." --lead-prompt "..."`
5. Or paste the lead prompt directly after spawning

---

*Generated: 2026-02-26*
