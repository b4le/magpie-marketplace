#!/usr/bin/env bash
# arch-score.sh — Score domain keyword presence across conversation history files.
#
# Usage:
#   arch-score.sh <history-dir> [--registry PATH] [--filter PATH] [--quiet] [--help]
#
# Arguments:
#   <history-dir>       Directory containing *.jsonl conversation files
#   --registry PATH     Domain registry YAML (default: ../skills/archaeology/references/domains/registry.yaml
#                       relative to script location)
#   --filter PATH       jq filter file for extracting conversation text (default:
#                       ../skills/archaeology/references/jsonl-filter.jq relative to script location)
#   --quiet             Suppress per-domain progress output (JSON result still printed)
#   --help, -h          Print this help and exit
#
# Output:
#   JSON array to stdout, sorted by score descending:
#   [
#     {
#       "domain": "orchestration",
#       "name": "Orchestration Patterns",
#       "score": 34.5,
#       "signal": "strong",
#       "confidence": "high",
#       "sessions": 5,
#       "rationale": "primary: 18 (3 keywords), secondary: 12 (4 keywords), 5 sessions"
#     }
#   ]
#
# Scoring algorithm:
#   For each keyword, counts occurrences per file, capped at PRIMARY_CAP_PER_SESSION=5
#   (primary) or SECONDARY_CAP_PER_SESSION=3 (secondary). Then:
#     raw_score        = (primary_score * 3) + (secondary_score * 1)
#     diversity_factor = min(1.5, 1.0 + (session_count * 0.1))
#     final_score      = raw_score * diversity_factor  (rounded to 1dp)
#   Signal:     strong (>=20 AND sessions>=2), moderate (>=8), weak (>=2), none (<2)
#   Confidence: high (sessions>=3), medium (sessions>=2), low (sessions>=1), - (0)
#
# Exit codes:
#   0   Success (including empty directory — outputs [])
#   1   Fatal error (bad args, missing tools, missing registry/filter)
#
# Requires: bash 3.2+, jq (or jaq), awk, grep, wc
# Bash 3.2 compatible (macOS default shell).

# ── Tool detection ────────────────────────────────────────────────────

JQ="${JQ:-jaq}"
command -v "$JQ" >/dev/null 2>&1 || JQ="jq"
command -v "$JQ" >/dev/null 2>&1 || {
  printf 'arch-score: jq or jaq is required\n' >&2
  exit 1
}

command -v awk >/dev/null 2>&1 || {
  printf 'arch-score: awk is required\n' >&2
  exit 1
}

# ── Script location — for default paths ──────────────────────────────

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# ── Defaults ─────────────────────────────────────────────────────────

HISTORY_DIR=""
REGISTRY_PATH="${SCRIPT_DIR}/../skills/archaeology/references/domains/registry.yaml"
FILTER_PATH="${SCRIPT_DIR}/../skills/archaeology/references/jsonl-filter.jq"
QUIET=false

# Scoring constants
PRIMARY_CAP_PER_SESSION=5
SECONDARY_CAP_PER_SESSION=3

# ── Usage ─────────────────────────────────────────────────────────────

usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────

while [ $# -gt 0 ]; do
  case "$1" in
    --registry)
      REGISTRY_PATH="$2"
      shift 2
      ;;
    --filter)
      FILTER_PATH="$2"
      shift 2
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    --help|-h)
      usage
      ;;
    --)
      shift
      break
      ;;
    -*)
      printf 'arch-score: unknown option: %s\n' "$1" >&2
      printf 'Run with --help for usage.\n' >&2
      exit 1
      ;;
    *)
      if [ -z "$HISTORY_DIR" ]; then
        HISTORY_DIR="$1"
        shift
      else
        printf 'arch-score: unexpected argument: %s\n' "$1" >&2
        exit 1
      fi
      ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────

if [ -z "$HISTORY_DIR" ]; then
  printf 'arch-score: history directory is required\n' >&2
  printf 'Usage: arch-score.sh <history-dir> [--registry PATH] [--filter PATH] [--quiet]\n' >&2
  exit 1
