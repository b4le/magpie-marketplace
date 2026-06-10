#!/usr/bin/env bash
# =============================================================================
# devkit-cron.sh
#
# Purpose: Two-phase hybrid maintenance orchestrator for the Claude Code
#          Development Kit. Detects schema drift and changelog gaps (Phase 1)
#          then spawns a Claude Code session to apply safe auto-fixes (Phase 2).
#
# Usage:
#   ./devkit-cron.sh [--dry-run] [--force] [--since YYYY-MM-DD] [--help]
#
# Exit codes:
#   0  Success
#   1  Argument / validation error
#   2  Missing dependency
#   3  Network failure (last-run NOT updated)
#   4  Phase 2 (Claude Code session) failed
#
# Dependencies:
#   - bash 4.4+
#   - python3  (stdlib only)
#   - claude   (Claude Code CLI — required for Phase 2)
#   - fetch-changelog.sh, analyze-sync.sh, check-schema-drift.sh (same dir)
#
# Environment:
#   NO_COLOR      Suppress ANSI colour output
#   GITHUB_TOKEN  Optional — passed through to fetch-changelog.sh
# =============================================================================

set -Eeuo pipefail
if (( BASH_VERSINFO[0] > 4 || ( BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4 ) )); then
  shopt -s inherit_errexit
fi

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename -- "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR SCRIPT_NAME

PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PLUGIN_ROOT

readonly FETCH_SCRIPT="${SCRIPT_DIR}/fetch-changelog.sh"
readonly ANALYZE_SCRIPT="${SCRIPT_DIR}/analyze-sync.sh"
readonly DRIFT_SCRIPT="${SCRIPT_DIR}/check-schema-drift.sh"

readonly STATE_DIR="${PLUGIN_ROOT}/local-state/devkit-cron"
readonly LAST_RUN_FILE="${STATE_DIR}/last-run"
readonly REPORTS_DIR="${STATE_DIR}/reports"

readonly TODAY="$(python3 -c 'import datetime; print(datetime.date.today().isoformat())')"
readonly REPORT_RETENTION_DAYS=30

# ---------------------------------------------------------------------------
# Colour helpers (respect NO_COLOR and non-interactive output)
# ---------------------------------------------------------------------------

if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' RESET=''
fi

# ---------------------------------------------------------------------------
# Logging helpers (all to stderr so stdout stays clean for parsed output)
# ---------------------------------------------------------------------------

log_info()    { printf "${DIM}[info]${RESET}  %s\n"    "$*" >&2; }
log_ok()      { printf "${GREEN}[ok]${RESET}    %s\n"  "$*" >&2; }
log_warn()    { printf "${YELLOW}[warn]${RESET}  %s\n" "$*" >&2; }
log_error()   { printf "${RED}[error]${RESET} %s\n"    "$*" >&2; }
log_section() { printf "\n${BOLD}=== %s ===${RESET}\n" "$*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}Usage:${RESET}
  ${SCRIPT_NAME} [OPTIONS]

${BOLD}Description:${RESET}
  Two-phase hybrid maintenance orchestrator for the Claude Code Development Kit.

  ${BOLD}Phase 1 (Shell Detection):${RESET}
    Runs existing scripts to detect changes since last run:
      - fetch-changelog.sh  — new changelog entries
      - analyze-sync.sh     — schema gap analysis
      - check-schema-drift.sh — live schema drift

  ${BOLD}Phase 2 (Claude Code Session):${RESET}
    Only runs if Phase 1 finds actionable items (or --force is set).
    Spawns a Claude Code session to apply safe auto-fixes:
      - Version field updates
      - Kebab-case normalization
      - Tool enum updates
      - model_rationale updates
      - expected-fields.json regeneration
    Runs validators, commits changes, and writes a summary report.

${BOLD}Options:${RESET}
  --dry-run           Run Phase 1 only, do not spawn Claude Code session
  --force             Always run Phase 2, even if Phase 1 finds nothing
  --since YYYY-MM-DD  Override the last-run date for Phase 1 detection
  --help, -h          Show this message and exit

${BOLD}State files:${RESET}
  ${STATE_DIR}/last-run
  ${REPORTS_DIR}/YYYY-MM-DD-phase1.json
  ${REPORTS_DIR}/YYYY-MM-DD.md

${BOLD}Environment:${RESET}
  NO_COLOR       Suppress ANSI colour output
  GITHUB_TOKEN   Passed through to fetch-changelog.sh

${BOLD}Exit codes:${RESET}
  0  Success
  1  Argument or validation error
  2  Missing dependency
  3  Network failure (last-run not updated)
  4  Phase 2 (Claude Code session) failed
EOF
}

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

