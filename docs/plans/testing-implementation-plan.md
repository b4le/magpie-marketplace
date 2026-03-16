# Testing Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement consistent automated testing across all 12 marketplace plugins, using a shared bash harness and standardized Makefile targets.

**Architecture:** Shared harness at `tests/harness.sh`, per-plugin test suites following the patterns established in session-autopilot (bash unit tests) and CCDK (fixture-based validator tests). Python unittest for knowledge-harvester modules.

**Tech Stack:** Bash (test harness, unit/integration tests), Python 3 unittest (knowledge-harvester), Make (build targets), jq (JSON validation, optional graceful fallback).

**Prerequisite:** Read `docs/testing-framework.md` for conventions, harness API, and per-plugin test plans.

---

## Chunk 1: Foundation (shared infrastructure)

### Task 1: Create shared test harness

**Files:**
- Create: `tests/harness.sh`

- [ ] **Step 1: Create `tests/harness.sh`**

Implement the full harness spec from `docs/testing-framework.md` section 3. The harness provides:
- Color output (auto-disabled on non-TTY)
- Counters: PASS, FAIL, SKIP, FAILURES array
- Assertions: `assert_eq`, `assert_contains`, `assert_matches`, `assert_exit_code`, `assert_file_exists`, `assert_file_contains`, `assert_valid_json`
- Validator helpers: `run_validator`, `assert_passes`, `assert_fails`, `assert_output_contains`, `assert_output_not_contains`
- Setup/teardown: `setup_tmpdir`, `on_cleanup`
- Skip: `skip <label> [reason]`
- Auto-summary on EXIT trap

- [ ] **Step 2: Write self-test for the harness**

Create `tests/test-harness.sh` that verifies:
- `assert_eq` passes on equal strings, fails on different strings
- `assert_contains` passes on substring match, fails on missing
- `assert_matches` passes on regex match, fails on mismatch
- `assert_exit_code` captures exit codes correctly
- `assert_file_exists` works for existing and missing files
- `setup_tmpdir` creates a directory that is cleaned up on exit
- `skip` increments SKIP counter
- Color output is suppressed when stdout is not a TTY

Run: `bash tests/test-harness.sh`

- [ ] **Step 3: Commit**

```bash
git add tests/harness.sh tests/test-harness.sh
git commit -m "test: add shared test harness for marketplace plugins"
```

### Task 2: Create root Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Create root `Makefile`**

```makefile
.PHONY: test-all lint-all validate-all test-harness

PLUGINS := archaeology claude-code-development-kit expert-review \
  gen-plugin knowledge-harvester mode-plugin orchestration-toolkit \
  plugin-profile quality-assurance-toolkit session-autopilot \
  session-budget unicode-library

test-harness:
	bash tests/test-harness.sh

test-all: test-harness
	@for plugin in $(PLUGINS); do \
	  if [ -f "$$plugin/Makefile" ]; then \
	    echo "=== $$plugin ===" && $(MAKE) -C $$plugin test || exit 1; \
	  else \
	    echo "=== $$plugin (no Makefile, skipping) ==="; \
	  fi; \
	done

validate-all:
	@for plugin in $(PLUGINS); do \
	  if [ -f "$$plugin/Makefile" ]; then \
	    echo "=== $$plugin ===" && $(MAKE) -C $$plugin validate || exit 1; \
	  else \
	    echo "=== $$plugin (no Makefile, skipping) ==="; \
	  fi; \
	done

lint-all:
	@for plugin in $(PLUGINS); do \
	  if [ -f "$$plugin/Makefile" ]; then \
	    echo "=== $$plugin ===" && $(MAKE) -C $$plugin lint || exit 1; \
	  else \
	    echo "=== $$plugin (no Makefile, skipping) ==="; \
	  fi; \
	done
```

- [ ] **Step 2: Commit**

```bash
git add Makefile
git commit -m "build: add root Makefile with test-all/lint-all/validate-all targets"
```

---

## Wave 1: High Priority

Plugins with the largest testing gaps relative to their complexity and usage.

---

### Task 3: knowledge-harvester — structure validator + Python unit tests

**Files:**
- Create: `knowledge-harvester/evals/validate-structure.sh`
- Create: `knowledge-harvester/tests/test_sanitize.py`
- Create: `knowledge-harvester/tests/test_triage.py`
- Create: `knowledge-harvester/tests/test_checkpoint.py`
- Create: `knowledge-harvester/tests/test_extract.py`
- Create: `knowledge-harvester/tests/test_synthesize.py`
- Create: `knowledge-harvester/tests/test_enumerate.py`
- Create: `knowledge-harvester/Makefile`

