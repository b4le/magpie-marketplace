#!/usr/bin/env bash
# Integration test for auto-handoff.sh
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

echo "=== Testing auto-handoff.sh ==="

repo_dir="$(git -C "${SCRIPT_DIR}/.." rev-parse --show-toplevel)"
branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)
safe_branch=$(printf '%s' "$branch" | tr '/' '-')
handoffs_dir="${repo_dir}/.claude/handoffs"

# Clean up any existing handoff files for this branch
rm -f "${handoffs_dir}/${safe_branch}_"*.md 2>/dev/null || true

# --- Test 1: Normal handoff creation ---
echo ""
echo "--- Test: creates handoff file ---"
echo '{"cwd":"'"$repo_dir"'","session_id":"test-session-001"}' \
  | bash "${SCRIPT_DIR}/../scripts/auto-handoff.sh"

handoff_file=$(ls -t "${handoffs_dir}/${safe_branch}_"*.md 2>/dev/null | head -1 || true)
[[ -n "$handoff_file" ]]
assert_eq "handoff file created" "0" "$?"

content=$(cat "$handoff_file")
assert_contains "has auto header" "# Session Handoff (auto)" "$content"
assert_contains "has branch" "**Branch:** ${branch}" "$content"
assert_contains "has HEAD" "**HEAD:**" "$content"
assert_contains "has session id" "test-session-001" "$content"
assert_contains "has Git State section" "## Git State" "$content"
assert_contains "has Changes section" "## Changes" "$content"
assert_contains "has Recent Commits section" "## Recent Commits" "$content"

# --- Test 2: Skip if recent file exists ---
echo ""
echo "--- Test: skips if recent handoff exists ---"
count_before=$(ls "${handoffs_dir}/${safe_branch}_"*.md 2>/dev/null | wc -l | tr -d ' ')

# Run again immediately (file was written < 60s ago)
echo '{"cwd":"'"$repo_dir"'","session_id":"test-session-002"}' \
  | bash "${SCRIPT_DIR}/../scripts/auto-handoff.sh"

count_after=$(ls "${handoffs_dir}/${safe_branch}_"*.md 2>/dev/null | wc -l | tr -d ' ')
assert_eq "no new file created (skip)" "$count_before" "$count_after"

# Clean up
rm -f "${handoffs_dir}/${safe_branch}_"*.md 2>/dev/null || true

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
exit "$FAIL"
