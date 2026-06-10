# Magpie Marketplace Testing Framework

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a consistent, reusable testing approach across all 12 marketplace plugins.

**Architecture:** Shared bash test harness at repo root, sourced by per-plugin test suites. Four test categories (structure, unit, integration, eval-spec) with standardized Makefile targets.

---

## 1. Test Categories

### Category 1: Structure Validation

**What:** Verify plugin directory layout, required files, manifest validity.

**Runner:** `evals/validate-structure.sh` (per-plugin, already exists in 8 of 12).

**Conventions:**
- Every plugin MUST have `evals/validate-structure.sh`
- Checks: `plugin.json` validity, required directories, README, version alignment
- Exit 0 on pass, exit 1 on failure
- Uses `log_error`, `log_warning`, `log_success` from shared logging

### Category 2: Unit Tests (bash)

**What:** Test pure functions in shell scripts — scoring, parsing, validation, state management.

**Runner:** `tests/test-*.sh` files sourcing `../../tests/harness.sh`.

**When to use:** Plugin has `.sh` scripts with named functions that can be sourced and tested in isolation.

**Applicable plugins:** archaeology, session-autopilot, session-budget, orchestration-toolkit, plugin-profile, expert-review, knowledge-harvester (for `harvest.sh`).

### Category 3: Unit Tests (Python)

**What:** Test pure functions in Python modules — scoring, sanitization, schema validation.

**Runner:** `tests/test_*.py` using `unittest` (stdlib only, no pytest dependency).

**When to use:** Plugin has Python modules with testable logic.

**Applicable plugins:** knowledge-harvester (7 modules, 40+ methods).

### Category 4: Integration Tests (bash)

**What:** Test script-level I/O contracts — given JSON input on stdin, verify file creation and output.

**Runner:** `tests/test-*.sh` files using `run_script` + assert helpers from shared harness.

**When to use:** Scripts that read stdin JSON, interact with filesystem, or produce structured output.

**Applicable plugins:** session-autopilot (existing pattern), plugin-profile (detect.sh, apply.sh), archaeology (arch-score.sh end-to-end).

### Category 5: Fixture-Based Validator Tests

**What:** Run validators against known-good and known-bad fixture files, assert pass/fail.

**Runner:** `evals/tests/test-validate-*.sh` sourcing `../../tests/harness.sh`.

**When to use:** Plugin has validators that accept file paths and return pass/fail.

**Gold standard:** CCDK's `evals/tests/` — 94 test cases across 4 validators with 40+ fixtures.

### Category 6: Eval Specs (declarative, not automated)

**What:** YAML files describing LLM behavior expectations — prompts, expected outputs, scoring rubrics.

**Runner:** Manual/future automated eval runner. Not part of `make test`.

**When to use:** Testing skill invocation behavior, output quality, edge case handling.

**Applicable plugins:** archaeology (15 specs), orchestration-toolkit (5), quality-assurance-toolkit (5).

---

## 2. Conventions

### Directory Layout

```
plugin-name/
├── tests/                          # Unit + integration tests
│   ├── test-<module>.sh            # Bash unit tests
│   ├── test_<module>.py            # Python unit tests (if applicable)
│   └── fixtures/                   # Test data files
│       ├── good-<case>.json
│       └── bad-<case>.json
├── evals/                          # Validators + eval specs
│   ├── validate-structure.sh       # Structure validator (required)
│   ├── validate-<custom>.sh        # Plugin-specific validators
│   ├── tests/                      # Validator fixture tests
│   │   ├── test-validate-<name>.sh
│   │   └── fixtures/               # Good/bad fixture files
│   └── *.yaml                      # Eval specs (declarative)
└── Makefile                        # Standard targets
```

### Naming

| Type | Pattern | Example |
|------|---------|---------|
| Bash unit test | `tests/test-<source-file>.sh` | `tests/test-arch-score.sh` |
| Python unit test | `tests/test_<module>.py` | `tests/test_triage.py` |
| Validator test | `evals/tests/test-validate-<name>.sh` | `evals/tests/test-validate-conserve.sh` |
| Test fixture | `tests/fixtures/<type>-<case>.<ext>` | `tests/fixtures/good-profile.yaml` |
| Eval spec | `evals/<ID>.yaml` | `evals/INVOKE-01.yaml` |