- [ ] **Step 1: Create `evals/validate-structure.sh`**

Validate:
- `plugin.json` exists, valid JSON, name == "knowledge-harvester", version present
- `lib/` directory with expected Python modules: `checkpoint.py`, `triage.py`, `sanitize.py`, `enumerate.py`, `extract.py`, `synthesize.py`, `orchestrator.py`
- `lib/harvest.sh` exists and is executable
- JSON schemas present: `candidates.schema.json`, `checkpoint.schema.json`, `extractions.schema.json`, `harvest-config.schema.json`, `ranked.schema.json`
- `README.md` exists

- [ ] **Step 2: Create `tests/test_sanitize.py`**

Test `sanitize.py` functions — these are pure string operations, highest unit-test value:
- `sanitize_path`: normal path, path traversal (`../`), absolute path, empty string, None
- `validate_glob_pattern`: valid patterns (`*.py`, `**/*.md`), invalid patterns (shell injection attempts)
- `quote_for_shell`: strings with spaces, quotes, special chars, empty string

Target: 12+ test cases.

Read `knowledge-harvester/lib/sanitize.py` first to understand exact function signatures and edge cases.

- [ ] **Step 3: Run tests to verify they pass**

Run: `cd knowledge-harvester && python3 -m unittest tests/test_sanitize.py -v`

- [ ] **Step 4: Create `tests/test_triage.py`**

Test `triage.py` scoring — the core ranking algorithm:
- `calculate_combined_score`: known inputs → expected score ranges
- `_determine_decision`: scores above/below threshold → accept/reject
- `score_candidates`: list of candidates → sorted by score, decisions applied
- Edge cases: empty candidate list, all-zero scores, threshold boundary values

Target: 10+ test cases.

Read `knowledge-harvester/lib/triage.py` first.

- [ ] **Step 5: Run tests**

Run: `cd knowledge-harvester && python3 -m unittest tests/test_triage.py -v`

- [ ] **Step 6: Create `tests/test_checkpoint.py`**

Test `checkpoint.py` state management:
- `save` + `load` round-trip: save state, load it back, verify equality
- `record_stage_start`/`record_stage_complete`: stage lifecycle
- `is_stage_complete`: true after complete, false before
- `record_error`: error captured in state
- Edge cases: load from non-existent file, corrupt file

Target: 8+ test cases.

Read `knowledge-harvester/lib/checkpoint.py` first.

- [ ] **Step 7: Run tests**

Run: `cd knowledge-harvester && python3 -m unittest tests/test_checkpoint.py -v`

- [ ] **Step 8: Create `tests/test_extract.py`**

Test `extract.py` finding validation:
- `validate_finding`: valid finding dict → passes
- Missing required fields → raises/returns error
- Invalid field types → raises/returns error
- `_create_finding`: constructs finding with defaults

Target: 6+ test cases.

Read `knowledge-harvester/lib/extract.py` first.

- [ ] **Step 9: Create `tests/test_synthesize.py`**

Test `synthesize.py` categorization logic:
- `_categorize_findings`: findings with different tags → correct buckets
- `handle_empty_findings`: empty input → graceful response
- `_identify_patterns`: repeated signals → pattern detected
- `_detect_conflicts`: contradictory findings → conflict flagged

Target: 6+ test cases.

Read `knowledge-harvester/lib/synthesize.py` first.

- [ ] **Step 10: Create `tests/test_enumerate.py`**

Test `enumerate.py` file discovery:
- `_find_files`: mock directory → correct file list
- `_get_file_metadata`: existing file → size, mtime populated
- Edge cases: empty directory, permission errors, symlinks

Target: 4+ test cases. Uses `tempfile` for fixture directories.

Read `knowledge-harvester/lib/enumerate.py` first.

- [ ] **Step 10b: Note on `orchestrator.py`**

`orchestrator.py` contains `HarvestOrchestrator` which orchestrates all other modules (`enumerate` → `triage` → `extract` → `synthesize`). It is **excluded from unit tests** because:
- Its methods primarily compose the other modules, which are individually tested
- Testing it requires mocking 6 module interfaces — high maintenance, low incremental value
- Integration-level testing (running the full pipeline on a fixture directory) is more appropriate and planned as a future addition

- [ ] **Step 11: Create `Makefile`**

