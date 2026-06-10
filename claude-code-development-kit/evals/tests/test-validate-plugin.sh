#!/usr/bin/env bash
# Test suite for evals/validate-plugin.sh
#
# Usage:
#   ./test-validate-plugin.sh
#   VERBOSE=1 ./test-validate-plugin.sh   # show validator output on failure
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/../validate-plugin.sh"
FIXTURES="$SCRIPT_DIR/fixtures/plugins"

# ---------------------------------------------------------------------------
# Test runner state
# ---------------------------------------------------------------------------

PASS=0
FAIL=0
SKIP=0
FAILURES=()

# ANSI colours — disabled when not a TTY
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  RESET='\033[0m'
else
  GREEN=''
  RED=''
  YELLOW=''
  RESET=''
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

pass() { printf "${GREEN}PASS${RESET} %s\n" "$1"; (( PASS++ )) || true; }
fail() {
  printf "${RED}FAIL${RESET} %s\n" "$1"
  (( FAIL++ )) || true
  FAILURES+=("$1")
  if [[ "${VERBOSE:-}" == "1" && -n "${LAST_OUTPUT:-}" ]]; then
    echo "  --- output ---"
    echo "$LAST_OUTPUT" | head -20 | sed 's/^/  /'
    echo "  ---"
  fi
}
skip() { printf "${YELLOW}SKIP${RESET} %s — %s\n" "$1" "$2"; (( SKIP++ )) || true; }

