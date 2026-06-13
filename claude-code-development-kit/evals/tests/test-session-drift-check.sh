#!/usr/bin/env bash
# Regression tests for hooks/scripts/session-drift-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/scripts/session-drift-check.sh"

PASS=0
FAIL=0
FAILURES=()

if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  RESET='\033[0m'
else
  GREEN=''
  RED=''
  RESET=''
fi

pass() { printf "${GREEN}PASS${RESET} %s\n" "$1"; (( PASS++ )) || true; }
fail() {
  printf "${RED}FAIL${RESET} %s\n" "$1"
  (( FAIL++ )) || true
  FAILURES+=("$1")
}

assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name (expected '$expected', got '$actual')"
  fi
}

assert_contains() {
  local name="$1"
  local haystack="$2"
  local needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$name"
  else
    fail "$name (missing '$needle')"
  fi
}

echo ""
echo "=== session-drift-check.sh tests ==="
echo ""

if [[ ! -f "$HOOK" ]]; then
  echo "ERROR: Hook not found at $HOOK"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required to run session drift tests."
  exit 1
fi
REAL_JQ="$(command -v jq)"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

STDOUT_FILE="$TMP_HOME/stdout"
STDERR_FILE="$TMP_HOME/stderr"
FIXTURE_PLUGIN_ROOT="$TMP_HOME/plugin"

mkdir -p \
  "$FIXTURE_PLUGIN_ROOT/schemas" \
  "$FIXTURE_PLUGIN_ROOT/skills" \
  "$FIXTURE_PLUGIN_ROOT/hooks" \
  "$FIXTURE_PLUGIN_ROOT/evals" \
  "$FIXTURE_PLUGIN_ROOT/scripts"

for schema in plugin.schema.json agent-frontmatter.schema.json skill-frontmatter.schema.json hooks.schema.json; do
  printf '{}\n' > "$FIXTURE_PLUGIN_ROOT/schemas/$schema"
done

cat >"$FIXTURE_PLUGIN_ROOT/scripts/expected-fields.json" <<'EOF'
{
  "_updated": "2000-01-01"
}
EOF

env HOME="$TMP_HOME" CLAUDE_PLUGIN_ROOT="$FIXTURE_PLUGIN_ROOT" \
  bash "$HOOK" </dev/null >"$STDOUT_FILE" 2>"$STDERR_FILE"
HOOK_EXIT=$?

STDOUT="$(cat "$STDOUT_FILE")"
STDERR="$(cat "$STDERR_FILE")"
SYSTEM_MESSAGE="$(jq -r '.systemMessage // empty' "$STDOUT_FILE" 2>/dev/null || true)"

assert_eq "tc01: exits zero when drift warning is emitted" "0" "$HOOK_EXIT"
assert_eq "tc02: warning emission produces no stderr" "" "$STDERR"
assert_contains "tc03: output reports dev-kit drift" "$SYSTEM_MESSAGE" "Dev-kit drift detected:"
assert_contains "tc04: output includes warning bullet" "$SYSTEM_MESSAGE" "- Schema baseline is"
assert_contains "tc05: warning is actionable" "$SYSTEM_MESSAGE" "run /devkit-maintain sync"

TMP_HOME_JQ_FAIL="$(mktemp -d)"
TMP_BIN="$TMP_HOME_JQ_FAIL/bin"
mkdir -p "$TMP_BIN"
cat >"$TMP_BIN/jq" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-cn" ]]; then
  exit 3
fi
exec "$REAL_JQ" "\$@"
EOF
chmod +x "$TMP_BIN/jq"

env HOME="$TMP_HOME_JQ_FAIL" CLAUDE_PLUGIN_ROOT="$FIXTURE_PLUGIN_ROOT" PATH="$TMP_BIN:$PATH" \
  bash "$HOOK" </dev/null >/dev/null 2>/dev/null
HOOK_EXIT=$?

assert_eq "tc06: exits zero when warning JSON emit fails" "0" "$HOOK_EXIT"
if [[ -e "$TMP_HOME_JQ_FAIL/.claude/hook-state/devkit-drift-cache" ]]; then
  fail "tc07: failed warning output does not update cache"
else
  pass "tc07: failed warning output does not update cache"
fi

TOTAL=$(( PASS + FAIL ))
echo ""
printf "Results: ${GREEN}%d passed${RESET}, ${RED}%d failed${RESET} / %d total\n" \
  "$PASS" "$FAIL" "$TOTAL"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for failure in "${FAILURES[@]}"; do
    printf "  ${RED}x${RESET} %s\n" "$failure"
  done
fi

echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