```makefile
.PHONY: test lint validate

test:
	python3 -m unittest discover -s tests -p 'test_*.py' -v

lint:
	bash -n lib/harvest.sh
	python3 -m py_compile lib/sanitize.py
	python3 -m py_compile lib/triage.py
	python3 -m py_compile lib/checkpoint.py
	python3 -m py_compile lib/extract.py
	python3 -m py_compile lib/synthesize.py
	python3 -m py_compile lib/enumerate.py
	python3 -m py_compile lib/orchestrator.py

validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 12: Run full suite**

Run: `cd knowledge-harvester && make test && make lint && make validate`

- [ ] **Step 13: Commit**

```bash
git add knowledge-harvester/evals/validate-structure.sh knowledge-harvester/tests/ knowledge-harvester/Makefile
git commit -m "test(knowledge-harvester): add structure validator + Python unit tests for 6 modules"
```

---

### Task 4: plugin-profile — shell unit tests for detect/apply/validate

**Files:**
- Create: `plugin-profile/tests/test-detect.sh`
- Create: `plugin-profile/tests/test-apply.sh`
- Create: `plugin-profile/tests/test-validate.sh`
- Create: `plugin-profile/tests/fixtures/` (mock project dirs + profile YAMLs)
- Create: `plugin-profile/Makefile`

- [ ] **Step 1: Read source scripts**

Read these to understand function signatures, inputs/outputs:
- `plugin-profile/shared/scripts/detect.sh`
- `plugin-profile/shared/scripts/apply.sh`
- `plugin-profile/shared/scripts/validate.sh`

- [ ] **Step 2: Create test fixtures**

Create mock project directories in `tests/fixtures/`:
- `fixtures/python-project/` — contains `requirements.txt`, `*.py` files
- `fixtures/typescript-project/` — contains `package.json`, `tsconfig.json`, `*.ts` files
- `fixtures/rust-project/` — contains `Cargo.toml`, `*.rs` files
- `fixtures/empty-project/` — empty directory
- `fixtures/profiles/` — mock `.yaml` profile files with parent/child inheritance chains
- `fixtures/profiles/cycle-a.yaml` + `cycle-b.yaml` — circular inheritance for cycle detection test

- [ ] **Step 3: Create `tests/test-detect.sh`**

Source `../../tests/harness.sh` and test:
- Detection priority: TypeScript project → "typescript" profile
- Detection priority: Python project → "python" profile
- Detection priority: Rust project → "rust" profile
- Empty project → "core" fallback profile
- Confidence values: specific language > generic
- JSON output format: valid JSON with `profile`, `confidence`, `fingerprints` keys

Target: 8+ assertions.

- [ ] **Step 4: Run tests**

Run: `bash plugin-profile/tests/test-detect.sh`

- [ ] **Step 5: Create `tests/test-apply.sh`**

Source `../../tests/harness.sh` and test:
- `extract_plugins`: profile YAML → plugin list
- `get_parent_profile`: child profile → parent name
- `collect_all_plugins`: profile chain → merged plugin list without duplicates
- `get_disable_inherited`: profile with disabled list → correct exclusions
- Cycle detection: circular parent chain → error, not infinite loop

Target: 8+ assertions.

- [ ] **Step 6: Run tests**

Run: `bash plugin-profile/tests/test-apply.sh`

- [ ] **Step 7: Create `tests/test-validate.sh`**

Source `../../tests/harness.sh` and test:
- `is_enabled`: plugin in enabled list → true
- `is_enabled`: plugin not in list → false
- `error_json`: conflict details → valid JSON output
- Conflict detection: incompatible plugins → conflict reported
- No conflicts: compatible plugins → clean output

Target: 5+ assertions.

- [ ] **Step 8: Run tests**

Run: `bash plugin-profile/tests/test-validate.sh`

- [ ] **Step 9: Create `Makefile`**

```makefile
.PHONY: test lint validate

test:
	bash tests/test-detect.sh
	bash tests/test-apply.sh
	bash tests/test-validate.sh

lint:
	bash -n shared/scripts/detect.sh
	bash -n shared/scripts/apply.sh
	bash -n shared/scripts/validate.sh
	bash -n hooks/scripts/session-start.sh

validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 10: Commit**

```bash
git add plugin-profile/tests/ plugin-profile/Makefile
git commit -m "test(plugin-profile): add unit tests for detect, apply, and validate scripts"
```

---

### Task 5: mode-plugin — Makefile + command validation

**Files:**
- Create: `mode-plugin/Makefile`

- [ ] **Step 1: Create `Makefile`**

Since mode-plugin has no runtime scripts (commands are `.md` prompt files), testing focuses on structure validation and command frontmatter validation via CCDK validators.