### Makefile Targets

Every plugin MUST have a `Makefile` with these targets:

```makefile
.PHONY: test lint validate

# Run all automated tests (unit + integration + validator tests)
test:
	@echo "=== Running tests for <plugin-name> ==="
	bash tests/test-<module>.sh
	# ... additional test files ...

# Syntax check all shell scripts
lint:
	bash -n scripts/<script1>.sh
	# ... additional scripts ...

# Run structure validation only (fast, for CI)
validate:
	bash evals/validate-structure.sh .
```

### Root-Level Makefile

```makefile
.PHONY: test-all lint-all validate-all

test-all:
	@for plugin in archaeology claude-code-development-kit expert-review \
	  gen-plugin knowledge-harvester mode-plugin orchestration-toolkit \
	  plugin-profile quality-assurance-toolkit session-autopilot \
	  session-budget unicode-library; do \
	  echo "=== $$plugin ===" && $(MAKE) -C $$plugin test || exit 1; \
	done

validate-all:
	@for plugin in ...; do \
	  $(MAKE) -C $$plugin validate || exit 1; \
	done

lint-all:
	@for plugin in ...; do \
	  $(MAKE) -C $$plugin lint || exit 1; \
	done
```

---

## 3. Shared Test Harness

**Location:** `tests/harness.sh` (repo root)

**Usage:** Every test file sources this at the top:
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../../tests/harness.sh"
```

### Harness API

```bash
# ── Assertions ──────────────────────────────────────────────

# Exact string equality
assert_eq <label> <expected> <actual>

# Substring containment (glob-based)
assert_contains <label> <needle> <haystack>

# Regex match
assert_matches <label> <pattern> <string>

# Exit code check
assert_exit_code <label> <expected_code> <command...>

# File existence
assert_file_exists <label> <path>

# File contains string
assert_file_contains <label> <needle> <file_path>

# String is valid JSON (requires jq)
assert_valid_json <label> <string>

# ── Validator Helpers ───────────────────────────────────────

# Run a validator script, capture output and exit code
# Sets: VALIDATOR_OUTPUT, VALIDATOR_EXIT
run_validator <script_path> [args...]

# Assert last validator run passed (exit 0)
assert_passes <label>

# Assert last validator run failed (exit != 0)
assert_fails <label>

# Assert validator output matches regex
assert_output_contains <label> <pattern>

# Assert validator output does NOT match regex
assert_output_not_contains <label> <pattern>

# ── Setup / Teardown ───────────────────────────────────────

# Create a temp directory, cleaned up on exit
# Sets: TEST_TMPDIR
setup_tmpdir

# Register a cleanup function to run on exit
on_cleanup <command>

# ── Tracking ────────────────────────────────────────────────

# Print summary and exit with fail count
# Called automatically via EXIT trap
test_summary

# Skip a test (increments SKIP counter)
skip <label> [reason]
```

### Harness Implementation Spec

```bash
#!/usr/bin/env bash
# tests/harness.sh — Shared test harness for magpie-marketplace
# Source this file in every test script.

set -euo pipefail

# ── Color output (disabled if not TTY) ──
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; RESET='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; RESET=''
fi

# ── Counters ──
PASS=0; FAIL=0; SKIP=0
FAILURES=()
_CLEANUP_CMDS=()

# ── Assertions ──

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf "  ${GREEN}PASS${RESET}: %s\n" "$label"
    (( PASS++ )) || true
  else
    printf "  ${RED}FAIL${RESET}: %s\n" "$label"
    printf "    expected: %s\n" "$(printf '%q' "$expected")"
    printf "    actual:   %s\n" "$(printf '%q' "$actual")"
    (( FAIL++ )) || true
    FAILURES+=("$label")
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    printf "  ${GREEN}PASS${RESET}: %s\n" "$label"
    (( PASS++ )) || true
  else
    printf "  ${RED}FAIL${RESET}: %s (missing: '%s')\n" "$label" "$needle"
    (( FAIL++ )) || true
    FAILURES+=("$label")
  fi
}

