#!/usr/bin/env bash
# session-start.sh — SessionStart hook for session-budget plugin
# Emits a systemMessage reminding Claude that the session-budget skill is available.
# Skips "compact" source (already has context). Uses a 6h cache to prevent nagging.
# Fail-open: exits 0 on all error paths.
set -euo pipefail

# Fail-open: any unexpected error exits cleanly
trap 'exit 0' EXIT

# ── Constants ────────────────────────────────────────────────────────────────
readonly CACHE_FILE="${HOME}/.claude/hook-state/session-budget-last-shown"
readonly CACHE_TTL_SECONDS=21600  # 6 hours

# ── Read stdin ───────────────────────────────────────────────────────────────
input="$(cat)"

# ── Source filter: skip "compact" — it already has context ──────────────────
source_type="$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null || true)"
if [[ "$source_type" == "compact" ]]; then
  exit 0
fi

# ── Cache check: skip if shown within the TTL window ────────────────────────
if [[ -f "$CACHE_FILE" ]]; then
  last_shown="$(cat "$CACHE_FILE" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  if (( now - last_shown < CACHE_TTL_SECONDS )); then
    exit 0
  fi
fi

# ── Write SESSION_BUDGET_PLUGIN_ACTIVE to env file ───────────────────────────
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  printf 'SESSION_BUDGET_PLUGIN_ACTIVE=1\n' >> "$CLAUDE_ENV_FILE" 2>/dev/null || true
fi

# ── Update cache timestamp ───────────────────────────────────────────────────
mkdir -p "$(dirname "$CACHE_FILE")"
date +%s > "$CACHE_FILE" 2>/dev/null || true

# ── Emit systemMessage ───────────────────────────────────────────────────────
jq -n \
  --arg msg "The session-budget skill is active. When helping the user plan or scope a session, score tasks by complexity (simple=1, medium=2, complex=3) and keep each agent session at ~8 points. Split larger plans across sessions with explicit handoffs. Front-load critical work to avoid lost-in-the-middle degradation. Suggest a complexity budget proactively when the user is planning a multi-step session." \
  '{"systemMessage": $msg}'