```makefile
.PHONY: test lint validate

CCDK_EVALS := ../claude-code-development-kit/evals

test: validate
	@echo "mode-plugin: no unit tests (prompt-only plugin)"
	@echo "Running command validation via CCDK validators..."
	@for cmd in commands/*.md; do \
	  echo "  Validating $$cmd..." && \
	  bash $(CCDK_EVALS)/validate-command.sh "$$cmd" || exit 1; \
	done
	@echo "All commands validated."

lint:
	bash -n evals/validate-structure.sh

validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 2: Run**

Run: `cd mode-plugin && make test`

- [ ] **Step 3: Commit**

```bash
git add mode-plugin/Makefile
git commit -m "test(mode-plugin): add Makefile with command validation via CCDK"
```

---

### Task 6: quality-assurance-toolkit — Makefile + command validation

**Files:**
- Create: `quality-assurance-toolkit/Makefile`

- [ ] **Step 1: Create `Makefile`**

Same pattern as mode-plugin — prompt-only skill, validate structure + CCDK skill validator.

```makefile
.PHONY: test lint validate

CCDK_EVALS := ../claude-code-development-kit/evals

test: validate
	@echo "quality-assurance-toolkit: no unit tests (prompt-only plugin)"
	@echo "Running skill validation via CCDK validators..."
	bash $(CCDK_EVALS)/validate-skill.sh skills/eval-plugin || exit 1
	@echo "Skill validated."

lint:
	bash -n evals/validate-structure.sh

validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 2: Commit**

```bash
git add quality-assurance-toolkit/Makefile
git commit -m "test(quality-assurance-toolkit): add Makefile with skill validation"
```

---

### Task 7: expert-review — worktree validation + checkpoint detector tests

**Files:**
- Create: `expert-review/tests/test-validate-worktree.sh`
- Create: `expert-review/tests/test-checkpoint-detector.sh`
- Create: `expert-review/tests/fixtures/` (path test cases)
- Create: `expert-review/Makefile`

- [ ] **Step 1: Read source scripts**

Read:
- `expert-review/skills/expert-review/scripts/validate-worktree.sh`
- `expert-review/hooks/checkpoint-detector.sh`

- [ ] **Step 2: Create `tests/test-validate-worktree.sh`**

Source `../../tests/harness.sh` and test:
- Valid path within project → passes
- Path traversal (`../../etc/passwd`) → blocked (contains `..`)
- Invalid characters in path → blocked (non-alphanumeric/slash/dot/dash/underscore)
- Canonical path outside project root → blocked (resolved path not under project)
- Absolute path outside project (`/etc/passwd`) → blocked (outside project root, not path traversal)
- Worktree count at limit (10) → blocked
- Worktree count at warning (5) → warning but passes
- Normal worktree count → passes

Target: 8+ assertions.

- [ ] **Step 3: Create `tests/test-checkpoint-detector.sh`**

Source `../../tests/harness.sh` and test:
- Transcript with "ready for feedback" → suggests checkpoint
- Transcript with "batch complete" → suggests checkpoint
- Transcript with "checkpoint" → suggests checkpoint
- Transcript with no trigger patterns → no output
- Empty input → no output

Target: 5+ assertions.

- [ ] **Step 4: Create `Makefile`**

```makefile
.PHONY: test lint validate

test:
	bash tests/test-validate-worktree.sh
	bash tests/test-checkpoint-detector.sh

lint:
	bash -n skills/expert-review/scripts/validate-worktree.sh
	bash -n hooks/checkpoint-detector.sh

validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 5: Run and commit**

Run: `cd expert-review && make test`

```bash
git add expert-review/tests/ expert-review/Makefile
git commit -m "test(expert-review): add worktree validation + checkpoint detector tests"
```

---

## Wave 2: Medium Priority

Plugins with existing partial coverage or moderate complexity.

---

### Task 8: session-budget — budget tracker tests

**Files:**
- Create: `session-budget/evals/validate-structure.sh`
- Create: `session-budget/tests/test-budget-tracker.sh`
- Create: `session-budget/tests/fixtures/` (mock budget.json files)
- Create: `session-budget/Makefile`

- [ ] **Step 1: Read source scripts**

Read:
- `session-budget/hooks/scripts/budget-tracker.sh`
- `session-budget/hooks/scripts/session-start.sh`

- [ ] **Step 2: Create `evals/validate-structure.sh`**

Validate:
- `plugin.json` exists, valid JSON, name == "session-budget", version present
- `hooks/` dir, `hooks.json` valid JSON
- `hooks/scripts/budget-tracker.sh` exists and is executable
- `skills/session-budget/SKILL.md` with YAML frontmatter
- `README.md` exists

- [ ] **Step 3: Create test fixtures**

Create `tests/fixtures/`:
- `budget-under.json` — `points_completed: 2, points_in_progress: 1, tasks: [...]` (consumed=3, no warning)
- `budget-info.json` — `points_completed: 3, points_in_progress: 2, tasks: [...]` (consumed=5, info threshold)
- `budget-warning.json` — `points_completed: 5, points_in_progress: 2, tasks: [...]` (consumed=7, warning threshold)
- `budget-exceeded.json` — `points_completed: 6, points_in_progress: 2, tasks: [...]` (consumed=8, exceeded threshold)
- `budget-empty.json` — `points_completed: 0, points_in_progress: 0, tasks: []` (consumed=0)

- [ ] **Step 4: Create `tests/test-budget-tracker.sh`**

Source `../../tests/harness.sh` and test:
- Under threshold: points_completed + points_in_progress < 5 → no warning in `additionalContext`
- Info threshold: consumed >= 5 → info message in `additionalContext` JSON
- Warning threshold: consumed >= 7 → warning message with task names
- Exceeded threshold: consumed >= 8 → exceeded message
- Empty budget: no tasks array → consumed = 0, no warning
- JSON output format: valid `additionalContext` JSON blob
- Missing budget file → graceful handling (no crash)
- Planned tasks: when `tasks` array has `status: "planned"` entries, names appear in output

Target: 8+ assertions.

- [ ] **Step 5: Create `Makefile`**

```makefile
.PHONY: test lint validate