check_deps() {
  local -a missing=()
  local cmd
  for cmd in python3 bash; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  for script in "$FETCH_SCRIPT" "$ANALYZE_SCRIPT" "$DRIFT_SCRIPT"; do
    if [[ ! -f "$script" ]]; then
      log_error "Required script not found: ${script}"
      exit 2
    fi
  done

  if [[ "${#missing[@]}" -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    exit 2
  fi
}

check_claude_dep() {
  if ! command -v claude &>/dev/null; then
    log_error "claude CLI not found in PATH — required for Phase 2"
    log_error "Install Claude Code: https://claude.ai/code"
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Validate a YYYY-MM-DD date string
# ---------------------------------------------------------------------------

validate_date() {
  local date_str="$1"
  if [[ ! "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    log_error "Invalid date format '${date_str}' — expected YYYY-MM-DD"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# State management helpers
# ---------------------------------------------------------------------------

read_last_run() {
  if [[ -f "$LAST_RUN_FILE" ]]; then
    local date_str
    date_str="$(tr -d '[:space:]' < "$LAST_RUN_FILE")"
    if [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      printf '%s' "$date_str"
      return
    fi
    log_warn "last-run file contains invalid date '${date_str}' — using 7 days ago"
  fi
  # Default: 7 days ago
  python3 -c 'import datetime; print((datetime.date.today() - datetime.timedelta(days=7)).isoformat())'
}

write_last_run() {
  mkdir -p "$STATE_DIR"
  local tmp
  tmp="$(mktemp "${STATE_DIR}/.last-run.XXXXXX")"
  printf '%s\n' "$TODAY" > "$tmp"
  mv -f "$tmp" "$LAST_RUN_FILE"
  log_info "Updated last-run to ${TODAY}"
}

ensure_reports_dir() {
  mkdir -p "$REPORTS_DIR"
}

# ---------------------------------------------------------------------------
# Purge reports older than REPORT_RETENTION_DAYS
# ---------------------------------------------------------------------------

purge_old_reports() {
  if [[ ! -d "$REPORTS_DIR" ]]; then
    return
  fi
  local cutoff
  cutoff="$(python3 -c "import datetime; print((datetime.date.today() - datetime.timedelta(days=${REPORT_RETENTION_DAYS})).isoformat())")"
  local count=0
  while IFS= read -r -d '' report_file; do
    local basename_file
    basename_file="$(basename "$report_file")"
    # Extract date prefix from filenames like YYYY-MM-DD-phase1.json or YYYY-MM-DD.md
    local file_date="${basename_file:0:10}"
    if [[ "$file_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$file_date" < "$cutoff" ]]; then
      rm -f "$report_file"
      (( count++ )) || true
    fi
  done < <(find "$REPORTS_DIR" -maxdepth 1 -type f \( -name '*.json' -o -name '*.md' \) -print0 2>/dev/null)
  if [[ "$count" -gt 0 ]]; then
    log_info "Purged ${count} report(s) older than ${REPORT_RETENTION_DAYS} days"
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

DRY_RUN=false
FORCE=false
SINCE_DATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --since)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        log_error "--since requires a YYYY-MM-DD argument"
        usage >&2
        exit 1
      fi
      SINCE_DATE="$2"
      shift 2
      ;;
    --since=*)
      SINCE_DATE="${1#*=}"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      log_error "Unknown argument: ${1}"
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$SINCE_DATE" ]]; then
  validate_date "$SINCE_DATE"
fi

check_deps

# ---------------------------------------------------------------------------
# Resolve since date
# ---------------------------------------------------------------------------

if [[ -z "$SINCE_DATE" ]]; then
  SINCE_DATE="$(read_last_run)"
  log_info "Using last-run date: ${SINCE_DATE}"
else
  log_info "Using provided --since date: ${SINCE_DATE}"
fi

# ---------------------------------------------------------------------------
# Initialise state directories and purge old reports
# ---------------------------------------------------------------------------

ensure_reports_dir
purge_old_reports

readonly PHASE1_REPORT="${REPORTS_DIR}/${TODAY}-phase1.json"
readonly PHASE2_REPORT="${REPORTS_DIR}/${TODAY}.md"

# ---------------------------------------------------------------------------
# Phase 1: Detection
# ---------------------------------------------------------------------------

log_section "Phase 1: Detection (since ${SINCE_DATE})"

# Aggregate findings
NETWORK_FAILURE=false
CHANGELOG_JSON=""
ANALYZE_JSON=""
DRIFT_EXIT=0

# --- 1a. fetch-changelog.sh ---
log_info "Running fetch-changelog.sh --since ${SINCE_DATE} --json ..."
fetch_exit=0
CHANGELOG_JSON="$(bash "$FETCH_SCRIPT" --since "$SINCE_DATE" --json 2>/dev/null)" || fetch_exit=$?

if [[ "$fetch_exit" -eq 3 ]]; then
  log_warn "fetch-changelog.sh: network failure (exit 3) — changelog check skipped"
  NETWORK_FAILURE=true
elif [[ "$fetch_exit" -ne 0 ]]; then
  log_warn "fetch-changelog.sh: non-zero exit ${fetch_exit} — continuing without changelog data"
  CHANGELOG_JSON=""
else
  local_count="$(python3 -c "import json,sys; data=json.loads(sys.argv[1]) if sys.argv[1] else []; print(len(data))" "${CHANGELOG_JSON:-[]}" 2>/dev/null || echo 0)"
  log_info "fetch-changelog.sh: ${local_count} entries found since ${SINCE_DATE}"
fi

# --- 1b. analyze-sync.sh ---
log_info "Running analyze-sync.sh --since ${SINCE_DATE} --json ..."
analyze_exit=0
ANALYZE_JSON="$(bash "$ANALYZE_SCRIPT" --since "$SINCE_DATE" --json 2>/dev/null)" || analyze_exit=$?

if [[ "$analyze_exit" -eq 3 ]]; then
  log_warn "analyze-sync.sh: network failure (exit 3) — sync analysis skipped"
  NETWORK_FAILURE=true
elif [[ "$analyze_exit" -ne 0 ]]; then
  log_warn "analyze-sync.sh: non-zero exit ${analyze_exit} — continuing without sync analysis"
  ANALYZE_JSON=""
else
  log_info "analyze-sync.sh: completed"
fi

# --- 1c. check-schema-drift.sh ---
log_info "Running check-schema-drift.sh ..."
drift_exit=0
bash "$DRIFT_SCRIPT" >/dev/null 2>&1 || drift_exit=$?

if [[ "$drift_exit" -eq 1 ]]; then
  log_warn "check-schema-drift.sh: drift detected (exit 1)"
elif [[ "$drift_exit" -eq 2 ]]; then
  log_warn "check-schema-drift.sh: missing dependency or file (exit 2) — skipping"
  drift_exit=0  # treat as non-actionable for Phase 2 triggering
elif [[ "$drift_exit" -eq 0 ]]; then
  log_ok "check-schema-drift.sh: no drift detected"
fi
DRIFT_EXIT="$drift_exit"

# --- Bail on network failure before writing state ---
if [[ "$NETWORK_FAILURE" == true ]]; then
  log_error "Network failure occurred — Phase 1 incomplete, last-run NOT updated"
  # Write partial phase1 report for diagnostics
  python3 - "$SINCE_DATE" "$TODAY" "$CHANGELOG_JSON" "$ANALYZE_JSON" "$DRIFT_EXIT" > "$PHASE1_REPORT" <<'PYEOF'
import json, sys
since       = sys.argv[1]
today       = sys.argv[2]
cl_raw      = sys.argv[3]
an_raw      = sys.argv[4]
drift_exit  = int(sys.argv[5])

cl_entries = []
try:
    if cl_raw:
        cl_entries = json.loads(cl_raw)
except Exception:
    pass

an_data = {}
try:
    if an_raw:
        an_data = json.loads(an_raw)
except Exception:
    pass

report = {
    "date": today,
    "since": since,
    "network_failure": True,
    "changelog": {
        "entries": cl_entries,
        "count": len(cl_entries),
    },
    "sync_analysis": an_data,
    "schema_drift": {
        "exit_code": drift_exit,
        "drift_detected": drift_exit == 1,
    },
    "summary": {
        "action_required": 0,
        "needs_review": 0,
        "phase2_triggered": False,
    }
}
print(json.dumps(report, indent=2))
PYEOF
  exit 3
fi

# --- Summarise Phase 1 findings ---
log_info "Summarising Phase 1 findings ..."

phase1_report="$(python3 - "$SINCE_DATE" "$TODAY" "$CHANGELOG_JSON" "$ANALYZE_JSON" "$DRIFT_EXIT" <<'PYEOF'
import json, sys

since       = sys.argv[1]
today       = sys.argv[2]
cl_raw      = sys.argv[3]
an_raw      = sys.argv[4]
drift_exit  = int(sys.argv[5])

cl_entries = []
try:
    if cl_raw:
        cl_entries = json.loads(cl_raw)
except Exception:
    pass

an_data = {}
try:
    if an_raw:
        an_data = json.loads(an_raw)
except Exception:
    pass

action_required = an_data.get("summary", {}).get("action_required", 0)
needs_review    = an_data.get("summary", {}).get("needs_review", 0)

report = {
    "date": today,
    "since": since,
    "network_failure": False,
    "changelog": {
        "entries": cl_entries,
        "count": len(cl_entries),
    },
    "sync_analysis": an_data,
    "schema_drift": {
        "exit_code": drift_exit,
        "drift_detected": drift_exit == 1,
    },
    "summary": {
        "action_required": action_required,
        "needs_review": needs_review,
        "phase2_triggered": False,
    }
}
print(json.dumps(report, indent=2))
PYEOF
)"

printf '%s\n' "$phase1_report" > "$PHASE1_REPORT"
log_info "Phase 1 report written to: ${PHASE1_REPORT}"

# --- Determine whether Phase 2 should run ---
action_required="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['summary']['action_required'])" "$phase1_report" 2>/dev/null || echo 0)"
needs_review="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['summary']['needs_review'])" "$phase1_report" 2>/dev/null || echo 0)"
drift_detected="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('true' if d['schema_drift']['drift_detected'] else 'false')" "$phase1_report" 2>/dev/null || echo false)"
changelog_count="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['changelog']['count'])" "$phase1_report" 2>/dev/null || echo 0)"

log_info "Phase 1 summary: changelog_entries=${changelog_count}, action_required=${action_required}, needs_review=${needs_review}, drift_detected=${drift_detected}"

PHASE2_NEEDED=false
if [[ "$FORCE" == true ]]; then
  PHASE2_NEEDED=true
  log_info "Phase 2 triggered: --force flag set"
elif [[ "$action_required" -gt 0 ]]; then
  PHASE2_NEEDED=true
  log_info "Phase 2 triggered: ${action_required} action_required item(s)"
elif [[ "$needs_review" -gt 0 ]]; then
  PHASE2_NEEDED=true
  log_info "Phase 2 triggered: ${needs_review} needs_review item(s)"
elif [[ "$drift_detected" == "true" ]]; then
  PHASE2_NEEDED=true
  log_info "Phase 2 triggered: schema drift detected"
else
  log_ok "Phase 1: nothing actionable found — Phase 2 not needed"
fi

# --- Dry run: stop after Phase 1 ---
if [[ "$DRY_RUN" == true ]]; then
  log_info "--dry-run: stopping after Phase 1 (Phase 2 skipped)"
  write_last_run
  exit 0
fi

if [[ "$PHASE2_NEEDED" == false ]]; then
  write_last_run
  exit 0
fi

# ---------------------------------------------------------------------------
# Phase 2: Claude Code session
# ---------------------------------------------------------------------------

log_section "Phase 2: Claude Code session"

check_claude_dep

readonly GIT_BRANCH="devkit/auto-update-${TODAY}"

# Guard: ensure variables expanded into the prompt contain no newlines
for _path in "$PLUGIN_ROOT" "$TODAY" "$SCRIPT_DIR"; do
  if [[ "$_path" == *$'\n'* ]]; then
    log_error "Path variable contains unexpected newline — aborting"
    exit 1
  fi
done

PHASE2_PROMPT="You are a devkit maintenance agent. Your job is to apply safe auto-fixes to the Claude Code Development Kit plugin.

## Context

Working directory: ${PLUGIN_ROOT}
Git branch to create: ${GIT_BRANCH}
Phase 1 report: ${PHASE1_REPORT}
Phase 2 summary report (write here): ${PHASE2_REPORT}
Today's date: ${TODAY}

## Instructions

### Step 1: Read the Phase 1 report
Read the Phase 1 report at: ${PHASE1_REPORT}
This JSON report describes what changes were detected. Use it to guide your work.

### Step 2: Create a git branch
Run: git -C ${PLUGIN_ROOT} checkout -b ${GIT_BRANCH}
If the branch already exists, check it out instead.

### Step 3: Apply safe auto-fixes only
Apply ONLY these categories of safe fixes. Do NOT make speculative changes.

**Safe fixes (apply these):**
- Version fields: Update version strings in plugin.json or schema files where a clear new version is mentioned in the changelog
- Kebab-case normalization: Rename any camelCase filenames or YAML/JSON keys that should be kebab-case per the devkit conventions (check existing patterns first)
- Tool enum updates: If new Claude Code built-in tools appear in the changelog, add them to schemas/tools-enum.json
- model_rationale: If new Claude model shorthands appear in changelog, add them to the model enum in schemas/agent-frontmatter.schema.json
- expected-fields.json regeneration: After any schema edits, always regenerate by running: bash ${SCRIPT_DIR}/check-schema-drift.sh --update

**Do NOT do these (require human review):**
- Structural schema changes (adding/removing required fields)
- Changing existing field semantics or types
- Modifying hook event names without clear changelog evidence
- Deleting any files
- Modifying test or eval scripts
- Pushing to remote

### Step 4: Run validators
After making any changes, run:
  bash ${PLUGIN_ROOT}/evals/validate-plugin.sh ${PLUGIN_ROOT}

If validation fails, review the errors. Fix only issues that are safe and clearly caused by your changes. Do not suppress or work around validators.

### Step 5: Commit changes
If you made any changes:
  git -C ${PLUGIN_ROOT} add -A
  git -C ${PLUGIN_ROOT} commit -m 'chore(devkit): auto-update ${TODAY} — version fields, tool enums, schema sync'

If there are no changes to commit, that is fine — note it in the summary.

### Step 6: Write summary report
Write a markdown summary to: ${PHASE2_REPORT}

The summary must include:
- Date: ${TODAY}
- Branch: ${GIT_BRANCH}
- Phase 1 findings summary (from the phase1 report)
- What changes were made (list each file modified and what changed)
- Validator outcome (pass/fail + any warnings)
- Any items that need human review (things you detected but could not safely auto-fix)
- Git commit hash (if a commit was made)

## Important constraints
- Only make changes inside: ${PLUGIN_ROOT}
- Do not modify scripts in ${SCRIPT_DIR} (the maintenance scripts themselves)
- Do not push to any remote
- Do not install packages or modify system state
- If you are unsure about a change, skip it and note it in the 'needs human review' section
- All changes must be reversible with git revert
"

log_info "Spawning Claude Code session ..."
log_info "Branch: ${GIT_BRANCH}"
log_info "Phase 1 report: ${PHASE1_REPORT}"

phase2_exit=0
# NOTE: --dangerously-skip-permissions is required for unattended cron operation.
# Blast radius is limited via --allowedTools to file operations and shell only.
claude -p "$PHASE2_PROMPT" \
  --model sonnet \
  --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
  --dangerously-skip-permissions \
  --no-session-persistence \
  --add-dir "$PLUGIN_ROOT" \
  2>&1 || phase2_exit=$?

if [[ "$phase2_exit" -ne 0 ]]; then
  log_error "Phase 2 (Claude Code session) failed with exit code ${phase2_exit}"
  # Update Phase 1 report to record Phase 2 failure
  python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
data['summary']['phase2_triggered'] = True
data['summary']['phase2_exit_code'] = int(sys.argv[2])
data['summary']['phase2_failed'] = True
with open(sys.argv[1], 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" "$PHASE1_REPORT" "$phase2_exit" 2>/dev/null || true
  exit 4
fi

log_ok "Phase 2 completed successfully"

# Update Phase 1 report to record Phase 2 success
python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
data['summary']['phase2_triggered'] = True
data['summary']['phase2_exit_code'] = 0
data['summary']['phase2_failed'] = False
data['summary']['phase2_report'] = sys.argv[2]
with open(sys.argv[1], 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" "$PHASE1_REPORT" "$PHASE2_REPORT" 2>/dev/null || true

if [[ -f "$PHASE2_REPORT" ]]; then
  log_info "Phase 2 summary written to: ${PHASE2_REPORT}"
else
  log_warn "Phase 2 summary report not found at: ${PHASE2_REPORT} (Claude may not have written it)"
fi

# ---------------------------------------------------------------------------
# Finalise: update last-run on success
# ---------------------------------------------------------------------------

write_last_run

log_section "Done"
log_ok "devkit-cron completed successfully for ${TODAY}"
log_info "Phase 1 report: ${PHASE1_REPORT}"
if [[ -f "$PHASE2_REPORT" ]]; then
  log_info "Phase 2 report: ${PHASE2_REPORT}"
fi
