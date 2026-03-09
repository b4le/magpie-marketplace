#!/usr/bin/env bash
# Test suite for evals/validate-skill.sh
#
# Usage:
#   ./test-validate-skill.sh
#   VERBOSE=1 ./test-validate-skill.sh   # show validator output on failure
#
# Exit codes:
#   0 — all tests passed
#   1 — one or more tests failed

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/../validate-skill.sh"
FIXTURES="$SCRIPT_DIR/fixtures/skills"

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
  local skill_path="$1"
  shift
  LAST_OUTPUT=""
  VALIDATOR_OUTPUT=$(bash "$VALIDATOR" "$@" "$skill_path" 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
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
echo "=== validate-skill.sh tests ==="
echo ""

if [[ ! -f "$VALIDATOR" ]]; then
  echo "ERROR: Validator not found at $VALIDATOR"
  exit 1
fi

# ---------------------------------------------------------------------------
# Section 1: Good skill
# ---------------------------------------------------------------------------

echo "-- Section 1: Valid skill --"

# tc01: Good skill passes
run_validator "$FIXTURES/good"
assert_passes "tc01: good skill passes validation"

# tc02: Output confirms name present
assert_output_contains "tc02: output shows name present" "name.*present"

# tc03: Output confirms description present
assert_output_contains "tc03: output shows description present" "description.*present"

# ---------------------------------------------------------------------------
# Section 2: Missing frontmatter
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 2: Missing frontmatter --"

# tc04: No frontmatter fails
run_validator "$FIXTURES/missing-frontmatter"
assert_fails "tc04: missing frontmatter fails"

# tc05: Error mentions frontmatter
assert_output_contains "tc05: error mentions frontmatter" "frontmatter"

# ---------------------------------------------------------------------------
# Section 3: Missing fields
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 3: Missing fields --"

# tc06: Missing name
run_validator "$FIXTURES/missing-name"
assert_fails "tc06: missing name fails"
assert_output_contains "tc07: error mentions missing name" "name.*missing"

# tc08: Missing description
run_validator "$FIXTURES/missing-description"
assert_fails "tc08: missing description fails"
assert_output_contains "tc09: error mentions missing description" "description.*missing"

# ---------------------------------------------------------------------------
# Section 4: Line count
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 4: Line count --"

# tc10: File over 500 lines fails
TMPDIR_TC10=$(mktemp -d)
cat > "$TMPDIR_TC10/SKILL.md" << 'HEADER'
---
name: too-long
description: A skill that is over 500 lines long and should fail the line count check from the validator
allowed-tools:
  - Read
---

HEADER
# Generate lines to exceed 500
for i in $(seq 1 500); do
  echo "Line $i of filler content." >> "$TMPDIR_TC10/SKILL.md"
done
run_validator "$TMPDIR_TC10"
assert_fails "tc10: >500 lines fails"
assert_output_contains "tc11: error mentions line count" "500|exceed|lines"
rm -rf "$TMPDIR_TC10"

# ---------------------------------------------------------------------------
# Section 5: @path imports
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 5: @path imports --"

# tc12: Broken import gets warning
run_validator "$FIXTURES/broken-import"
# The validator treats unresolved imports as warnings, not errors
assert_output_contains "tc12: broken import flagged" "import.*may not resolve|resolve|nonexistent"

# ---------------------------------------------------------------------------
# Section 6: Personal identifiers
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 6: Personal identifiers --"

# tc13: Personal path detected
run_validator "$FIXTURES/personal-path"
assert_fails "tc13: personal path fails"
assert_output_contains "tc14: error mentions personal identifier" "personal.*identifier|/Users/johndoe"

# ---------------------------------------------------------------------------
# Section 7: Schema validation
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 7: Schema validation --"

if python3 -c "import jsonschema, yaml" 2>/dev/null; then
  # tc15: Good skill passes schema
  run_validator "$FIXTURES/good"
  assert_output_contains "tc15: schema validation ran" "schema validation|Schema"

  # tc15b: Optional fields pass schema validation
  run_validator "$FIXTURES/good-optional-fields"
  assert_passes "tc15b: optional fields pass schema"

  # tc16: Schema catches unknown fields
  TMPDIR_TC16=$(mktemp -d)
  cat > "$TMPDIR_TC16/SKILL.md" << 'EOF'
---
name: bad-field
description: A skill with an unknown field to test additionalProperties validation from the schema
bogus-field: this-is-not-allowed
allowed-tools:
  - Read
---

Content of the skill.
EOF
  run_validator "$TMPDIR_TC16"
  assert_output_contains "tc16: schema catches unknown field" "schema.*error|additional|bogus"
  rm -rf "$TMPDIR_TC16"
else
  skip "tc15: schema validation" "python3 jsonschema/pyyaml not installed"
  skip "tc15b: optional fields" "python3 jsonschema/pyyaml not installed"
  skip "tc16: schema catches unknown field" "python3 jsonschema/pyyaml not installed"
fi

# ---------------------------------------------------------------------------
# Section 8: --hook-mode
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 8: Hook mode --"

# tc17: Hook mode outputs JSON on pass
HOOK_OUTPUT=$(bash "$VALIDATOR" --hook-mode "$FIXTURES/good/SKILL.md" 2>&1) && HOOK_EXIT=0 || HOOK_EXIT=$?
if echo "$HOOK_OUTPUT" | jq -e '.status' &>/dev/null; then
  pass "tc17: hook mode outputs valid JSON"
else
  fail "tc17: hook mode outputs valid JSON (got: ${HOOK_OUTPUT:0:80})"
fi

# tc18: Hook mode status is pass for good skill
HOOK_STATUS=$(echo "$HOOK_OUTPUT" | jq -r '.status' 2>/dev/null || echo "unknown")
if [[ "$HOOK_STATUS" == "pass" ]]; then
  pass "tc18: hook mode status is 'pass'"
else
  fail "tc18: hook mode status is 'pass' (got: $HOOK_STATUS)"
fi

# tc19: Hook mode on missing frontmatter returns fail
HOOK_OUTPUT=$(bash "$VALIDATOR" --hook-mode "$FIXTURES/missing-frontmatter/SKILL.md" 2>&1) && HOOK_EXIT=0 || HOOK_EXIT=$?
HOOK_STATUS=$(echo "$HOOK_OUTPUT" | jq -r '.status' 2>/dev/null || echo "unknown")
if [[ "$HOOK_STATUS" == "fail" ]]; then
  pass "tc19: hook mode returns fail for bad skill"
else
  fail "tc19: hook mode returns fail for bad skill (got: $HOOK_STATUS)"
fi

# ---------------------------------------------------------------------------
# Section 9: Edge cases
# ---------------------------------------------------------------------------

echo ""
echo "-- Section 9: Edge cases --"

# tc20: --help exits 0
VALIDATOR_OUTPUT=$(bash "$VALIDATOR" --help 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
LAST_OUTPUT="$VALIDATOR_OUTPUT"
if [[ $VALIDATOR_EXIT -eq 0 ]]; then
  pass "tc20: --help exits 0"
else
  fail "tc20: --help exits 0 (got $VALIDATOR_EXIT)"
fi

# tc21: No arguments exits non-zero
VALIDATOR_OUTPUT=$(bash "$VALIDATOR" 2>&1) && VALIDATOR_EXIT=0 || VALIDATOR_EXIT=$?
LAST_OUTPUT="$VALIDATOR_OUTPUT"
if [[ $VALIDATOR_EXIT -ne 0 ]]; then
  pass "tc21: no arguments exits non-zero"
else
  fail "tc21: no arguments exits non-zero (got $VALIDATOR_EXIT)"
fi

# tc22: Non-existent directory fails
run_validator "/tmp/nonexistent-skill-dir-$$"
assert_fails "tc22: non-existent directory fails"

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