test:
	bash tests/test-budget-tracker.sh

lint:
	bash -n hooks/scripts/budget-tracker.sh
	bash -n hooks/scripts/session-start.sh
	bash -n evals/validate-structure.sh

validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 6: Run and commit**

Run: `cd session-budget && make test && make validate`

```bash
git add session-budget/evals/ session-budget/tests/ session-budget/Makefile
git commit -m "test(session-budget): add structure validator + budget tracker threshold tests"
```

---

### Task 9: orchestration-toolkit — capability registry tests

**Files:**
- Create: `orchestration-toolkit/tests/test-capability-registry.sh`
- Create: `orchestration-toolkit/tests/fixtures/` (mock plugin dirs)
- Create: `orchestration-toolkit/Makefile`

- [ ] **Step 1: Read source script**

Read: `orchestration-toolkit/scripts/build-capability-registry.sh`

- [ ] **Step 2: Create test fixtures**

Create `tests/fixtures/`:
- `fixtures/mock-plugin/plugin.json` — valid manifest
- `fixtures/mock-plugin/skills/test-skill/SKILL.md` — skill with frontmatter
- `fixtures/mock-plugin/agents/test-agent.md` — agent with frontmatter
- `fixtures/blocked-plugin/plugin.json` — plugin in blocked list
- `fixtures/disabled-plugin/plugin.json` — plugin not installed

- [ ] **Step 3: Create `tests/test-capability-registry.sh`**

Source `../../tests/harness.sh`. **Important:** `build-capability-registry.sh` has no `BASH_SOURCE` guard — sourcing it triggers a live registry rebuild writing to `~/.claude/registry/`. Test via subprocess with controlled arguments, or extract functions into a sourceable helper.

Test via subprocess I/O:
- Run with `--quiet` flag on mock plugin directory → valid JSON output
- Run with fresh cache (< TTL) → skips rebuild
- Run with stale/missing cache → rebuilds
- Output contains expected plugin entries from mock dirs
- Output is valid JSON array

Test individual functions (if extracted to helper):
- `extract_frontmatter_field`: valid YAML → correct field value
- `extract_frontmatter_field`: missing field → empty string
- `extract_description`: skill SKILL.md → description text
- `infer_domain_tags`: skill with known keywords → correct tags
- `add_entry` / `add_builtin`: mock entry → valid JSON fragment

Target: 12+ assertions.

- [ ] **Step 4: Create `Makefile`**

