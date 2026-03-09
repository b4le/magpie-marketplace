#!/usr/bin/env bash
# archaeology-excavation.sh — Run archaeology surveys across discovered projects.
# Bash 3.2 compatible (macOS default shell).
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────
DEFAULT_SCAN_PATHS="$HOME"
MAX_CONCURRENT=3
MAX_AGE_DAYS=7
DRY_RUN=false
IGNORE_FILE="$HOME/.claude/archaeology-ignore"
CONFIG_FILE="$HOME/.claude/archaeology-config"
CENTRAL_BASE="$HOME/.claude/data/visibility-toolkit/work-log/archaeology"
LOG_DIR="$CENTRAL_BASE/.excavation-logs"

# ── Load user config (overrides defaults before CLI args) ────────────
if [[ -f "$CONFIG_FILE" ]]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    # Trim whitespace
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    case "$key" in
      scan_paths)     DEFAULT_SCAN_PATHS="$value" ;;
      max_concurrent) MAX_CONCURRENT="$value" ;;
      max_age_days)   MAX_AGE_DAYS="$value" ;;
    esac
  done < "$CONFIG_FILE"
fi

# ── Argument parsing ─────────────────────────────────────────────────
SCAN_PATHS_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan-paths)     SCAN_PATHS_ARG="$2"; shift 2 ;;
    --max-concurrent) MAX_CONCURRENT="$2"; shift 2 ;;
    --max-age)        MAX_AGE_DAYS="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=true; shift ;;
    *)                printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# Split scan paths into array (Bash 3.2: -ra is fine)
IFS=',' read -ra SCAN_PATHS <<< "${SCAN_PATHS_ARG:-$DEFAULT_SCAN_PATHS}"

# ── Setup ────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"