fi

if [ ! -d "$HISTORY_DIR" ]; then
  printf 'arch-score: directory not found: %s\n' "$HISTORY_DIR" >&2
  exit 1
fi

if [ ! -f "$REGISTRY_PATH" ]; then
  printf 'arch-score: registry file not found: %s\n' "$REGISTRY_PATH" >&2
  exit 1
fi

if [ ! -f "$FILTER_PATH" ]; then
  printf 'arch-score: jq filter file not found: %s\n' "$FILTER_PATH" >&2
  exit 1
fi

# Resolve registry dir for relative domain file lookups
REGISTRY_DIR="$(cd -- "$(dirname -- "$REGISTRY_PATH")" && pwd -P)"

# ── Helpers ───────────────────────────────────────────────────────────

# warn — print a warning to stderr
warn() {
  printf 'arch-score: WARNING: %s\n' "$1" >&2
}

# log — print progress to stderr unless --quiet
log() {
  if [ "$QUIET" = false ]; then
    printf '%s\n' "$1" >&2
  fi
}

# ── YAML frontmatter parser ───────────────────────────────────────────
#
# Extracts lines between the first pair of --- delimiters.
# Returns the raw YAML block on stdout.
extract_frontmatter() {
  local file="$1"
  awk '
    /^---$/ { if (in_fm) { exit } else { in_fm=1; next } }
    in_fm   { print }
  ' "$file"
}

# parse_keyword_list <yaml_block> <section>
# Extracts YAML sequence items from a named subsection of a keywords block.
# section is "primary" or "secondary".
# Output: one keyword per line.
parse_keyword_list() {
  local yaml_block="$1"
  local section="$2"
  printf '%s\n' "$yaml_block" | awk -v section="$section" '
    # State machine: find "keywords:", then find "  primary:" or "  secondary:",
    # then collect "    - <item>" lines until the next non-list line.
    /^keywords:$/        { in_keywords=1; in_section=0; next }
    in_keywords && /^  [a-z]/ {
      # Check if this is our target section
      if ($0 ~ "^  " section ":") {
        in_section=1
      } else {
        in_section=0
      }
      next
    }
    # Exit keywords block when we reach a top-level key (no leading spaces)
    in_keywords && /^[a-z]/ { in_keywords=0; in_section=0 }
    in_section && /^    - / {
      # Strip leading "    - " and print
      sub(/^    - /, "")
      # Strip surrounding quotes if present
      gsub(/^'"'"'|'"'"'$/, "")
      gsub(/^"|"$/, "")
      print
    }
  '
}

# count_keyword_in_file <keyword> <file>
# Counts word-boundary occurrences of keyword in the jq-filtered output of file.
# Returns count on stdout.
count_keyword_in_file() {
  local keyword="$1"
  local file="$2"
  "$JQ" -r -f "$FILTER_PATH" "$file" 2>/dev/null \
    | grep -oi "\\b${keyword}\\b" 2>/dev/null \
    | wc -l \
    | tr -d ' '
}

# ── Registry parser ───────────────────────────────────────────────────
#
# Extracts active/draft domain entries from the YAML registry.
# Outputs records as: id|name|file  (pipe-delimited), one per line.
# Skips domains where status is not active or draft.
parse_registry() {
  awk '
    BEGIN { id=""; name=""; file=""; status="" }

    function emit() {
      if (id != "" && name != "" && (status == "active" || status == "draft")) {
        print id "|" name "|" file
      }
      id=""; name=""; file=""; status=""
    }

    /^  - id:/ {
      emit()
      id = $NF
      gsub(/'"'"'|"/, "", id)
    }
    /^    name:/ {
      sub(/^    name: */, "")
      gsub(/'"'"'|"/, "")
      name = $0
    }
    /^    file:/ {
      file = $NF
      gsub(/'"'"'|"/, "", file)
    }
    /^    status:/ {
      status = $NF
      gsub(/'"'"'|"/, "", status)
    }
    END { emit() }
  ' "$REGISTRY_PATH"
}