```makefile
.PHONY: test lint validate

test:
	bash tests/test-capability-registry.sh

lint:
	bash -n scripts/build-capability-registry.sh
	bash -n scripts/migrate-plans.sh

validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 5: Run and commit**

Run: `cd orchestration-toolkit && make test`

```bash
git add orchestration-toolkit/tests/ orchestration-toolkit/Makefile
git commit -m "test(orchestration-toolkit): add capability registry unit tests"
```

---

### Task 10: archaeology — shell unit tests for scoring + caching

**Files:**
- Create: `archaeology/tests/test-arch-score.sh`
- Create: `archaeology/tests/test-arch-cache.sh`
- Create: `archaeology/tests/test-excavation.sh`
- Create: `archaeology/tests/fixtures/` (mock YAML, session data)
- Create: `archaeology/evals/tests/test-validate-conserve.sh`
- Create: `archaeology/evals/tests/test-validate-dig.sh`
- Create: `archaeology/evals/tests/fixtures/` (good/bad artifacts, spelunk output)
- Create: `archaeology/Makefile`

- [ ] **Step 1: Read source scripts**

Read:
- `archaeology/scripts/arch-score.sh`
- `archaeology/scripts/arch-cache.sh`
- `archaeology/scripts/archaeology-excavation.sh`
- `archaeology/scripts/validate-conserve.sh`
- `archaeology/scripts/validate-dig.sh`

- [ ] **Step 2: Create `tests/test-arch-score.sh`**

Source `../../tests/harness.sh`. **Important:** `arch-score.sh` has no `BASH_SOURCE` guard and calls `exit 0` at the end — it cannot be sourced. Test functions by extracting them into a helper or by testing the script's end-to-end I/O via subprocess:

```bash
# Run arch-score.sh as subprocess, capture output
output=$(bash ../scripts/arch-score.sh "$TEST_TMPDIR/mock-file.md" "$TEST_TMPDIR/mock-registry.yaml" 2>&1)
assert_contains "score output present" "score" "$output"
```

Test cases:
- Mock file with known primary keywords → score in expected range
- Mock file with secondary keywords only → lower score
- Mock file with no keywords → zero/minimal score
- Multi-domain keywords → diversity factor applied
- Empty file → graceful handling
- Invalid/missing registry → error exit code

Target: 10+ assertions.

- [ ] **Step 3: Create `tests/test-arch-cache.sh`**

Source `../../tests/harness.sh`. **Same sourcing caveat** — `arch-cache.sh` has a main execution block with no guard. Test via subprocess:

```bash
# Test cache behavior via subprocess I/O
output=$(bash ../scripts/arch-cache.sh "$TEST_TMPDIR/mock-session.jsonl" 2>&1)
```

Test cases:
- `process_session` with mock JSONL file (not directory) → processed output
- Fresh cache file → skip rebuild (fast path)
- Stale/missing cache → rebuild triggered
- ISO timestamp format in output

Target: 5+ assertions.

- [ ] **Step 4: Create `tests/test-excavation.sh`**

Source `../../tests/harness.sh`. **Same sourcing caveat** — `archaeology-excavation.sh` executes immediately. Test via subprocess or extract individual functions into a testable helper:

Test cases:
- Slug generation: "My Project" → "my-project"
- Slug generation: path with slashes → slugified
- Survey freshness: recent timestamp → fresh (exit 0)
- Survey freshness: old timestamp → stale (exit 1)
- JSON escaping: special characters → properly escaped

Target: 5+ assertions.

- [ ] **Step 5: Create validator fixture tests**

Create `evals/tests/test-validate-conserve.sh` with fixtures:
- `fixtures/good-artifact.md` — valid conserve artifact with frontmatter, URI, exhibition link
- `fixtures/bad-missing-uri.md` — artifact without URI field
- `fixtures/bad-broken-exhibition.md` — artifact with dead exhibition link

Create `evals/tests/test-validate-dig.sh` with fixtures:
- `fixtures/good-spelunk/` — valid cavern-map.json + nuggets
- `fixtures/bad-no-cavern-map/` — missing cavern-map.json
- `fixtures/bad-invalid-nugget/` — nugget missing required schema fields

- [ ] **Step 6: Create `Makefile`**

```makefile
.PHONY: test lint validate

test:
	bash tests/test-arch-score.sh
	bash tests/test-arch-cache.sh
	bash tests/test-excavation.sh
	bash evals/tests/test-validate-conserve.sh
	bash evals/tests/test-validate-dig.sh

lint:
	bash -n scripts/arch-score.sh
	bash -n scripts/arch-cache.sh
	bash -n scripts/arch-discover.sh
	bash -n scripts/arch-profile.sh
	bash -n scripts/archaeology-excavation.sh
	bash -n scripts/validate-conserve.sh
	bash -n scripts/validate-dig.sh
	bash -n scripts/prep-rig.sh

validate:
	bash evals/validate-structure.sh .
	bash evals/validate-scripts.sh
	bash evals/validate-skill-content.sh