assert_matches() {
  local label="$1" pattern="$2" string="$3"
  if [[ "$string" =~ $pattern ]]; then
    printf "  ${GREEN}PASS${RESET}: %s\n" "$label"
    (( PASS++ )) || true
  else
    printf "  ${RED}FAIL${RESET}: %s (pattern: '%s')\n" "$label" "$pattern"
    (( FAIL++ )) || true
    FAILURES+=("$label")
  fi
}

assert_exit_code() {
  local label="$1" expected="$2"; shift 2
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  assert_eq "$label" "$expected" "$actual"
}

assert_file_exists() {
  local label="$1" path="$2"
  if [[ -f "$path" ]]; then
    printf "  ${GREEN}PASS${RESET}: %s\n" "$label"
    (( PASS++ )) || true
  else
    printf "  ${RED}FAIL${RESET}: %s (not found: %s)\n" "$label" "$path"
    (( FAIL++ )) || true
    FAILURES+=("$label")
  fi
}

assert_file_contains() {
  local label="$1" needle="$2" file="$3"
  if grep -q "$needle" "$file" 2>/dev/null; then
    printf "  ${GREEN}PASS${RESET}: %s\n" "$label"
    (( PASS++ )) || true
  else
    printf "  ${RED}FAIL${RESET}: %s (missing '%s' in %s)\n" "$label" "$needle" "$file"
    (( FAIL++ )) || true
    FAILURES+=("$label")
  fi
}

assert_valid_json() {
  local label="$1" string="$2"
  if command -v jq >/dev/null 2>&1 && echo "$string" | jq . >/dev/null 2>&1; then
    printf "  ${GREEN}PASS${RESET}: %s\n" "$label"
    (( PASS++ )) || true
  elif ! command -v jq >/dev/null 2>&1; then
    skip "$label" "jq not available"
  else
    printf "  ${RED}FAIL${RESET}: %s (invalid JSON)\n" "$label"
    (( FAIL++ )) || true
    FAILURES+=("$label")
  fi
}

# ── Validator Helpers ──

VALIDATOR_OUTPUT=""
VALIDATOR_EXIT=0

