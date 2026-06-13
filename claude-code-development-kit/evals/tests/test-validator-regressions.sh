#!/usr/bin/env bash
# Regression tests for validator orchestration edge cases.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVALS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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

write_readme() {
  local target="$1"
  cat >"$target" <<'EOF'
# Regression Plugin

This fixture exists to test marketplace validators.

## Installation

Install this fixture through the marketplace test harness.

## Usage

Run the validators against this generated plugin.

## Notes

The content only needs enough lines for README validation.
EOF
}

write_plugin_json() {
  local target="$1"
  local name="$2"
  cat >"$target" <<EOF
{
  "name": "$name",
  "version": "1.0.0",
  "description": "Generated regression fixture for validator orchestration checks.",
  "author": { "name": "Test Author" },
  "license": "MIT"
}
EOF
}

write_clean_hook() {
  local target="$1"
  cat >"$target" <<'EOF'
#!/usr/bin/env bash
set -e
echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"fixture"}}'
EOF
  chmod +x "$target"
}

write_warning_hook() {
  local target="$1"
  cat >"$target" <<'EOF'
#!/usr/bin/env bash
echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"fixture"}}'
EOF
  chmod +x "$target"
}

echo ""
echo "=== validator regression tests ==="
echo ""

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required to run validator regression tests."
  exit 1
fi

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PLUGIN_ROOT="$TMP_ROOT/nested-hook-plugin"
mkdir -p "$PLUGIN_ROOT/hooks/scripts" "$PLUGIN_ROOT/scripts"
write_plugin_json "$PLUGIN_ROOT/plugin.json" "nested-hook-plugin"
write_readme "$PLUGIN_ROOT/README.md"
write_clean_hook "$PLUGIN_ROOT/hooks/scripts/session-start.sh"
write_warning_hook "$PLUGIN_ROOT/scripts/not-a-hook.sh"

set +e
PLUGIN_OUTPUT="$(bash "$EVALS_DIR/validate-plugin.sh" "$PLUGIN_ROOT" 2>&1)"
PLUGIN_EXIT=$?
set -e

assert_eq "tc01: validate-plugin accepts clean nested hooks" "0" "$PLUGIN_EXIT"
assert_contains "tc02: validate-plugin discovers nested hook scripts" "$PLUGIN_OUTPUT" "Found hook: session-start.sh"
if [[ "$PLUGIN_OUTPUT" == *"not-a-hook.sh"* ]]; then
  fail "tc03: validate-plugin ignores top-level scripts directory"
else
  pass "tc03: validate-plugin ignores top-level scripts directory"
fi

WARNING_PLUGIN_ROOT="$TMP_ROOT/warning-hook-plugin"
mkdir -p "$WARNING_PLUGIN_ROOT/hooks/scripts"
write_plugin_json "$WARNING_PLUGIN_ROOT/plugin.json" "warning-hook-plugin"
write_readme "$WARNING_PLUGIN_ROOT/README.md"
write_warning_hook "$WARNING_PLUGIN_ROOT/hooks/scripts/session-start.sh"

set +e
WARNING_PLUGIN_OUTPUT="$(bash "$EVALS_DIR/validate-plugin.sh" "$WARNING_PLUGIN_ROOT" 2>&1)"
WARNING_PLUGIN_EXIT=$?
set -e

assert_eq "tc04: validate-plugin rejects warning-only hooks" "1" "$WARNING_PLUGIN_EXIT"
assert_contains "tc05: validate-plugin surfaces warning-only hook failure" "$WARNING_PLUGIN_OUTPUT" "Hook failed"

INVALID_COMPONENT_PLUGIN="$TMP_ROOT/invalid-component-plugin"
mkdir -p "$INVALID_COMPONENT_PLUGIN/commands"
write_plugin_json "$INVALID_COMPONENT_PLUGIN/plugin.json" "invalid-component-plugin"
write_readme "$INVALID_COMPONENT_PLUGIN/README.md"
cat >"$INVALID_COMPONENT_PLUGIN/commands/bad.md" <<'EOF'
This command intentionally omits frontmatter.
EOF

set +e
INVALID_COMPONENT_OUTPUT="$(bash "$EVALS_DIR/validate-plugin.sh" "$INVALID_COMPONENT_PLUGIN" 2>&1)"
INVALID_COMPONENT_EXIT=$?
set -e

assert_eq "tc06: validate-plugin rejects invalid components" "1" "$INVALID_COMPONENT_EXIT"
assert_contains "tc07: validate-plugin prints summary after component failure" "$INVALID_COMPONENT_OUTPUT" "PLUGIN VALIDATION SUMMARY"

MARKETPLACE_ROOT="$TMP_ROOT/marketplace"
mkdir -p "$MARKETPLACE_ROOT/.claude-plugin" "$MARKETPLACE_ROOT/plugins"
cp -R "$PLUGIN_ROOT" "$MARKETPLACE_ROOT/plugins/nested-hook-plugin"
cat >"$MARKETPLACE_ROOT/.claude-plugin/marketplace.json" <<'EOF'
{
  "name": "regression-marketplace",
  "plugins": [
    {
      "name": "nested-hook-plugin",
      "version": "1.0.0",
      "source": "./plugins/nested-hook-plugin"
    }
  ]
}
EOF

set +e
MARKETPLACE_OUTPUT="$(bash "$EVALS_DIR/validate-marketplace.sh" "$MARKETPLACE_ROOT" 2>&1)"
MARKETPLACE_EXIT=$?
set -e

assert_eq "tc08: validate-marketplace does not abort on zero-to-one counters" "0" "$MARKETPLACE_EXIT"
assert_contains "tc09: validate-marketplace validates hooks" "$MARKETPLACE_OUTPUT" "Hooks:"
assert_contains "tc10: validate-marketplace reports plugin pass" "$MARKETPLACE_OUTPUT" "1/1 passed"

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
