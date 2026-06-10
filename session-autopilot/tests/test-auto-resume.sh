#!/usr/bin/env bash
# Integration test for auto-resume.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "    expected: $(printf '%q' "$expected")"
    echo "    actual:   $(printf '%q' "$actual")"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (missing: '$needle')"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Testing auto-resume.sh ==="

repo_dir="$(git -C "${SCRIPT_DIR}/.." rev-parse --show-toplevel)"
branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)
safe_branch=$(printf '%s' "$branch" | tr '/' '-')
handoffs_dir="${repo_dir}/.claude/handoffs"
mkdir -p "$handoffs_dir"

# --- Test 1: Resumes from handoff file ---
echo ""
echo "--- Test: resumes from handoff file ---"

# Create a fake handoff file
cat > "${handoffs_dir}/${safe_branch}_20260304T180000Z.md" << 'HANDOFF'
# Session Handoff (auto)
**Updated:** 2026-03-04T18:00:00Z
**Branch:** main
**HEAD:** abc1234
HANDOFF

output=$(echo '{"cwd":"'"$repo_dir"'","source":"startup"}' \
  | bash "${SCRIPT_DIR}/../scripts/auto-resume.sh")

assert_contains "output has additionalContext" "additionalContext" "$output"
assert_contains "output has handoff content" "Session Handoff" "$output"

# Verify it's valid JSON (if jq available)
if command -v jq &>/dev/null; then
  echo "$output" | jq . > /dev/null 2>&1
  assert_eq "output is valid JSON" "0" "$?"
fi

rm -f "${handoffs_dir}/${safe_branch}_20260304T180000Z.md"

# --- Test 2: Falls back to checkpoint ---
echo ""
echo "--- Test: falls back to checkpoint ---"

cat > "${handoffs_dir}/.checkpoint_${safe_branch}.md" << 'CHECKPOINT'
# Checkpoint
**Updated:** 2026-03-04T17:00:00Z
**Branch:** main
**HEAD:** def5678
CHECKPOINT

output=$(echo '{"cwd":"'"$repo_dir"'","source":"startup"}' \
  | bash "${SCRIPT_DIR}/../scripts/auto-resume.sh")

assert_contains "checkpoint fallback has additionalContext" "additionalContext" "$output"
assert_contains "checkpoint fallback type" "checkpoint" "$output"

rm -f "${handoffs_dir}/.checkpoint_${safe_branch}.md"

# --- Test 3: Skips non-startup sources ---
echo ""
echo "--- Test: skips resume source ---"

cat > "${handoffs_dir}/${safe_branch}_20260304T180000Z.md" << 'HANDOFF'
# Session Handoff (auto)
**Updated:** 2026-03-04T18:00:00Z
HANDOFF

output=$(echo '{"cwd":"'"$repo_dir"'","source":"resume"}' \
  | bash "${SCRIPT_DIR}/../scripts/auto-resume.sh")

assert_eq "no output for resume source" "" "$output"

rm -f "${handoffs_dir}/${safe_branch}_20260304T180000Z.md"

# --- Test 4: Falls back to git inference ---
echo ""
echo "--- Test: falls back to git inference ---"

# Ensure no handoff or checkpoint files exist
rm -f "${handoffs_dir}/${safe_branch}_"*.md 2>/dev/null || true
rm -f "${handoffs_dir}/.checkpoint_${safe_branch}.md" 2>/dev/null || true

output=$(echo '{"cwd":"'"$repo_dir"'","source":"startup"}' \
  | bash "${SCRIPT_DIR}/../scripts/auto-resume.sh")

# Should get git-inference output (repo has commits)
assert_contains "git inference has additionalContext" "additionalContext" "$output"
assert_contains "git inference type" "inferred from git" "$output"

# --- Test 5: Collision detection ---
echo ""
echo "--- Test: collision detection ---"

cat > "${handoffs_dir}/${safe_branch}_20260304T180000Z.md" << 'HANDOFF'
# Session 1
HANDOFF
cat > "${handoffs_dir}/${safe_branch}_20260304T175900Z.md" << 'HANDOFF'
# Session 2
HANDOFF
# Touch both files so they appear recent and close together
touch "${handoffs_dir}/${safe_branch}_20260304T180000Z.md"
touch "${handoffs_dir}/${safe_branch}_20260304T175900Z.md"