run_validator() {
  local script="$1"; shift
  VALIDATOR_OUTPUT=$(bash "$script" "$@" 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
}

assert_passes() {
  local label="$1"
  if [[ $VALIDATOR_EXIT -eq 0 ]]; then
    printf "  ${GREEN}PASS${RESET}: %s\n" "$label"
    (( PASS++ )) || true
  else
    printf "  ${RED}FAIL${RESET}: %s (exit code: %d)\n" "$label" "$VALIDATOR_EXIT"
    (( FAIL++ )) || true
    FAILURES+=("$label")
  fi
}

assert_fails() {
  local label="$1"
  if [[ $VALIDATOR_EXIT -ne 0 ]]; then
    printf "  ${GREEN}PASS${RESET}: %s\n" "$label"
    (( PASS++ )) || true
  else
    printf "  ${RED}FAIL${RESET}: %s (expected failure, got exit 0)\n" "$label"
    (( FAIL++ )) || true
    FAILURES+=("$label")
  fi
}

assert_output_contains() {
  local label="$1" pattern="$2"
  if echo "$VALIDATOR_OUTPUT" | grep -qiE "$pattern"; then
    printf "  ${GREEN}PASS${RESET}: %s\n" "$label"
    (( PASS++ )) || true
  else
    printf "  ${RED}FAIL${RESET}: %s (pattern not found: '%s')\n" "$label" "$pattern"
    (( FAIL++ )) || true
    FAILURES+=("$label")
  fi
}

assert_output_not_contains() {
  local label="$1" pattern="$2"
  if ! echo "$VALIDATOR_OUTPUT" | grep -qiE "$pattern"; then
    printf "  ${GREEN}PASS${RESET}: %s\n" "$label"
    (( PASS++ )) || true
  else
    printf "  ${RED}FAIL${RESET}: %s (unexpected pattern found: '%s')\n" "$label" "$pattern"
    (( FAIL++ )) || true
    FAILURES+=("$label")
  fi
}

# ── Setup / Teardown ──

setup_tmpdir() {
  TEST_TMPDIR=$(mktemp -d)
  on_cleanup "rm -rf '$TEST_TMPDIR'"
}

on_cleanup() {
  _CLEANUP_CMDS+=("$1")
}

skip() {
  local label="$1" reason="${2:-}"
  if [[ -n "$reason" ]]; then
    printf "  ${YELLOW}SKIP${RESET}: %s (%s)\n" "$label" "$reason"
  else
    printf "  ${YELLOW}SKIP${RESET}: %s\n" "$label"
  fi
  (( SKIP++ )) || true
}

# ── Summary (auto-runs on exit) ──

_test_cleanup() {
  for cmd in "${_CLEANUP_CMDS[@]+"${_CLEANUP_CMDS[@]}"}"; do
    eval "$cmd" 2>/dev/null || true
  done
}

test_summary() {
  echo ""
  printf "=== Results: ${GREEN}%d passed${RESET}, ${RED}%d failed${RESET}, ${YELLOW}%d skipped${RESET} / %d total ===\n" \
    "$PASS" "$FAIL" "$SKIP" "$((PASS + FAIL + SKIP))"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
      printf "  - %s\n" "$f"
    done
  fi
  _test_cleanup
  exit "$FAIL"
}

trap test_summary EXIT
```

### Migration Path for Existing Tests

**session-autopilot** (47 tests): Replace inline `assert_eq`/`assert_contains` definitions with `source ../../tests/harness.sh`. Existing tests continue working — the harness API is a superset of the existing helpers.

**CCDK** (94 tests): Replace inline `pass()`/`fail()`/`skip()` and `run_validator` definitions. The shared harness provides identical functions. CCDK tests gain `assert_eq`, `assert_file_exists`, etc. for free.

---

## 4. Per-Plugin Test Plan

### archaeology

| Aspect | Details |
|--------|---------|
| **Exists** | 14 YAML evals, 3 evals/ validators (`validate-scripts.sh`, `validate-skill-content.sh`, `validate-structure.sh`), 3 scripts/ validators (`validate-conserve.sh`, `validate-dig.sh`, `validate-domains.sh`), no unit tests |
| **Shell-testable** | `arch-score.sh` (scoring algorithm: `extract_frontmatter`, `parse_keyword_list`, `count_keyword_in_file`, `parse_registry`), `arch-cache.sh` (caching: `file_mtime`, `cache_key`, `process_session`), `arch-profile.sh` (`ext_to_lang`), `archaeology-excavation.sh` (`to_slug`, `is_survey_fresh`, `json_escape`). **Note:** these scripts have no `BASH_SOURCE` guard — they must be tested via subprocess, not sourcing. |
| **Fixture-testable** | Validators already exist; need fixture tests like CCDK pattern for `scripts/validate-conserve.sh` (13 checks) and `scripts/validate-dig.sh` (13 checks) |
| **Add** | `tests/test-arch-score.sh` (10+ tests for scoring algorithm), `tests/test-arch-cache.sh` (5+ tests for cache TTL logic), `tests/test-excavation.sh` (5+ tests for slug/freshness), `evals/tests/test-validate-conserve.sh` + fixtures, `evals/tests/test-validate-dig.sh` + fixtures, `Makefile` |
| **Effort** | L |
| **Priority** | Medium (rich scripts, already has validators, needs unit test layer) |

### claude-code-development-kit

| Aspect | Details |
|--------|---------|
| **Exists** | 94 tests across 4 suites + fixtures, 10 validators, `_schema-validate.sh`, no Makefile |
| **Shell-testable** | `_schema-validate.sh` helper functions |
| **Fixture-testable** | All 10 validators; 4 already have fixture tests, 6 missing (`validate-hook.sh`, `validate-references.sh`, `validate-output-style.sh`, `validate-marketplace.sh`, `validate-structure.sh`, `validate-research-output.sh`) |
| **Add** | `Makefile`, fixture tests for 6 remaining validators, complete TODO items in `validate-command.sh` |
| **Effort** | M |
| **Priority** | Medium (best covered plugin after session-autopilot, incremental improvements) |

### expert-review

| Aspect | Details |
|--------|---------|
| **Exists** | `validate-structure.sh` only |
| **Shell-testable** | `validate-worktree.sh` (path traversal, canonical path, containment check, worktree limit), `checkpoint-detector.sh` (regex pattern matching against transcripts) |
| **Fixture-testable** | `validate-worktree.sh` against crafted path inputs |
| **Add** | `tests/test-validate-worktree.sh` (8+ tests: path traversal, protected paths, worktree limits), `tests/test-checkpoint-detector.sh` (5+ tests: pattern matching), `tests/fixtures/` with good/bad paths, `Makefile` |
| **Effort** | M |
| **Priority** | High (security-critical path validation has zero tests) |

### gen-plugin

| Aspect | Details |
|--------|---------|
| **Exists** | `validate-structure.sh` only |
| **Shell-testable** | None (skills are prompt-only, no runtime scripts) |
| **Fixture-testable** | Structure validator |
| **Add** | `Makefile`, verify `validate-structure.sh` covers all 3 skills |
| **Effort** | S |
| **Priority** | Low (spec-only plugin, minimal runtime risk) |

### knowledge-harvester

| Aspect | Details |
|--------|---------|
| **Exists** | Nothing — 0 tests, no `validate-structure.sh`, no Makefile |
| **Python-testable** | `checkpoint.py` (state management — `CheckpointManager` class, needs `workspace: Path` + `harvest_id: str` in constructor), `triage.py` (scoring — `TriageScorer.calculate_combined_score` takes `scores: dict`), `sanitize.py` (path/glob/shell quoting — pure functions), `enumerate.py` (file discovery), `extract.py` (finding validation), `synthesize.py` (finding categorization), `orchestrator.py` (pipeline coordination — harder to unit test, integration-level) |
| **Shell-testable** | `harvest.sh` (orchestration, but linear — limited unit value) |
| **Add** | `evals/validate-structure.sh`, `tests/test_checkpoint.py` (8+ tests), `tests/test_triage.py` (10+ tests), `tests/test_sanitize.py` (12+ tests), `tests/test_extract.py` (6+ tests), `tests/test_synthesize.py` (6+ tests), `tests/test_enumerate.py` (4+ tests), `Makefile` |
| **Effort** | L |
| **Priority** | High (largest untested codebase — 7 Python modules, 40+ methods, 0 tests) |

### mode-plugin

| Aspect | Details |
|--------|---------|
| **Exists** | `validate-structure.sh` only |
| **Shell-testable** | None (commands are prompt-only `.md` files) |
| **Fixture-testable** | Structure validator; command frontmatter can be validated via CCDK's `validate-command.sh` |
| **Add** | `Makefile`, add CCDK command validation for all 5 command files |
| **Effort** | S |
| **Priority** | High (frequently used plugin, should at least validate commands properly) |

### orchestration-toolkit

| Aspect | Details |
|--------|---------|
| **Exists** | 5 YAML evals, `validate-structure.sh` |
| **Shell-testable** | `build-capability-registry.sh` (9 functions: `log`, `extract_frontmatter_field`, `extract_description`, `infer_domain_tags`, `is_plugin_installed`, `is_plugin_blocked`, `add_entry`, `scan_plugin_dir`, `add_builtin`). **Note:** script has no `BASH_SOURCE` guard — must be tested via subprocess or by extracting functions. |
| **Fixture-testable** | Registry builder against mock plugin directories |
| **Add** | `tests/test-capability-registry.sh` (12+ tests for registry functions), `tests/fixtures/` with mock plugin dirs, `Makefile` |
| **Effort** | M |
| **Priority** | Medium (registry builder is a critical shared component) |

### plugin-profile

| Aspect | Details |
|--------|---------|
| **Exists** | `validate-structure.sh` only |
| **Shell-testable** | `shared/scripts/detect.sh` (language detection chain, confidence scoring, JSON output — no named functions, test via subprocess I/O), `shared/scripts/apply.sh` (profile inheritance, cycle detection: `extract_plugins`, `get_parent_profile`, `collect_all_plugins`), `shared/scripts/validate.sh` (conflict evaluation: `error_json`, `is_enabled`) |
| **Fixture-testable** | Detection against mock project directories, apply against mock profile YAML files |
| **Add** | `tests/test-detect.sh` (8+ tests: language detection priority chain, confidence values), `tests/test-apply.sh` (8+ tests: inheritance, cycle detection, plugin collection), `tests/test-validate.sh` (5+ tests: conflict rules), `tests/fixtures/` with mock projects + profiles, `Makefile` |
| **Effort** | L |
| **Priority** | High (3 core scripts with complex logic, all untested) |

### quality-assurance-toolkit

| Aspect | Details |
|--------|---------|
| **Exists** | 5 YAML evals, `validate-structure.sh` |
| **Shell-testable** | None (skill is prompt-only, no runtime scripts) |
| **Fixture-testable** | Structure validator |
| **Add** | `Makefile`, verify structure validator coverage |
| **Effort** | S |
| **Priority** | High (but limited scope — mainly needs proper Makefile + validate-structure.sh review) |

### session-autopilot

| Aspect | Details |
|--------|---------|
| **Exists** | 47–50 tests across 4 files, `Makefile` with `test` + `lint` targets |
| **Shell-testable** | Already well-covered |
| **Add** | Migrate to shared harness (remove inline assert definitions), verify all `common.sh` functions have coverage (several are implicit-only) |
| **Effort** | S |
| **Priority** | Low (already the best-tested plugin — migration only) |

### session-budget

| Aspect | Details |
|--------|---------|
| **Exists** | Nothing — 0 tests, no validators, no Makefile |
| **Shell-testable** | `hooks/scripts/budget-tracker.sh` (threshold math: consumed = points_completed + points_in_progress, three warning levels), `hooks/scripts/session-start.sh` (initialization) |
| **Add** | `evals/validate-structure.sh`, `tests/test-budget-tracker.sh` (8+ tests: threshold boundaries, JSON output format), `tests/fixtures/` with mock `budget.json` files (need `points_completed`, `points_in_progress`, `tasks` fields), `Makefile` |
| **Effort** | M |
| **Priority** | Medium (small surface area but zero coverage) |

### unicode-library

| Aspect | Details |
|--------|---------|
| **Exists** | Nothing — 0 tests, no validators, no Makefile |
| **Shell-testable** | None (spec-only plugin, no runtime scripts) |
| **Add** | `evals/validate-structure.sh`, `Makefile` |
| **Effort** | S |
| **Priority** | Low (no runtime to test, structure validation only) |

---

## 5. Summary Matrix

| Plugin | Structure | Unit (sh) | Unit (py) | Integration | Fixture | Eval Spec | Effort | Priority |
|--------|-----------|-----------|-----------|-------------|---------|-----------|--------|----------|
| archaeology | ✅ | ❌ → add | — | — | ❌ → add | ✅ (14) | L | Medium |
| ccdk | ✅ | — | — | — | ✅ partial → complete (6 remaining) | — | M | Medium |
| expert-review | ✅ | ❌ → add | — | — | — | — | M | High |
| gen-plugin | ✅ | — | — | — | — | — | S | Low |
| knowledge-harvester | ❌ → add | — | ❌ → add | — | — | — | L | High |
| mode-plugin | ✅ | — | — | — | — | — | S | High |
| orchestration-toolkit | ✅ | ❌ → add | — | — | — | ✅ (5) | M | Medium |
| plugin-profile | ✅ | ❌ → add | — | ❌ → add | — | — | L | High |
| quality-assurance-toolkit | ✅ | — | — | — | — | ✅ (5) | S | High |
| session-autopilot | ❌ → add | ✅ | — | ✅ | — | — | S | Low |
| session-budget | ❌ → add | ❌ → add | — | — | — | — | M | Medium |
| unicode-library | ❌ → add | — | — | — | — | — | S | Low |

**Legend:** ✅ = exists, ❌ → add = missing and planned, — = not applicable