# ── Collect JSONL files ───────────────────────────────────────────────

jsonl_files=""
jsonl_count=0
while IFS= read -r -d '' f; do
  jsonl_files="${jsonl_files}${f}"$'\n'
  jsonl_count=$((jsonl_count + 1))
done < <(find "$HISTORY_DIR" -maxdepth 1 -name '*.jsonl' -type f -print0 2>/dev/null)

if [ -z "$jsonl_files" ] || [ "$jsonl_count" -eq 0 ]; then
  log "arch-score: no .jsonl files found in ${HISTORY_DIR}, outputting empty result"
  printf '[]\n'
  exit 0
fi

log "arch-score: scoring ${jsonl_count} session file(s) in ${HISTORY_DIR}"

# ── Per-domain scoring ────────────────────────────────────────────────
#
# Accumulate JSON objects as newline-delimited strings, then assemble at end.

RESULT_OBJECTS=""

while IFS='|' read -r domain_id domain_name domain_file; do
  [ -z "$domain_id" ] && continue

  log "  scoring domain: ${domain_id}"

  # Locate domain .md file
  if [ -z "$domain_file" ]; then
    warn "domain '${domain_id}' has no file entry in registry, skipping"
    continue
  fi

  domain_md="${REGISTRY_DIR}/${domain_file}"
  if [ ! -f "$domain_md" ]; then
    warn "domain file not found for '${domain_id}': ${domain_md}, skipping"
    continue
  fi

  # Extract frontmatter
  frontmatter="$(extract_frontmatter "$domain_md")"
  if [ -z "$frontmatter" ]; then
    warn "no frontmatter found in '${domain_md}', skipping"
    continue
  fi

  # Parse keyword lists
  primary_keywords="$(parse_keyword_list "$frontmatter" "primary")"
  secondary_keywords="$(parse_keyword_list "$frontmatter" "secondary")"

  # ── Score primary keywords ──────────────────────────────────────────

  primary_score=0
  primary_keyword_count=0
  session_set=""  # newline-delimited list of files that had any primary hit

  if [ -n "$primary_keywords" ]; then
    while IFS= read -r kw; do
      [ -z "$kw" ] && continue
      primary_keyword_count=$((primary_keyword_count + 1))

      while IFS= read -r session_file; do
        [ -z "$session_file" ] && continue

        raw_count="$(count_keyword_in_file "$kw" "$session_file")"
        # Ensure numeric
        raw_count=$(printf '%s' "$raw_count" | tr -d '[:space:]')
        if ! printf '%s' "$raw_count" | grep -qE '^[0-9]+$'; then
          raw_count=0
        fi

        # Cap at PRIMARY_CAP_PER_SESSION
        if [ "$raw_count" -gt "$PRIMARY_CAP_PER_SESSION" ]; then
          capped=$PRIMARY_CAP_PER_SESSION
        else
          capped=$raw_count
        fi

        primary_score=$((primary_score + capped))

        # Track sessions with at least one hit
        if [ "$raw_count" -gt 0 ]; then
          # Add to session_set if not already present
          if ! printf '%s\n' "$session_set" | grep -qxF "$session_file"; then
            session_set="${session_set}${session_file}"$'\n'
          fi
        fi
      done <<SESSIONS_EOF
$jsonl_files
SESSIONS_EOF
    done <<KW_EOF
$primary_keywords
KW_EOF
  fi

  # ── Score secondary keywords ────────────────────────────────────────

  secondary_score=0
  secondary_keyword_count=0

  if [ -n "$secondary_keywords" ]; then
    while IFS= read -r kw; do
      [ -z "$kw" ] && continue
      secondary_keyword_count=$((secondary_keyword_count + 1))

      while IFS= read -r session_file; do
        [ -z "$session_file" ] && continue

        raw_count="$(count_keyword_in_file "$kw" "$session_file")"
        raw_count=$(printf '%s' "$raw_count" | tr -d '[:space:]')
        if ! printf '%s' "$raw_count" | grep -qE '^[0-9]+$'; then
          raw_count=0
        fi

        # Cap at SECONDARY_CAP_PER_SESSION
        if [ "$raw_count" -gt "$SECONDARY_CAP_PER_SESSION" ]; then
          capped=$SECONDARY_CAP_PER_SESSION
        else
          capped=$raw_count
        fi

        secondary_score=$((secondary_score + capped))

        # Secondary keywords also contribute to session tracking
        if [ "$raw_count" -gt 0 ]; then
          if ! printf '%s\n' "$session_set" | grep -qxF "$session_file"; then
            session_set="${session_set}${session_file}"$'\n'
          fi
        fi
      done <<SESSIONS_EOF2