output=$(echo '{"cwd":"'"$repo_dir"'","source":"startup"}' \
  | bash "${SCRIPT_DIR}/../scripts/auto-resume.sh")

assert_contains "collision mentions /pickup" "/pickup" "$output"
assert_contains "collision lists first filename" "${safe_branch}_20260304T180000Z.md" "$output"
assert_contains "collision lists second filename" "${safe_branch}_20260304T175900Z.md" "$output"
assert_contains "collision shows formatted date" "$(date '+%Y-%m-%d')" "$output"

# Must NOT contain the actual handoff content
if [[ "$output" == *"## Previous Session Context"* ]]; then
  echo "  FAIL: collision should not load handoff content"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: collision does not load handoff content"
  PASS=$((PASS + 1))
fi

# Collision output must be valid JSON
if command -v jq &>/dev/null; then
  echo "$output" | jq . > /dev/null 2>&1
  assert_eq "collision output is valid JSON" "0" "$?"
fi

rm -f "${handoffs_dir}/${safe_branch}_"*.md 2>/dev/null || true

# --- Test 6: Single handoff loads normally (no false collision) ---
echo ""
echo "--- Test: single handoff loads normally ---"

cat > "${handoffs_dir}/${safe_branch}_20260304T180000Z.md" << 'HANDOFF'
# Session Handoff (auto)
**Updated:** 2026-03-04T18:00:00Z
**Branch:** main
**HEAD:** abc1234
HANDOFF
touch "${handoffs_dir}/${safe_branch}_20260304T180000Z.md"

output=$(echo '{"cwd":"'"$repo_dir"'","source":"startup"}' \
  | bash "${SCRIPT_DIR}/../scripts/auto-resume.sh")

assert_contains "single handoff has content" "Session Handoff" "$output"
assert_contains "single handoff type label" "Previous Session Context (handoff)" "$output"
assert_contains "single handoff includes sha" "abc1234" "$output"

# Must NOT mention /pickup (no collision)
if [[ "$output" == *"/pickup"* ]]; then
  echo "  FAIL: single handoff should not trigger collision"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: single handoff does not trigger collision"
  PASS=$((PASS + 1))
fi

# Single handoff output must be valid JSON
if command -v jq &>/dev/null; then
  echo "$output" | jq . > /dev/null 2>&1
  assert_eq "single handoff output is valid JSON" "0" "$?"
fi

rm -f "${handoffs_dir}/${safe_branch}_"*.md 2>/dev/null || true

# --- Test 7: Two handoffs >1 hour apart do NOT collide ---
echo ""
echo "--- Test: no collision when handoffs are >1 hour apart ---"

cat > "${handoffs_dir}/${safe_branch}_20260304T180000Z.md" << 'HANDOFF'
# Session 1
HANDOFF
cat > "${handoffs_dir}/${safe_branch}_20260304T160000Z.md" << 'HANDOFF'
# Session 2
HANDOFF
# Touch first file now, second file >1 hour ago
touch "${handoffs_dir}/${safe_branch}_20260304T180000Z.md"
touch -t "$(date -v -3700S '+%Y%m%d%H%M.%S' 2>/dev/null \
  || date -d '3700 seconds ago' '+%Y%m%d%H%M.%S' 2>/dev/null)" \
  "${handoffs_dir}/${safe_branch}_20260304T160000Z.md"

output=$(echo '{"cwd":"'"$repo_dir"'","source":"startup"}' \
  | bash "${SCRIPT_DIR}/../scripts/auto-resume.sh")

assert_contains "no-collision loads handoff content" "Session 1" "$output"

# Must NOT mention /pickup
if [[ "$output" == *"/pickup"* ]]; then
  echo "  FAIL: >1 hour gap should not trigger collision"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: >1 hour gap does not trigger collision"
  PASS=$((PASS + 1))
fi

rm -f "${handoffs_dir}/${safe_branch}_"*.md 2>/dev/null || true

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
exit "$FAIL"
