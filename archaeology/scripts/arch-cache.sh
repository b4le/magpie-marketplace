#!/usr/bin/env bash
# arch-cache.sh — Extract per-session metadata from Claude Code JSONL files into a cache.
#
# Usage:
#   arch-cache.sh <history-dir> [--force] [--quiet] [--help]
#
# Arguments:
#   <history-dir>   Directory containing *.jsonl session files
#   --force         Rebuild all cache entries regardless of file mtime
#   --quiet         Suppress per-file progress output (summary still printed)
#   --help          Print this help and exit
#
# Cache layout:
#   <history-dir>/.arch-cache/meta/<key>.json   one JSON blob per session
#
# Exit codes:
#   0   Success (including empty directory)
#   1   Fatal error (bad args, missing tools, unwritable cache dir)
#
# Requires: bash 3.2+, jq (or jaq), date, stat, wc
# Bash 3.2 compatible (macOS default shell).

set -euo pipefail

# ── Tool detection ────────────────────────────────────────────────────

JQ="${JQ:-jaq}"
command -v "$JQ" >/dev/null 2>&1 || JQ="jq"
command -v "$JQ" >/dev/null 2>&1 || {
  printf 'arch-cache: jq or jaq is required\n' >&2
  exit 1
}

# ── Defaults ─────────────────────────────────────────────────────────

HISTORY_DIR=""
FORCE=false
QUIET=false

# ── Usage ─────────────────────────────────────────────────────────────

usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────

while [ $# -gt 0 ]; do
  case "$1" in
    --force)  FORCE=true;  shift ;;
    --quiet)  QUIET=true;  shift ;;
    --help|-h) usage ;;
    --)        shift; break ;;
    -*)
      printf 'arch-cache: unknown option: %s\n' "$1" >&2
      printf 'Run with --help for usage.\n' >&2
      exit 1
      ;;
    *)
      if [ -z "$HISTORY_DIR" ]; then
        HISTORY_DIR="$1"
        shift
      else
        printf 'arch-cache: unexpected argument: %s\n' "$1" >&2
        exit 1
      fi
      ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────

if [ -z "$HISTORY_DIR" ]; then
  printf 'arch-cache: history directory is required\n' >&2
  printf 'Usage: arch-cache.sh <history-dir> [--force] [--quiet]\n' >&2
  exit 1
fi

if [ ! -d "$HISTORY_DIR" ]; then
  printf 'arch-cache: directory not found: %s\n' "$HISTORY_DIR" >&2
  exit 1
fi

# ── Cache directory setup ─────────────────────────────────────────────

CACHE_DIR="${HISTORY_DIR}/.arch-cache/meta"

mkdir -p -- "$CACHE_DIR" 2>/dev/null || {
  printf 'arch-cache: cannot create cache directory: %s\n' "$CACHE_DIR" >&2
  exit 1
}

if [ ! -w "$CACHE_DIR" ]; then
  printf 'arch-cache: cache directory not writable: %s\n' "$CACHE_DIR" >&2
  exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────────

# warn — print a warning to stderr
warn() {
  printf 'arch-cache: WARNING: %s\n' "$1" >&2
}

# log — print progress to stderr unless --quiet
log() {
  if [ "$QUIET" = false ]; then
    printf '%s\n' "$1" >&2
  fi
}

# file_mtime <path> — print the file modification time as Unix epoch seconds
file_mtime() {
  local path="$1"
  if [ "$(uname -s)" = "Darwin" ]; then
    stat -f '%m' -- "$path"
  else
    stat -c '%Y' -- "$path"
  fi
}

# file_size <path> — print the file size in bytes
file_size() {
  local path="$1"
  if [ "$(uname -s)" = "Darwin" ]; then
    stat -f '%z' -- "$path"
  else
    stat -c '%s' -- "$path"
  fi
}

# cache_key <filename> — derive a stable, filesystem-safe cache key.
# Uses the basename stem (no extension) so that the key is human-readable
# and survives re-hashing tool differences across platforms.
cache_key() {
  local base
  base="$(basename -- "$1")"
  printf '%s' "${base%.jsonl}"
}

# iso_now — current UTC timestamp in ISO-8601 format
iso_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# ── jq filter — metadata extraction ──────────────────────────────────
#
# Reads JSONL via jq --slurp on a pre-validated temp file. Extracts:
#   - timestamp_first / timestamp_last (from non-snapshot messages)
#   - message_count (non-blank lines = total JSONL records)
#   - tool_counts (assistant tool_use block names aggregated)
#
# We pass file_size and source_file as --arg to avoid a second stat call.

JQ_FILTER='
  # Work on the array of all parsed objects
  . as $all |

  # Exclude file-history-snapshot (no timestamps, no sessionId)
  ($all | map(select(.type != "file-history-snapshot"))) as $messages |

  # Timestamps: pick the .timestamp field from non-snapshot messages
  ($messages | [.[].timestamp | select(. != null and . != "")] | sort) as $ts |

  # Total message count (all records including snapshots)
  ($all | length) as $msg_count |

  # Tool counts: collect names from assistant tool_use content blocks
  (
    $messages
    | map(
        select(.type == "assistant" and (.isMeta != true))
        | .message.content // []
        | .[]
        | select(type == "object" and .type == "tool_use")
        | .name
      )
    | group_by(.)
    | map({ key: .[0], value: (. | length) })
    | from_entries
  ) as $tool_counts |

  {
    source_file:     $source_file,
    file_size_bytes: ($file_size | tonumber),
    message_count:   $msg_count,
    timestamp_first: (if ($ts | length) > 0 then $ts[0] else null end),
    timestamp_last:  (if ($ts | length) > 0 then $ts[-1] else null end),
    tool_counts:     $tool_counts,
    cached_at:       $cached_at
  }