# Load ignore list into indexed array (no mapfile — Bash 3.2 compat)
IGNORE_PATTERNS=()
if [[ -f "$IGNORE_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    # Expand ~ to $HOME
    IGNORE_PATTERNS+=("${line/#\~/$HOME}")
  done < "$IGNORE_FILE"
fi

# ── Discovery ────────────────────────────────────────────────────────
discover_projects() {
  local scan_path project_dir skip pattern
  local -a found=()

  for scan_path in "${SCAN_PATHS[@]}"; do
    [[ -d "$scan_path" ]] || continue
    # Find directories containing .claude/ (depth 1-3 under scan path)
    while IFS= read -r claude_dir; do
      project_dir="$(dirname "$claude_dir")"

      # Skip ~/.claude itself and anything under it
      [[ "$project_dir" == "$HOME/.claude" ]]    && continue
      [[ "$project_dir" == "$HOME/.claude/"* ]]  && continue

      # Skip ignored paths
      skip=false
      for pattern in "${IGNORE_PATTERNS[@]+"${IGNORE_PATTERNS[@]}"}"; do
        if [[ "$project_dir" == "$pattern" || "$project_dir" == "$pattern/"* ]]; then
          skip=true
          break
        fi
      done
      [[ "$skip" == true ]] && continue

      found+=("$project_dir")
    done < <(find "$scan_path" -maxdepth 3 -name ".claude" -type d 2>/dev/null)
  done

  # Deduplicate while preserving order
  if [[ ${#found[@]} -gt 0 ]]; then
    printf '%s\n' "${found[@]}" | sort -u
  fi
}

# ── Helpers ──────────────────────────────────────────────────────────
to_slug() {
  local name
  name="$(basename "$1")"
  printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/^-//; s/-$//'
}

is_survey_fresh() {
  local slug="$1"
  local survey_file="$CENTRAL_BASE/$slug/survey.md"
  [[ -f "$survey_file" ]] || return 1

  local file_mtime now file_age_days
  if [[ "$(uname)" == "Darwin" ]]; then
    file_mtime=$(stat -f %m "$survey_file")
    now=$(date +%s)
    file_age_days=$(( (now - file_mtime) / 86400 ))
  else
    file_mtime=$(stat -c %Y "$survey_file")
    now=$(date +%s)
    file_age_days=$(( (now - file_mtime) / 86400 ))
  fi

  [[ $file_age_days -lt $MAX_AGE_DAYS ]]
}

# json_escape <string> — emit a JSON-safe double-quoted string value (no outer quotes)
json_escape() {
  local s="$1"
  # Escape backslash first, then double-quote, then control chars
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# ── Subprocess launcher ──────────────────────────────────────────────
run_survey() {
  local project_dir="$1"
  local slug="$2"

  (cd "$project_dir" && command claude -p "/archaeology survey" \
    --dangerously-skip-permissions \
    --output-format json \
    --no-session-persistence \
    --add-dir "$HOME/.claude" \
    --max-budget-usd 2.00 \
    2>"$LOG_DIR/${slug}.err" \
    >"$LOG_DIR/${slug}.out")
}

# ── Main ─────────────────────────────────────────────────────────────

# Collect all projects (Bash 3.2: no mapfile — use while-read loop)
ALL_PROJECTS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && ALL_PROJECTS+=("$line")
done < <(discover_projects)

TOTAL=${#ALL_PROJECTS[@]}
SKIPPED=0
SURVEYED=0
FAILED=0
RESULTS=""

# Classify each project into fresh-skip or needs-survey
TO_SURVEY=()
for project_dir in "${ALL_PROJECTS[@]+"${ALL_PROJECTS[@]}"}"; do
  slug=$(to_slug "$project_dir")
  escaped_path=$(json_escape "$project_dir")
  escaped_slug=$(json_escape "$slug")

  if is_survey_fresh "$slug"; then
    RESULTS="${RESULTS}{\"path\":\"${escaped_path}\",\"slug\":\"${escaped_slug}\",\"status\":\"skipped\",\"reason\":\"fresh_survey\"},"
    SKIPPED=$((SKIPPED + 1))
  else
    TO_SURVEY+=("$project_dir")
  fi
done

SURVEY_TOTAL=${#TO_SURVEY[@]}

# ── Dry run ──────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
  for project_dir in "${TO_SURVEY[@]+"${TO_SURVEY[@]}"}"; do
    slug=$(to_slug "$project_dir")
    escaped_path=$(json_escape "$project_dir")
    escaped_slug=$(json_escape "$slug")
    RESULTS="${RESULTS}{\"path\":\"${escaped_path}\",\"slug\":\"${escaped_slug}\",\"status\":\"would_survey\",\"reason\":null},"
  done
  RESULTS="${RESULTS%,}"
  printf '{"timestamp":"%s","projects_discovered":%d,"projects_skipped":%d,"projects_surveyed":0,"projects_failed":0,"dry_run":true,"results":[%s]}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TOTAL" "$SKIPPED" "$RESULTS"
  exit 0
fi

# ── Concurrent execution ─────────────────────────────────────────────
# Bash 3.2 compat: no associative arrays, no wait -n.
# Use three parallel indexed arrays to track running processes:
#   RUNNING_PIDS[i]     — the background PID
#   RUNNING_PROJECTS[i] — the project_dir for that PID
#   RUNNING_SLUGS[i]    — the slug for that PID
# A sentinel value of "" marks a slot as empty (process reaped).

RUNNING_PIDS=()
RUNNING_PROJECTS=()
RUNNING_SLUGS=()
RUNNING=0
QUEUE_INDEX=0

# launch_next — launch one job from the queue if slots are available
launch_next() {
  if [[ $QUEUE_INDEX -lt $SURVEY_TOTAL ]]; then
    local project_dir slug pid
    project_dir="${TO_SURVEY[$QUEUE_INDEX]}"
    slug=$(to_slug "$project_dir")
    QUEUE_INDEX=$((QUEUE_INDEX + 1))

    printf '[%d/%d] Surveying %s...\n' "$QUEUE_INDEX" "$SURVEY_TOTAL" "$slug" >&2
    run_survey "$project_dir" "$slug" &
    pid=$!

    RUNNING_PIDS+=("$pid")
    RUNNING_PROJECTS+=("$project_dir")
    RUNNING_SLUGS+=("$slug")
    RUNNING=$((RUNNING + 1))
  fi
}

# reap_finished — scan tracked PIDs; for each that has exited, collect result
# and clear its slot.  Returns 1 if nothing was reaped yet (all still running).
reap_finished() {
  local i pid project_dir slug local_exit escaped_path escaped_slug reaped=0

  for i in "${!RUNNING_PIDS[@]}"; do
    pid="${RUNNING_PIDS[$i]}"
    [[ -z "$pid" ]] && continue  # slot already reaped

    if ! kill -0 "$pid" 2>/dev/null; then
      # Process has exited — reap it to get exit code
      wait "$pid" 2>/dev/null && local_exit=0 || local_exit=$?

      project_dir="${RUNNING_PROJECTS[$i]}"
      slug="${RUNNING_SLUGS[$i]}"
      escaped_path=$(json_escape "$project_dir")
      escaped_slug=$(json_escape "$slug")

      if [[ $local_exit -eq 0 ]]; then
        RESULTS="${RESULTS}{\"path\":\"${escaped_path}\",\"slug\":\"${escaped_slug}\",\"status\":\"success\",\"reason\":null},"
        SURVEYED=$((SURVEYED + 1))
        printf '  [done] %s (success)\n' "$slug" >&2
      else
        RESULTS="${RESULTS}{\"path\":\"${escaped_path}\",\"slug\":\"${escaped_slug}\",\"status\":\"failed\",\"reason\":\"exit_code_%d\"}," \
          "$local_exit"
        FAILED=$((FAILED + 1))
        printf '  [fail] %s (exit %d, see %s/%s.err)\n' "$slug" "$local_exit" "$LOG_DIR" "$slug" >&2
      fi

      # Clear slot
      RUNNING_PIDS[i]=""
      RUNNING_PROJECTS[i]=""
      RUNNING_SLUGS[i]=""
      RUNNING=$((RUNNING - 1))
      reaped=$((reaped + 1))

      # Launch replacement immediately
      launch_next
    fi
  done

  [[ $reaped -gt 0 ]]
}

# Fill initial pool
while [[ $RUNNING -lt $MAX_CONCURRENT && $QUEUE_INDEX -lt $SURVEY_TOTAL ]]; do
  launch_next
done

# Drain — poll until all jobs complete
while [[ $RUNNING -gt 0 ]]; do
  if ! reap_finished; then
    # Nothing finished yet — brief pause before next poll
    sleep 1
  fi
done

# ── Output manifest ──────────────────────────────────────────────────
RESULTS="${RESULTS%,}"
printf '{"timestamp":"%s","projects_discovered":%d,"projects_skipped":%d,"projects_surveyed":%d,"projects_failed":%d,"dry_run":false,"results":[%s]}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TOTAL" "$SKIPPED" "$SURVEYED" "$FAILED" "$RESULTS"

printf '\nExcavation complete: %d surveyed, %d skipped, %d failed (of %d discovered)\n' \
  "$SURVEYED" "$SKIPPED" "$FAILED" "$TOTAL" >&2