```

- [ ] **Step 7: Run and commit**

Run: `cd archaeology && make test && make lint && make validate`

```bash
git add archaeology/tests/ archaeology/evals/tests/ archaeology/Makefile
git commit -m "test(archaeology): add unit tests for scoring/caching + validator fixture tests"
```

---

### Task 11: claude-code-development-kit — complete validator coverage + Makefile

**Files:**
- Create: `claude-code-development-kit/evals/tests/test-validate-hook.sh`
- Create: `claude-code-development-kit/evals/tests/test-validate-references.sh`
- Create: `claude-code-development-kit/evals/tests/test-validate-output-style.sh`
- Create: `claude-code-development-kit/evals/tests/test-validate-marketplace.sh`
- Create: `claude-code-development-kit/evals/tests/test-validate-structure.sh`
- Create: `claude-code-development-kit/evals/tests/test-validate-research-output.sh`
- Create: `claude-code-development-kit/evals/tests/fixtures/hooks/` (good/bad hook fixtures)
- Create: `claude-code-development-kit/evals/tests/fixtures/references/` (good/bad refs)
- Create: `claude-code-development-kit/evals/tests/fixtures/output-styles/` (good/bad styles)
- Create: `claude-code-development-kit/evals/tests/fixtures/marketplace/` (good/bad marketplace dirs)
- Create: `claude-code-development-kit/evals/tests/fixtures/research-outputs/` (good/bad research outputs)
- Create: `claude-code-development-kit/Makefile`

- [ ] **Step 1: Read remaining validators**

Read:
- `claude-code-development-kit/evals/validate-hook.sh`
- `claude-code-development-kit/evals/validate-references.sh`
- `claude-code-development-kit/evals/validate-output-style.sh`
- `claude-code-development-kit/evals/validate-marketplace.sh`
- `claude-code-development-kit/evals/validate-structure.sh`
- `claude-code-development-kit/evals/validate-research-output.sh`

- [ ] **Step 2: Create hook validator fixtures + test**

Create `fixtures/hooks/` with good/bad `hooks.json` files and `test-validate-hook.sh` following the existing test pattern (tc01-tcNN, `run_validator` + `assert_passes`/`assert_fails`/`assert_output_contains`).

Target: 10+ test cases.

- [ ] **Step 3: Create references validator fixtures + test**

Create `fixtures/references/` with good/bad `.md` reference files and `test-validate-references.sh`.

Target: 8+ test cases.

- [ ] **Step 4: Create output-style validator fixtures + test**

Create `fixtures/output-styles/` with good/bad style files and `test-validate-output-style.sh`.

Target: 8+ test cases.

- [ ] **Step 4b: Create marketplace validator fixtures + test**

Create `fixtures/marketplace/` with good/bad marketplace directory structures and `test-validate-marketplace.sh`.

Target: 6+ test cases.

- [ ] **Step 4c: Create structure validator fixtures + test**

Create `test-validate-structure.sh` testing against mock plugin directories with/without required components.

Target: 6+ test cases.

- [ ] **Step 4d: Create research-output validator fixtures + test**

Create `fixtures/research-outputs/` with good/bad research output files and `test-validate-research-output.sh`.

Target: 6+ test cases.

- [ ] **Step 5: Create `Makefile`**

```makefile
.PHONY: test lint validate

test:
	bash evals/tests/test-validate-command.sh
	bash evals/tests/test-validate-skill.sh
	bash evals/tests/test-validate-plugin.sh
	bash evals/tests/test-validate-agent.sh
	bash evals/tests/test-validate-hook.sh
	bash evals/tests/test-validate-references.sh
	bash evals/tests/test-validate-output-style.sh
	bash evals/tests/test-validate-marketplace.sh
	bash evals/tests/test-validate-structure.sh
	bash evals/tests/test-validate-research-output.sh

lint:
	bash -n evals/validate-command.sh
	bash -n evals/validate-skill.sh
	bash -n evals/validate-plugin.sh
	bash -n evals/validate-agent.sh
	bash -n evals/validate-hook.sh
	bash -n evals/validate-references.sh
	bash -n evals/validate-output-style.sh
	bash -n evals/validate-structure.sh
	bash -n evals/validate-marketplace.sh
	bash -n evals/_schema-validate.sh

validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 6: Run and commit**

Run: `cd claude-code-development-kit && make test && make lint`

```bash
git add claude-code-development-kit/evals/tests/ claude-code-development-kit/Makefile
git commit -m "test(ccdk): add fixture tests for 6 remaining validators + Makefile"
```

---

## Wave 3: Low Priority

Plugins that are already well-tested or have minimal runtime code.

---

### Task 12: gen-plugin — Makefile

**Files:**
- Create: `gen-plugin/Makefile`

- [ ] **Step 1: Create `Makefile`**

