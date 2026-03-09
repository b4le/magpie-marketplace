#!/usr/bin/env bash
# common.sh — shared utilities for session-autopilot hooks
# Sourced by all hook scripts. Do not execute directly.

set -euo pipefail

# --- Stdin / JSON ---

# Read hook JSON from stdin into global var. Call once per script.
HOOK_INPUT=""
read_stdin() {
  HOOK_INPUT=$(cat)
}

# Extract a top-level string field from HOOK_INPUT.
# Uses jq if available, falls back to grep/sed (fragile but functional).
get_field() {
  local field="$1"
  if command -v jq &>/dev/null; then
    printf '%s' "$HOOK_INPUT" | jq -r ".$field // empty" 2>/dev/null || true
  else
    printf '%s' "$HOOK_INPUT" \
      | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
      | head -1 \
      | sed 's/.*:[[:space:]]*"\(.*\)"/\1/' || true
  fi
}

# --- Project Directory ---

# Resolve project directory from env var, hook JSON, or pwd.
get_project_dir() {
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"
  else
    local cwd
    cwd=$(get_field "cwd")
    if [[ -n "$cwd" ]]; then
      printf '%s' "$cwd"
    else
      pwd
    fi
  fi
}

# --- Git Helpers ---

get_git_branch() {
  git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

get_git_sha() {
  git -C "$1" rev-parse --short HEAD 2>/dev/null || echo "unknown"
}

get_git_status() {
  git -C "$1" status --porcelain -uno 2>/dev/null || true
}

get_git_diff_stat() {
  git -C "$1" diff --stat 2>/dev/null || true
}

get_git_recent_commits() {
  git -C "$1" log --oneline -5 2>/dev/null || true
}

# --- Branch Sanitization ---

sanitize_branch() {
  printf '%s' "$1" | tr '/' '-'
}

# --- Handoff Directory ---

ensure_handoffs_dir() {
  local project_dir="$1"
  local dir="${project_dir}/.claude/handoffs"
  mkdir -p "$dir"
  printf '%s' "$dir"
}

# --- Atomic Write ---

atomic_write() {
  local target="$1"
  local content="$2"
  local tmpfile
  tmpfile=$(mktemp "${target}.tmp.XXXXXX")
  trap 'rm -f "$tmpfile" 2>/dev/null' EXIT
  printf '%s\n' "$content" > "$tmpfile"
  mv "$tmpfile" "$target"
  trap - EXIT
}

# --- Timestamps ---

utc_timestamp() {
  date -u +"%Y%m%dT%H%M%SZ"
}

iso_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# --- Cleanup ---

prune_old_handoffs() {
  local dir="$1"
  find "$dir" -maxdepth 1 -name "*.md" -not -name ".checkpoint_*" -mtime +7 -delete 2>/dev/null || true
}

# --- JSON Output ---

json_encode() {
  local input="$1"
  if command -v jq &>/dev/null; then
    printf '%s' "$input" | jq -Rs '.'
  elif command -v python3 &>/dev/null; then
    printf '%s' "$input" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))"
  else
    local escaped
    escaped=$(printf '%s' "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')
    escaped=$(printf '%s' "$escaped" | awk '{printf "%s\\n", $0}' | sed '$ s/\\n$//')
    printf '"%s"' "$escaped"
  fi
}
