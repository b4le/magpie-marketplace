#!/usr/bin/env bash
# session-drift-check.sh — Lightweight SessionStart hook for schema/feature drift detection
#
# Checks: schema file integrity, critical directory existence, schema drift
# Design: fail-open (all errors exit 0), <5s budget, 12h cache, no network
# Debug: CLAUDE_HOOK_DEBUG=1
#
# Exit codes:
#   0  Pass (or fail-open on error). Optional JSON on stdout for warnings.

# Fail-open safety net — cleared before intentional deny output
trap 'exit 0' EXIT

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
readonly STATE_DIR="${HOME}/.claude/hook-state"
readonly CACHE_FILE="${STATE_DIR}/devkit-drift-cache"
readonly CACHE_TTL=43200  # 12 hours in seconds
readonly DEBUG="${CLAUDE_HOOK_DEBUG:-0}"

# Plugin root — set by Claude Code when running plugin hooks
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"

debug() {
  [[ "$DEBUG" == "1" ]] && printf '[session-drift-check] %s\n' "$*" >&2 || true
}

# ---------------------------------------------------------------------------
# Dependency guard
# ---------------------------------------------------------------------------
if ! command -v jq &>/dev/null; then
  debug "jq not found — skipping (fail-open)"
  exit 0
fi

if [[ -z "$PLUGIN_ROOT" ]]; then
  debug "CLAUDE_PLUGIN_ROOT not set — skipping"
  exit 0
fi

# ---------------------------------------------------------------------------
# Input processing (SessionStart provides JSON on stdin)
# ---------------------------------------------------------------------------
INPUT=$(cat 2>/dev/null) || INPUT=""
debug "input length: ${#INPUT}"

# ---------------------------------------------------------------------------
# Cache check — skip expensive operations if recently validated
# ---------------------------------------------------------------------------
mkdir -p "$STATE_DIR" 2>/dev/null || true

LAST_CHECK=0
if [[ -f "$CACHE_FILE" ]]; then
  LAST_CHECK=$(cat "$CACHE_FILE" 2>/dev/null) || LAST_CHECK=0
fi

CURRENT_TIME=$(date +%s)
TIME_SINCE_CHECK=$(( CURRENT_TIME - LAST_CHECK ))

if [[ $TIME_SINCE_CHECK -lt $CACHE_TTL ]]; then
  debug "cache valid ($(( CACHE_TTL - TIME_SINCE_CHECK ))s remaining) — skipping"
  exit 0
fi

debug "cache expired or missing — running checks"

# ---------------------------------------------------------------------------
# Check 1: Critical schema files exist and are valid JSON
# ---------------------------------------------------------------------------
WARNINGS=()
SCHEMA_DIR="${PLUGIN_ROOT}/schemas"
CRITICAL_SCHEMAS=("plugin.schema.json" "agent-frontmatter.schema.json" "skill-frontmatter.schema.json" "hooks.schema.json")

for schema in "${CRITICAL_SCHEMAS[@]}"; do
  schema_path="${SCHEMA_DIR}/${schema}"
  if [[ ! -f "$schema_path" ]]; then
    WARNINGS+=("Missing schema: ${schema}")
    debug "WARN: missing ${schema}"
  elif ! jq empty "$schema_path" 2>/dev/null; then
    WARNINGS+=("Malformed schema: ${schema}")
    debug "WARN: malformed ${schema}"
  fi
done

# ---------------------------------------------------------------------------
# Check 2: Critical directories exist
# ---------------------------------------------------------------------------
REQUIRED_DIRS=("skills" "hooks" "evals" "schemas" "scripts")
for dir in "${REQUIRED_DIRS[@]}"; do
  if [[ ! -d "${PLUGIN_ROOT}/${dir}" ]]; then
    WARNINGS+=("Missing directory: ${dir}/")
    debug "WARN: missing dir ${dir}"
  fi
done

# ---------------------------------------------------------------------------
# Check 3: Schema drift (fast — just check expected-fields.json freshness)
# ---------------------------------------------------------------------------
EXPECTED_FILE="${PLUGIN_ROOT}/scripts/expected-fields.json"
if [[ -f "$EXPECTED_FILE" ]]; then
  UPDATED=$(jq -r '._updated // "unknown"' "$EXPECTED_FILE" 2>/dev/null) || UPDATED="unknown"
  if [[ "$UPDATED" != "unknown" ]]; then
    # Parse date portably (try GNU date -d first, then BSD date -j)
    UPDATED_EPOCH=$(date -d "$UPDATED" "+%s" 2>/dev/null) \
      || UPDATED_EPOCH=$(date -j -f "%Y-%m-%d" "$UPDATED" "+%s" 2>/dev/null) \
      || UPDATED_EPOCH=0
    if [[ $UPDATED_EPOCH -gt 0 ]]; then
      DAYS_OLD=$(( (CURRENT_TIME - UPDATED_EPOCH) / 86400 ))
      if [[ $DAYS_OLD -gt 30 ]]; then
        WARNINGS+=("Schema baseline is ${DAYS_OLD} days old — run /devkit-maintain sync")
        debug "WARN: expected-fields.json is ${DAYS_OLD} days old"
      fi
    fi
  fi
else
  WARNINGS+=("Missing expected-fields.json — schema drift detection unavailable")
  debug "WARN: no expected-fields.json"
fi

# ---------------------------------------------------------------------------
# Update cache
# ---------------------------------------------------------------------------
echo "$CURRENT_TIME" > "$CACHE_FILE" 2>/dev/null || true
debug "cache updated"

# ---------------------------------------------------------------------------
# Output warnings if any
# ---------------------------------------------------------------------------
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  WARNING_TEXT=$(printf '- %s\\n' "${WARNINGS[@]}")
  debug "emitting ${#WARNINGS[@]} warnings"

  # Clear fail-open trap before intentional output
  trap - EXIT

  jq -cn \
    --arg warnings "$WARNING_TEXT" \
    '{
      "systemMessage": ("Dev-kit drift detected:\n" + $warnings + "\nRun /devkit-maintain to investigate.")
    }' 2>/dev/null || true

  exit 0
fi

debug "all checks passed — no warnings"
trap - EXIT
exit 0
