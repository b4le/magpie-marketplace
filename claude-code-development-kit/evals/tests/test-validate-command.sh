#!/usr/bin/env bash
# Test suite for evals/validate-command.sh
#
# Usage:
#   ./test-validate-command.sh
#   VERBOSE=1 ./test-validate-command.sh   # show validator output on failure
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/../validate-command.sh"
FIXTURES="$SCRIPT_DIR/fixtures/commands"

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
  local cmd_path="$1"
  LAST_OUTPUT=""
  VALIDATOR_OUTPUT=$(bash "$VALIDATOR" "$cmd_path" 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
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
echo "=== validate-command.sh tests ==="
echo ""

if [[ ! -f "$VALIDATOR" ]]; then
  echo "ERROR: Validator not found at $VALIDATOR"
  exit 1
fi

# ---------------------------------------------------------------------------
# Section 1: Good command
# ---------------------------------------------------------------------------

echo "-- Section 1: Valid command --"

# tc01: Good command passes
run_validator "$FIXTURES/good.md"
assert_passes "tc01: good command passes validation"

# tc02: Output shows description present
assert_output_contains "tc02: output shows description present" "description.*present"

# tc03: Output shows name present
assert_output_contains "tc03: output shows name present" "name.*present|name.*good-command"

# ---------------------------------------------------------------------------
# Section 2: Missing frontmatter
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 2: Missing frontmatter --"

# tc04: No frontmatter fails
run_validator "$FIXTURES/missing-frontmatter.md"
assert_fails "tc04: missing frontmatter fails"

# tc05: Error mentions frontmatter
assert_output_contains "tc05: error mentions frontmatter" "frontmatter"

# ---------------------------------------------------------------------------
# Section 3: Missing description
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 3: Missing description --"

# tc06: Missing description fails
run_validator "$FIXTURES/missing-description.md"
assert_fails "tc06: missing description fails"

# tc07: Error mentions description
assert_output_contains "tc07: error mentions missing description" "description.*missing"

# ---------------------------------------------------------------------------
# Section 4: $ARGUMENTS handling
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 4: \$ARGUMENTS handling --"

# tc08: Command with $ARGUMENTS and docs passes
run_validator "$FIXTURES/with-arguments.md"
assert_passes "tc08: command with \$ARGUMENTS and docs passes"

# tc09: Output mentions $ARGUMENTS detected
assert_output_contains "tc09: output mentions \$ARGUMENTS" "ARGUMENTS"

# tc10: Output mentions arguments docs found
assert_output_contains "tc10: output mentions argument docs" "argument.*doc|Arguments.*found"

# tc11: Command with $ARGUMENTS but no docs gets warning
run_validator "$FIXTURES/with-arguments-no-docs.md"
assert_passes "tc11: \$ARGUMENTS without docs still passes (warning only)"
assert_output_contains "tc12: warning about missing argument docs" "ARGUMENTS.*no.*Argument|WARN"

# ---------------------------------------------------------------------------
# Section 5: user-invocable field
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 5: user-invocable field --"

# tc13: Command with user-invocable field passes
run_validator "$FIXTURES/user-invocable.md"
assert_passes "tc13: user-invocable command passes"

# ---------------------------------------------------------------------------
# Section 6: Body content checks
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 6: Body content --"

# tc14: Empty body gets warning
run_validator "$FIXTURES/empty-body.md"
# Empty body is a warning, not an error — should still pass
assert_output_contains "tc14: warning about empty/short body" "body.*empty|body.*short|WARN"

# ---------------------------------------------------------------------------
# Section 7: Personal identifiers
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 7: Personal identifiers --"

# tc15: Personal path detected
run_validator "$FIXTURES/personal-path.md"
assert_fails "tc15: personal path fails"
assert_output_contains "tc16: error mentions personal identifier" "personal.*identifier|/Users/johndoe"

# ---------------------------------------------------------------------------
# Section 8: Schema validation
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 8: Schema validation --"

if python3 -c "import jsonschema, yaml" 2>/dev/null; then
  # tc17: Good command passes schema
  run_validator "$FIXTURES/good.md"
  assert_output_contains "tc17: schema validation ran" "schema|Schema"

  # tc18: Unknown frontmatter field caught by schema
  TMPFILE=$(mktemp /tmp/test-cmd-XXXXXX.md)
  cat > "$TMPFILE" << 'EOF'
---
name: bad-field-cmd
description: A command with unknown fields to test schema additionalProperties check
bogus-field: this-is-not-allowed
---

This command has a bogus field.

## Purpose

Test schema validation catches extra fields.

## Usage

Do not use in production.
EOF
  run_validator "$TMPFILE"
  assert_output_contains "tc18: schema catches unknown field" "schema.*error|additional|bogus"
  rm -f "$TMPFILE"
else
  skip "tc17: schema validation" "python3 jsonschema/pyyaml not installed"
  skip "tc18: schema catches unknown field" "python3 jsonschema/pyyaml not installed"
fi

# ---------------------------------------------------------------------------
# Section 9: Edge cases
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 9: Edge cases --"

# tc19: --help exits 0
VALIDATOR_OUTPUT=$(bash "$VALIDATOR" --help 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
LAST_OUTPUT="$VALIDATOR_OUTPUT"
if [[ $VALIDATOR_EXIT -eq 0 ]]; then
  pass "tc19: --help exits 0"
else
  fail "tc19: --help exits 0 (got $VALIDATOR_EXIT)"
fi

# tc20: No arguments exits non-zero
VALIDATOR_OUTPUT=$(bash "$VALIDATOR" 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
LAST_OUTPUT="$VALIDATOR_OUTPUT"
if [[ $VALIDATOR_EXIT -ne 0 ]]; then
  pass "tc20: no arguments exits non-zero"
else
  fail "tc20: no arguments exits non-zero (got $VALIDATOR_EXIT)"
fi

# tc21: Non-existent file fails
run_validator "/tmp/nonexistent-command-$$.md"
assert_fails "tc21: non-existent file fails"

# tc22: Non-.md file extension fails
TMPFILE=$(mktemp /tmp/test-cmd-XXXXXX.txt)
echo "---" > "$TMPFILE"
echo "name: bad-ext" >> "$TMPFILE"
echo "description: Should fail because this file has a txt extension not md" >> "$TMPFILE"
echo "---" >> "$TMPFILE"
echo "Content." >> "$TMPFILE"
run_validator "$TMPFILE"
assert_fails "tc22: non-.md extension fails"
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
