#!/usr/bin/env bash
# Test suite for evals/validate-agent.sh
#
# Usage:
#   ./test-validate-agent.sh
#   VERBOSE=1 ./test-validate-agent.sh   # show validator output on failure
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/../validate-agent.sh"
FIXTURES="$SCRIPT_DIR/fixtures/agents"

# ---------------------------------------------------------------------------
# Test runner state
# ---------------------------------------------------------------------------

PASS=0
FAIL=0
SKIP=0
FAILURES=()

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

run_validator() {
  local agent_path="$1"
  LAST_OUTPUT=""
  VALIDATOR_OUTPUT=$(bash "$VALIDATOR" "$agent_path" 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
  LAST_OUTPUT="$VALIDATOR_OUTPUT"
}

assert_passes() {
  local name="$1"
  if [[ $VALIDATOR_EXIT -eq 0 ]]; then
    pass "$name"
  else
    fail "$name (expected exit 0, got $VALIDATOR_EXIT)"
  fi
}

assert_fails() {
  local name="$1"
  if [[ $VALIDATOR_EXIT -ne 0 ]]; then
    pass "$name"
  else
    fail "$name (expected exit 1, got $VALIDATOR_EXIT)"
  fi
}

assert_output_contains() {
  local name="$1"
  local pattern="$2"
  if echo "$VALIDATOR_OUTPUT" | grep -qiE "$pattern"; then
    pass "$name"
  else
    fail "$name (output missing pattern: $pattern)"
  fi
}

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
echo "=== validate-agent.sh tests ==="
echo ""

if [[ ! -f "$VALIDATOR" ]]; then
  echo "ERROR: Validator not found at $VALIDATOR"
  exit 1
fi

# ---------------------------------------------------------------------------
# Section 1: Good agent (.md)
# ---------------------------------------------------------------------------

echo "-- Section 1: Valid agent (.md) --"

# tc01: Good .md agent passes
run_validator "$FIXTURES/good-agent.md"
assert_passes "tc01: good .md agent passes validation"

# tc02: Output shows name present
assert_output_contains "tc02: output shows name present" "name.*present"

# tc03: Output shows description present
assert_output_contains "tc03: output shows description present" "description.*present"

# tc04: Output shows tools present
assert_output_contains "tc04: output shows tools present" "tools.*present|Tools.*present"

# tc05: Output shows valid model
assert_output_contains "tc05: output shows valid model" "model.*valid|Model.*sonnet"

# ---------------------------------------------------------------------------
# Section 2: Good agent (.yaml)
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 2: Valid agent (.yaml) --"

# tc06: Good .yaml agent passes
run_validator "$FIXTURES/good-agent.yaml"
assert_passes "tc06: good .yaml agent passes validation"

# tc07: YAML detection message
assert_output_contains "tc07: YAML agent detected" "YAML.*agent|yaml"

# ---------------------------------------------------------------------------
# Section 3: Name/filename mismatch
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 3: Name/filename mismatch --"

# tc08: Name mismatch fails
run_validator "$FIXTURES/name-mismatch.md"
assert_fails "tc08: name mismatch fails"

# tc09: Error mentions name mismatch
assert_output_contains "tc09: error mentions name mismatch" "name.*does not match|wrong-name.*name-mismatch"

# ---------------------------------------------------------------------------
# Section 4: Invalid model
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 4: Invalid model --"

# tc10: Invalid model fails
run_validator "$FIXTURES/invalid-model.md"
assert_fails "tc10: invalid model fails"

# tc11: Error mentions invalid model
assert_output_contains "tc11: error mentions invalid model" "invalid.*model|gpt4|must be opus|sonnet|haiku"

# ---------------------------------------------------------------------------
# Section 5: Missing tools
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 5: Missing tools --"

# tc12: Missing tools field fails
run_validator "$FIXTURES/missing-tools.md"
assert_fails "tc12: missing tools fails"

# tc13: Error mentions missing tools
assert_output_contains "tc13: error mentions missing tools" "tools.*missing|Required.*tools"

# ---------------------------------------------------------------------------
# Section 6: Missing name and description
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 6: Missing required fields --"

# tc14: Missing name fails
run_validator "$FIXTURES/missing-name.md"
assert_fails "tc14: missing name fails"
assert_output_contains "tc15: error mentions missing name" "name.*missing"

# tc16: Missing description fails
run_validator "$FIXTURES/missing-description.md"
assert_fails "tc16: missing description fails"
assert_output_contains "tc17: error mentions missing description" "description.*missing"

# tc18: Short description fails
run_validator "$FIXTURES/short-description.md"
assert_fails "tc18: short description fails"
assert_output_contains "tc19: error mentions short description" "too short|minimum.*20"

# ---------------------------------------------------------------------------
# Section 7: No frontmatter
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 7: No frontmatter --"

# tc20: No frontmatter fails
run_validator "$FIXTURES/no-frontmatter.md"
assert_fails "tc20: no frontmatter fails"
assert_output_contains "tc21: error mentions frontmatter" "frontmatter"

# ---------------------------------------------------------------------------
# Section 8: allowed-tools alias
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 8: allowed-tools alias --"

# tc22: Agent with allowed-tools passes
run_validator "$FIXTURES/allowed-tools-agent.md"
assert_passes "tc22: allowed-tools field accepted"
assert_output_contains "tc23: output shows tools present" "tools.*present|Tools.*present"

# ---------------------------------------------------------------------------
# Section 9: Personal identifiers
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 9: Personal identifiers --"

# tc24: Personal path detected
run_validator "$FIXTURES/personal-path.md"
assert_fails "tc24: personal path fails"
assert_output_contains "tc25: error mentions personal identifier" "personal.*identifier|/Users/johndoe"

# ---------------------------------------------------------------------------
# Section 10: Schema validation
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 10: Schema validation --"

if python3 -c "import jsonschema, yaml" 2>/dev/null; then
  # tc26: Schema validation runs on good agent
  run_validator "$FIXTURES/good-agent.md"
  assert_output_contains "tc26: schema validation ran" "schema|Schema"

  # tc26b: Optional fields pass schema validation (.md)
  run_validator "$FIXTURES/good-agent-optional-fields.md"
  assert_passes "tc26b: optional fields pass schema (.md)"

  # tc26c: Optional fields pass schema validation (.yaml)
  run_validator "$FIXTURES/good-agent-optional-fields.yaml"
  assert_passes "tc26c: optional fields pass schema (.yaml)"

  # tc26d: Snake_case field rejected by additionalProperties
  run_validator "$FIXTURES/invalid-snake-case-field.md"
  assert_fails "tc26d: snake_case field rejected"
  assert_output_contains "tc26e: error mentions schema" "schema.*error|additional"

  # tc26f: Extra unknown field rejected
  run_validator "$FIXTURES/invalid-extra-field.md"
  assert_fails "tc26f: extra field rejected"

  # tc26g: Invalid permission mode rejected
  run_validator "$FIXTURES/invalid-permission-mode.md"
  assert_fails "tc26g: invalid permission mode rejected"
else
  skip "tc26: schema validation" "python3 jsonschema/pyyaml not installed"
  skip "tc26b-g: schema rejection tests" "python3 jsonschema/pyyaml not installed"
fi

# ---------------------------------------------------------------------------
# Section 11: Edge cases
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 11: Edge cases --"

# tc27: --help exits 0
VALIDATOR_OUTPUT=$(bash "$VALIDATOR" --help 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
LAST_OUTPUT="$VALIDATOR_OUTPUT"
if [[ $VALIDATOR_EXIT -eq 0 ]]; then
  pass "tc27: --help exits 0"
else
  fail "tc27: --help exits 0 (got $VALIDATOR_EXIT)"
fi

# tc28: No arguments exits non-zero
VALIDATOR_OUTPUT=$(bash "$VALIDATOR" 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
LAST_OUTPUT="$VALIDATOR_OUTPUT"
if [[ $VALIDATOR_EXIT -ne 0 ]]; then
  pass "tc28: no arguments exits non-zero"
else
  fail "tc28: no arguments exits non-zero (got $VALIDATOR_EXIT)"
fi

# tc29: Non-existent file fails
run_validator "/tmp/nonexistent-agent-$$.md"
assert_fails "tc29: non-existent file fails"

# tc30: Non-.md/.yaml extension fails
TMPFILE=$(mktemp /tmp/test-agent-XXXXXX.txt)
echo "---" > "$TMPFILE"
echo "name: bad-ext" >> "$TMPFILE"
echo "---" >> "$TMPFILE"
run_validator "$TMPFILE"
assert_fails "tc30: non-.md/.yaml extension fails"
rm -f "$TMPFILE"

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