'

# ── Per-file cache function ───────────────────────────────────────────

# process_session <jsonl_path> — parse one JSONL file and write its cache entry.
# Returns 0 on success, 1 on skip (malformed / empty), 2 on skip (cache fresh).
process_session() {
  local jsonl_path="$1"
  local key size src_mtime cache_path cache_mtime
  local tmp_valid tmp_out

  key="$(cache_key "$jsonl_path")"
  cache_path="${CACHE_DIR}/${key}.json"

  # ── Freshness check ─────────────────────────────────────────────────
  if [ "$FORCE" = false ] && [ -f "$cache_path" ]; then
    src_mtime="$(file_mtime "$jsonl_path")"
    cache_mtime="$(file_mtime "$cache_path")"
    if [ "$cache_mtime" -ge "$src_mtime" ]; then
      log "  skip  ${key} (cache fresh)"
      return 2
    fi
  fi

  log "  cache ${key} ..."

  # ── Validate and collect valid JSON lines ────────────────────────────
  # We build a temp file of valid JSON objects only, then slurp with jq.
  tmp_valid="$(mktemp "${CACHE_DIR}/.tmp-valid-${key}.XXXXXX")"

  local line line_num bad_lines
  line_num=0
  bad_lines=0

  while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))
    [ -z "$line" ] && continue

    if printf '%s\n' "$line" | "$JQ" empty 2>/dev/null; then
      printf '%s\n' "$line" >> "$tmp_valid"
    else
      bad_lines=$((bad_lines + 1))
    fi
  done < "$jsonl_path"

  if [ "$bad_lines" -gt 0 ]; then
    warn "${key}: skipped ${bad_lines} malformed line(s)"
  fi

  # Check we have at least one parseable record
  if [ ! -s "$tmp_valid" ]; then
    warn "${key}: no valid JSON lines found, skipping"
    rm -f -- "$tmp_valid"
    return 1
  fi

  # ── Extract metadata via jq ──────────────────────────────────────────
  size="$(file_size "$jsonl_path")"
  tmp_out="$(mktemp "${CACHE_DIR}/.tmp-out-${key}.XXXXXX")"

  if ! "$JQ" \
      --slurp \
      --arg source_file "$(basename -- "$jsonl_path")" \
      --arg file_size   "$size" \
      --arg cached_at   "$(iso_now)" \
      "$JQ_FILTER" \
      "$tmp_valid" \
      > "$tmp_out" 2>/dev/null; then
    warn "${key}: jq extraction failed, skipping"
    rm -f -- "$tmp_valid" "$tmp_out"
    return 1
  fi

  # Verify output is non-empty valid JSON before committing
  if [ ! -s "$tmp_out" ] || ! "$JQ" empty "$tmp_out" 2>/dev/null; then
    warn "${key}: jq produced invalid output, skipping"
    rm -f -- "$tmp_valid" "$tmp_out"
    return 1
  fi

  # Atomic commit
  mv -- "$tmp_out" "$cache_path" || {
    warn "${key}: failed to write cache file: ${cache_path}"
    rm -f -- "$tmp_valid" "$tmp_out"
    return 1
  }

  rm -f -- "$tmp_valid"
  return 0
}

# ── Main ──────────────────────────────────────────────────────────────

TOTAL=0
UPDATED=0
SKIPPED=0
ERRORS=0

# Collect JSONL files — top-level only, exclude any subagent directories.
# Use find with -maxdepth 1 and NUL separation for safety.
jsonl_files=""
while IFS= read -r -d '' f; do
  # Skip files inside subdirectories (subagents/ etc.) — maxdepth 1 handles this,
  # but double-check: the file's directory must be exactly HISTORY_DIR.
  jsonl_files="${jsonl_files}${f}"$'\n'
done < <(find "$HISTORY_DIR" -maxdepth 1 -name '*.jsonl' -type f -print0 2>/dev/null)

# Check for empty directory
if [ -z "$jsonl_files" ]; then
  printf 'arch-cache: no .jsonl files found in %s\n' "$HISTORY_DIR"
  exit 0
fi

# Process each file
while IFS= read -r jsonl_path; do
  [ -z "$jsonl_path" ] && continue

  TOTAL=$((TOTAL + 1))
  result_code=0
  process_session "$jsonl_path" || result_code=$?

  case "$result_code" in
    0) UPDATED=$((UPDATED + 1)) ;;
    2) SKIPPED=$((SKIPPED + 1)) ;;
    *) ERRORS=$((ERRORS + 1)) ;;
  esac
done <<EOF
$jsonl_files
EOF

# ── Summary ───────────────────────────────────────────────────────────

printf 'Cached %d sessions (%d skipped, %d updated, %d errors)\n' \
  "$TOTAL" "$SKIPPED" "$UPDATED" "$ERRORS"

[ "$ERRORS" -gt 0 ] && exit 1
exit 0
