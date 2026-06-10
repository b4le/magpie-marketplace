#!/usr/bin/env bash
# Integration test for checkpoint.sh
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

echo "=== Testing checkpoint.sh ==="

# Use current project as the test target
repo_dir="$(git -C "${SCRIPT_DIR}/.." rev-parse --show-toplevel)"
branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)
safe_branch=$(printf '%s' "$branch" | tr '/' '-')

# Run checkpoint.sh with simulated hook input
echo '{"cwd":"'"$repo_dir"'"}' | bash "${SCRIPT_DIR}/../scripts/checkpoint.sh"

checkpoint_file="${repo_dir}/.claude/handoffs/.checkpoint_${safe_branch}.md"

# Verify file was created
[[ -f "$checkpoint_file" ]]
assert_eq "checkpoint file exists" "0" "$?"

# Verify content
content=$(cat "$checkpoint_file")
assert_contains "has Checkpoint header" "# Checkpoint" "$content"
assert_contains "has Updated field" "**Updated:**" "$content"
assert_contains "has Branch field" "**Branch:** ${branch}" "$content"
assert_contains "has HEAD field" "**HEAD:**" "$content"
assert_contains "has Git State section" "## Git State" "$content"

# Clean up
rm -f "$checkpoint_file"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
exit "$FAIL"