# run_validator <plugin-root>
# Sets VALIDATOR_EXIT and VALIDATOR_OUTPUT
run_validator() {
  local plugin_root="$1"
  LAST_OUTPUT=""
  VALIDATOR_OUTPUT=$(bash "$VALIDATOR" "$plugin_root" 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
  LAST_OUTPUT="$VALIDATOR_OUTPUT"
}

# assert_passes <test-name>
assert_passes() {
  local name="$1"
  if [[ $VALIDATOR_EXIT -eq 0 ]]; then
    pass "$name"
  else
    fail "$name (expected exit 0, got $VALIDATOR_EXIT)"
  fi
}

# assert_fails <test-name>
assert_fails() {
  local name="$1"
  if [[ $VALIDATOR_EXIT -ne 0 ]]; then
    pass "$name"
  else
    fail "$name (expected exit 1, got $VALIDATOR_EXIT)"
  fi
}

# assert_output_contains <test-name> <pattern>
assert_output_contains() {
  local name="$1"
  local pattern="$2"
  if echo "$VALIDATOR_OUTPUT" | grep -qiE "$pattern"; then
    pass "$name"
  else
    fail "$name (output missing pattern: $pattern)"
  fi
}

# assert_output_not_contains <test-name> <pattern>
assert_output_not_contains() {
  local name="$1"
  local pattern="$2"
  if echo "$VALIDATOR_OUTPUT" | grep -qiE "$pattern"; then
    fail "$name (output unexpectedly contains: $pattern)"
  else
    pass "$name"
  fi
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

echo ""
echo "=== validate-plugin.sh tests ==="
echo ""

if [[ ! -f "$VALIDATOR" ]]; then
  echo "ERROR: Validator not found at $VALIDATOR"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required to run validator tests."
  exit 1
fi

# ---------------------------------------------------------------------------
# Section 1: Good plugin
# ---------------------------------------------------------------------------

echo "-- Section 1: Valid plugin --"

# tc01: Good plugin passes validation
run_validator "$FIXTURES/good"
assert_passes "tc01: good plugin passes validation"

# tc02: Good plugin output contains PASS for name
assert_output_contains "tc02: output shows name present" "name.*test-good-plugin|Required field.*name"

# tc03: Good plugin output shows version
assert_output_contains "tc03: output shows version present" "version.*1\\.0\\.0|Field.*version"

# ---------------------------------------------------------------------------
# Section 2: Plugin.json location
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 2: Plugin.json location --"

# tc04: Plugin.json in .claude-plugin/ directory
run_validator "$FIXTURES/dot-claude-plugin"
assert_passes "tc04: plugin.json in .claude-plugin/ passes"

# tc05: Plugin.json in .claude-plugin/ is detected
assert_output_contains "tc05: detects .claude-plugin/ location" "claude-plugin|marketplace location"

# ---------------------------------------------------------------------------
# Section 3: Missing fields
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 3: Missing fields --"

# tc06: Missing name causes error
run_validator "$FIXTURES/missing-name"
assert_fails "tc06: missing name fails validation"

# tc07: Missing name error message present
assert_output_contains "tc07: error mentions missing name" "name.*missing|Required.*name"

# ---------------------------------------------------------------------------
# Section 4: Invalid JSON
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 4: Invalid JSON --"

# tc08: Invalid JSON fails
run_validator "$FIXTURES/invalid-json"
assert_fails "tc08: invalid JSON fails validation"

# tc09: Invalid JSON error message
assert_output_contains "tc09: error mentions invalid JSON" "not valid JSON|invalid.*JSON"

# ---------------------------------------------------------------------------
# Section 5: Explicit component arrays (rejected by Claude Code)
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 5: Explicit component array warning --"

# tc10: Manifest with explicit skills/commands/agents arrays fails schema validation.
# Claude Code's internal validator rejects these fields; our schema now also rejects them
# via additionalProperties: false, so the validator exits 1.
run_validator "$FIXTURES/missing-components"
assert_fails "tc10: manifest with explicit component arrays fails schema validation"

# tc11: Schema error mentions the unexpected fields
assert_output_contains "tc11: schema error mentions unexpected fields" "Additional properties|unexpected|explicit component"

# tc12: Warning advises auto-discovery
assert_output_contains "tc12: warning mentions auto-discovery" "auto-discover|conventional director"

# ---------------------------------------------------------------------------
# Section 6: Documentation
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 6: Documentation --"

# tc13: No README generates error
run_validator "$FIXTURES/no-readme"
# no-readme still passes if only warnings — but README is an error
assert_output_contains "tc13: missing README flagged" "README.*not found|README"

# ---------------------------------------------------------------------------
# Section 7: No plugin.json at all
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 7: No plugin.json --"

# tc14: Directory with no plugin.json
TMPDIR_TC14=$(mktemp -d)
mkdir -p "$TMPDIR_TC14"
echo "# Empty" > "$TMPDIR_TC14/README.md"
run_validator "$TMPDIR_TC14"
assert_fails "tc14: no plugin.json fails"
rm -rf "$TMPDIR_TC14"

# tc15: Error mentions plugin.json not found
assert_output_contains "tc15: error mentions plugin.json not found" "plugin\\.json not found"

# ---------------------------------------------------------------------------
# Section 8: Non-existent directory
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 8: Non-existent directory --"

# tc16: Non-existent directory
run_validator "/tmp/nonexistent-plugin-dir-$$"
assert_fails "tc16: non-existent directory fails"

# ---------------------------------------------------------------------------
# Section 9: --help flag
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 9: Help flag --"

# tc17: --help exits 0
VALIDATOR_OUTPUT=$(bash "$VALIDATOR" --help 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
LAST_OUTPUT="$VALIDATOR_OUTPUT"
if [[ $VALIDATOR_EXIT -eq 0 ]]; then
  pass "tc17: --help exits 0"
else
  fail "tc17: --help exits 0 (got $VALIDATOR_EXIT)"
fi

# tc18: --help output contains usage
assert_output_contains "tc18: --help shows usage" "USAGE|Usage|usage"

# ---------------------------------------------------------------------------
# Section 10: Schema validation
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 10: Schema validation --"

# tc19: Good plugin with schema validation available
if python3 -c "import jsonschema, json" 2>/dev/null; then
  run_validator "$FIXTURES/good"
  assert_output_contains "tc19: schema validation ran" "schema validation|Schema"
else
  skip "tc19: schema validation available" "python3 jsonschema not installed"
fi

# tc20: Schema validation on invalid JSON is not attempted
run_validator "$FIXTURES/invalid-json"
assert_output_not_contains "tc20: schema not attempted on invalid JSON" "passes schema validation"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

TOTAL=$(( PASS + FAIL + SKIP ))
echo ""
echo "==================================================="
printf "Results: ${GREEN}%d passed${RESET}, ${RED}%d failed${RESET}, ${YELLOW}%d skipped${RESET} / %d total\n" \
  "$PASS" "$FAIL" "$SKIP" "$TOTAL"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for f in "${FAILURES[@]}"; do
    printf "  ${RED}✗${RESET} %s\n" "$f"
  done
fi

echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