$jsonl_files
SESSIONS_EOF2
    done <<KW2_EOF
$secondary_keywords
KW2_EOF
  fi

  # ── Compute final score ─────────────────────────────────────────────

  # Count unique sessions that contributed
  session_count=0
  if [ -n "$session_set" ]; then
    while IFS= read -r s; do
      [ -n "$s" ] && session_count=$((session_count + 1))
    done <<SC_EOF
$session_set
SC_EOF
  fi

  # raw_score = (primary_score * 3) + (secondary_score * 1)
  raw_score=$(( (primary_score * 3) + secondary_score ))

  # diversity_factor = min(1.5, 1.0 + (session_count * 0.1))
  diversity_factor="$(awk -v sc="$session_count" 'BEGIN {
    df = 1.0 + (sc * 0.1)
    if (df > 1.5) df = 1.5
    printf "%.10f\n", df
  }')"

  # final_score = round(raw_score * diversity_factor, 1dp)
  final_score="$(awk -v raw="$raw_score" -v df="$diversity_factor" 'BEGIN {
    printf "%.1f\n", raw * df
  }')"

  # ── Classify signal ─────────────────────────────────────────────────

  # Compare final_score as float
  signal="$(awk -v fs="$final_score" -v sc="$session_count" 'BEGIN {
    if (fs >= 20 && sc >= 2) { print "strong" }
    else if (fs >= 8)        { print "moderate" }
    else if (fs >= 2)        { print "weak" }
    else                     { print "none" }
  }')"

  # ── Classify confidence ─────────────────────────────────────────────

  if [ "$session_count" -ge 3 ]; then
    confidence="high"
  elif [ "$session_count" -ge 2 ]; then
    confidence="medium"
  elif [ "$session_count" -ge 1 ]; then
    confidence="low"
  else
    confidence="-"
  fi

  # ── Build rationale string ──────────────────────────────────────────

  rationale="primary: ${primary_score} (${primary_keyword_count} keywords), secondary: ${secondary_score} (${secondary_keyword_count} keywords), ${session_count} sessions"

  log "    ${domain_id}: score=${final_score} signal=${signal} sessions=${session_count}"

  # ── Emit JSON object ────────────────────────────────────────────────

  obj="$("$JQ" -n \
    --arg domain     "$domain_id" \
    --arg name       "$domain_name" \
    --argjson score  "$final_score" \
    --arg signal     "$signal" \
    --arg confidence "$confidence" \
    --argjson sessions "$session_count" \
    --arg rationale  "$rationale" \
    '{
      domain:     $domain,
      name:       $name,
      score:      $score,
      signal:     $signal,
      confidence: $confidence,
      sessions:   $sessions,
      rationale:  $rationale
    }')"

  if [ -z "$RESULT_OBJECTS" ]; then
    RESULT_OBJECTS="$obj"
  else
    RESULT_OBJECTS="${RESULT_OBJECTS}
${obj}"
  fi

done <<REGISTRY_EOF
$(parse_registry)
REGISTRY_EOF

# ── Assemble and sort output ──────────────────────────────────────────

if [ -z "$RESULT_OBJECTS" ]; then
  printf '[]\n'
  exit 0
fi

# Wrap objects in array and sort by score descending
printf '%s\n' "$RESULT_OBJECTS" \
  | "$JQ" -s 'sort_by(-.score)'

exit 0