```makefile
.PHONY: test lint validate

CCDK_EVALS := ../claude-code-development-kit/evals

test: validate
	@echo "gen-plugin: no unit tests (prompt-only plugin)"
	@for skill_dir in skills/*/; do \
	  echo "  Validating $$skill_dir..." && \
	  bash $(CCDK_EVALS)/validate-skill.sh "$$skill_dir" || exit 1; \
	done

lint:
	bash -n evals/validate-structure.sh

validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 2: Commit**

```bash
git add gen-plugin/Makefile
git commit -m "test(gen-plugin): add Makefile with skill validation"
```

---

### Task 13: unicode-library — structure validator + Makefile

**Files:**
- Create: `unicode-library/evals/validate-structure.sh`
- Create: `unicode-library/Makefile`

- [ ] **Step 1: Create `evals/validate-structure.sh`**

Validate:
- `plugin.json` exists, valid JSON, name == "unicode-library", version present
- `README.md` exists
- Expected skill directories present

- [ ] **Step 2: Create `Makefile`**

```makefile
.PHONY: test lint validate

test: validate
	@echo "unicode-library: no unit tests (spec-only plugin)"

lint:
	bash -n evals/validate-structure.sh

validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 3: Commit**

```bash
git add unicode-library/evals/ unicode-library/Makefile
git commit -m "test(unicode-library): add structure validator + Makefile"
```

---

### Task 14: session-autopilot — migrate to shared harness + add validate-structure.sh

**Files:**
- Modify: `session-autopilot/tests/test-common.sh`
- Modify: `session-autopilot/tests/test-auto-resume.sh`
- Modify: `session-autopilot/tests/test-auto-handoff.sh`
- Modify: `session-autopilot/tests/test-checkpoint.sh`
- Modify: `session-autopilot/Makefile` (add `validate` target)
- Create: `session-autopilot/evals/validate-structure.sh`

- [ ] **Step 1: Update test files to source shared harness**

In each test file, replace the inline `PASS=0; FAIL=0` counters and `assert_eq`/`assert_contains` definitions with:
```bash
source "${SCRIPT_DIR}/../../tests/harness.sh"
```

The shared harness provides identical `assert_eq` and `assert_contains` functions, so tests continue working without changes to assertion calls.

Also remove the inline summary/exit logic at the end of each file — the harness EXIT trap handles this.

- [ ] **Step 1b: Create `evals/validate-structure.sh`**

session-autopilot is one of 4 plugins missing this. Create it to validate:
- `plugin.json` exists, valid JSON, name == "session-autopilot", version present
- `scripts/` dir with `auto-resume.sh`, `auto-handoff.sh`, `checkpoint.sh`
- `scripts/lib/common.sh` exists
- `hooks/` dir, `hooks.json` valid JSON
- `skills/session-autopilot/SKILL.md` with YAML frontmatter
- `README.md` exists

- [ ] **Step 2: Add `validate` target to Makefile**

```makefile
validate:
	bash evals/validate-structure.sh .
```

- [ ] **Step 3: Run all tests to verify no regressions**

Run: `cd session-autopilot && make test`

- [ ] **Step 4: Commit**

```bash
git add session-autopilot/tests/ session-autopilot/Makefile
git commit -m "refactor(session-autopilot): migrate tests to shared harness"
```

---

## Summary

| Wave | Task | Plugin | Type | New Tests | Effort |
|------|------|--------|------|-----------|--------|
| Foundation | 1 | (shared) | Harness | Self-test | S |
| Foundation | 2 | (root) | Makefile | — | S |
| 1 | 3 | knowledge-harvester | Python unit + structure | ~46 | L |
| 1 | 4 | plugin-profile | Shell unit | ~21 | L |
| 1 | 5 | mode-plugin | Makefile + validation | — | S |
| 1 | 6 | quality-assurance-toolkit | Makefile + validation | — | S |
| 1 | 7 | expert-review | Shell unit | ~13 | M |
| 2 | 8 | session-budget | Shell unit + structure | ~8 | M |
| 2 | 9 | orchestration-toolkit | Shell unit | ~12 | M |
| 2 | 10 | archaeology | Shell unit + fixtures | ~25 | L |
| 2 | 11 | ccdk | Fixture validator tests | ~44 | M |
| 3 | 12 | gen-plugin | Makefile | — | S |
| 3 | 13 | unicode-library | Structure + Makefile | — | S |
| 3 | 14 | session-autopilot | Harness migration | 0 (migration) | S |

**Total new tests estimated:** ~169 (plus harness self-tests)

**After completion:** Every plugin has `make test`, `make lint`, `make validate`. Root `make test-all` runs everything.
