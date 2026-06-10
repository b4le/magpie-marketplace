#!/usr/bin/env bash
# Test suite for common.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../scripts/lib/common.sh"

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

echo "=== Testing common.sh ==="

# --- sanitize_branch ---
echo ""
echo "--- sanitize_branch ---"
assert_eq "simple branch" "main" "$(sanitize_branch "main")"
assert_eq "slash branch" "feature-auth" "$(sanitize_branch "feature/auth")"
assert_eq "nested slash" "fix-ui-button" "$(sanitize_branch "fix/ui/button")"

# --- get_field ---
echo ""
echo "--- get_field ---"
HOOK_INPUT='{"cwd":"/tmp/project","session_id":"abc-123","source":"startup"}'
assert_eq "extract cwd" "/tmp/project" "$(get_field "cwd")"
assert_eq "extract session_id" "abc-123" "$(get_field "session_id")"
assert_eq "extract source" "startup" "$(get_field "source")"
assert_eq "missing field" "" "$(get_field "nonexistent")"

# --- timestamps ---
echo ""
echo "--- timestamps ---"
ts=$(utc_timestamp)
assert_eq "utc format length" "16" "${#ts}"
iso=$(iso_timestamp)
[[ "$iso" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
assert_eq "iso format matches" "0" "$?"

# --- json_encode ---
echo ""
echo "--- json_encode ---"
encoded=$(json_encode "hello world")
assert_eq "simple string" '"hello world"' "$encoded"
encoded=$(json_encode 'has "quotes"')
assert_eq "escaped quotes" '"has \"quotes\""' "$encoded"

# --- git helpers (current repo) ---
echo ""
echo "--- git helpers (current repo) ---"
repo_dir="$(git -C "${SCRIPT_DIR}/.." rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -n "$repo_dir" ]]; then
  branch=$(get_git_branch "$repo_dir")
  [[ -n "$branch" && "$branch" != "unknown" ]]
  assert_eq "git branch not empty" "0" "$?"
  sha=$(get_git_sha "$repo_dir")
  [[ -n "$sha" && "$sha" != "unknown" ]]
  assert_eq "git sha not empty" "0" "$?"
else
  echo "  SKIP: not in a git repo"
fi

# --- atomic_write ---
echo ""
echo "--- atomic_write ---"
tmpdir=$(mktemp -d)
atomic_write "${tmpdir}/test.md" "hello world"
content=$(cat "${tmpdir}/test.md")
assert_eq "atomic write content" "hello world" "$content"
rm -rf "$tmpdir"

# --- Summary ---
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
exit "$FAIL"
