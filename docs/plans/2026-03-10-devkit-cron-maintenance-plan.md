# Devkit Cron Maintenance — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a daily cron job (macOS launchd) that detects Claude Code changelog changes cheaply via shell scripts, then spawns a Claude Code session only when fixes are needed.

**Architecture:** Two-phase hybrid pipeline. Phase 1 runs existing devkit shell scripts (fetch-changelog, analyze-sync, check-schema-drift) to detect changes at zero API cost. Phase 2 spawns `claude -p` with the devkit-maintainer agent only when actionable items are found. State tracked via timestamp file; reports retained 30 days.

**Tech Stack:** Bash 4.4+, macOS launchd, Claude Code CLI (`claude -p`), existing devkit scripts

**Design doc:** `docs/plans/2026-03-10-devkit-cron-maintenance-design.md`

---

### Task 1: Create directory structure and gitignore

**Files:**
- Create: `claude-code-development-kit/local-state/.gitkeep`
- Create: `claude-code-development-kit/local-state/.gitignore`

**Step 1: Create local-state directory with gitignore**

```bash
mkdir -p claude-code-development-kit/local-state/devkit-cron/reports
```

Create `claude-code-development-kit/local-state/.gitignore`:
```
# State files are machine-local, not committed
*
!.gitignore
!.gitkeep
```

Create `claude-code-development-kit/local-state/.gitkeep`:
```
```

**Step 2: Verify structure**

Run: `ls -la claude-code-development-kit/local-state/`
Expected: `.gitignore` and `.gitkeep` present, `devkit-cron/reports/` directory exists

**Step 3: Commit**

```bash
git add claude-code-development-kit/local-state/.gitignore claude-code-development-kit/local-state/.gitkeep
git commit -m "chore(devkit-cron): add local-state directory for cron state files"
```

---

### Task 2: Build devkit-cron.sh — scaffold with argument parsing and state management

**Files:**
- Create: `claude-code-development-kit/scripts/devkit-cron.sh`

**Step 1: Write the orchestrator scaffold**

Create `claude-code-development-kit/scripts/devkit-cron.sh` — follow the same patterns as the existing scripts (set -Eeuo pipefail, colour helpers, logging, usage function). Include:

```bash
#!/usr/bin/env bash
# =============================================================================
# devkit-cron.sh
#
# Purpose: Two-phase hybrid maintenance pipeline for the claude-code-development-kit.
#          Phase 1: Shell-based detection (cheap, no API tokens).
#          Phase 2: Claude Code session (only when changes detected).
#
# Usage:
#   ./devkit-cron.sh [--dry-run] [--force] [--since YYYY-MM-DD] [--help]
#
# Exit codes:
#   0  Success (no changes found, or changes detected and Phase 2 completed)
#   1  Argument / validation error
#   2  Missing dependency
#   3  Network failure in Phase 1
#   4  Phase 2 (Claude Code session) failed
#
# Dependencies:
#   - bash 4.4+
#   - curl, python3 (via fetch-changelog.sh / analyze-sync.sh)
#   - claude CLI (only needed if Phase 2 triggers)
#
# Environment:
#   NO_COLOR         Suppress ANSI colour output
#   GITHUB_TOKEN     Optional — passed through to fetch scripts
#   DEVKIT_CRON_DIR  Override state directory (default: <plugin-root>/local-state/devkit-cron)
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

readonly STATE_DIR="${DEVKIT_CRON_DIR:-${PLUGIN_ROOT}/local-state/devkit-cron}"
readonly LAST_RUN_FILE="${STATE_DIR}/last-run"
readonly REPORTS_DIR="${STATE_DIR}/reports"
readonly LOG_FILE="${STATE_DIR}/devkit-cron.log"

readonly FETCH_SCRIPT="${SCRIPT_DIR}/fetch-changelog.sh"
readonly ANALYZE_SCRIPT="${SCRIPT_DIR}/analyze-sync.sh"
readonly DRIFT_SCRIPT="${SCRIPT_DIR}/check-schema-drift.sh"

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
# Logging helpers (stderr + log file)
# ---------------------------------------------------------------------------

_log() {
  local level="$1" color="$2"
  shift 2
  local msg
  msg="$(printf "[%s] %s" "$level" "$*")"
  printf "${color}%s${RESET}\n" "$msg" >&2
  # Append to log file (plain text, no ANSI)
  printf "[%s] [%s] %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

log_info()  { _log "info"  "$DIM"    "$@"; }
log_ok()    { _log "ok"    "$GREEN"  "$@"; }
log_warn()  { _log "warn"  "$YELLOW" "$@"; }
log_error() { _log "error" "$RED"    "$@"; }
log_step()  { _log "step"  "$CYAN"   "$@"; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}Usage:${RESET}
  ${SCRIPT_NAME} [OPTIONS]

${BOLD}Description:${RESET}
  Two-phase hybrid maintenance pipeline for the claude-code-development-kit.

  Phase 1: Runs fetch-changelog, analyze-sync, and check-schema-drift to
           detect changes since last run. No API tokens consumed.

  Phase 2: Only runs if Phase 1 finds actionable items. Spawns a Claude Code
           session to apply safe auto-fixes and report manual-review items.

${BOLD}Options:${RESET}
  --dry-run             Run Phase 1 only; report what would trigger Phase 2
  --force               Skip the decision gate and always run Phase 2
  --since YYYY-MM-DD    Override the last-run date (useful for first run or re-check)
  --help, -h            Show this message and exit

${BOLD}Environment:${RESET}
  NO_COLOR          Suppress ANSI colour output
  GITHUB_TOKEN      Passed to fetch scripts for authenticated GitHub requests
  DEVKIT_CRON_DIR   Override state directory (default: <plugin-root>/local-state/devkit-cron)

${BOLD}Exit codes:${RESET}
  0  Success
  1  Argument or validation error
  2  Missing dependency
  3  Network failure in Phase 1
  4  Phase 2 (Claude Code session) failed
EOF
}

# ---------------------------------------------------------------------------
# State management
# ---------------------------------------------------------------------------

ensure_state_dir() {
  mkdir -p "$STATE_DIR" "$REPORTS_DIR"
}

read_last_run() {
  if [[ -f "$LAST_RUN_FILE" ]]; then
    cat "$LAST_RUN_FILE"
  else
    # Default: 7 days ago
    python3 -c "from datetime import date, timedelta; print((date.today() - timedelta(days=7)).isoformat())"
  fi
}

write_last_run() {
  local today
  today="$(python3 -c 'from datetime import date; print(date.today().isoformat())')"
  printf '%s\n' "$today" > "$LAST_RUN_FILE"
}

cleanup_old_reports() {
  if [[ -d "$REPORTS_DIR" ]]; then
    find "$REPORTS_DIR" -type f -mtime +"$REPORT_RETENTION_DAYS" -delete 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

DRY_RUN=false
FORCE=false
SINCE_OVERRIDE=""

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
        exit 1
      fi
      SINCE_OVERRIDE="$2"
      shift 2
      ;;
    --since=*)
      SINCE_OVERRIDE="${1#*=}"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown argument: ${1}"
      usage >&2
      exit 1
      ;;
  esac
done

# Validate --since format if provided
if [[ -n "$SINCE_OVERRIDE" ]]; then
  if [[ ! "$SINCE_OVERRIDE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    log_error "Invalid date format '${SINCE_OVERRIDE}' — expected YYYY-MM-DD"
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

check_deps() {
  local -a missing=()
  for cmd in python3 curl bash; do
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

# ---------------------------------------------------------------------------
# Phase 1: Detection
# ---------------------------------------------------------------------------

run_phase1() {
  local since_date="$1"
  local today
  today="$(python3 -c 'from datetime import date; print(date.today().isoformat())')"

  local phase1_report="${REPORTS_DIR}/${today}-phase1.json"
  local changes_found=false

  log_step "Phase 1: Detection (since ${since_date})"

  # --- 1a. Fetch changelog ---
  log_info "Running fetch-changelog.sh --since ${since_date} --json ..."
  local changelog_output=""
  local changelog_exit=0
  changelog_output="$(bash "$FETCH_SCRIPT" --since "$since_date" --json 2>/dev/null)" || changelog_exit=$?

  if [[ "$changelog_exit" -eq 3 ]]; then
    log_warn "Network failure in fetch-changelog.sh — will retry next run"
    exit 3
  elif [[ "$changelog_exit" -ne 0 ]]; then
    log_warn "fetch-changelog.sh exited ${changelog_exit} — continuing with other checks"
    changelog_output="[]"
  fi

  # Check if changelog has entries
  local changelog_count=0
  if [[ -n "$changelog_output" && "$changelog_output" != "[]" ]]; then
    changelog_count="$(printf '%s' "$changelog_output" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)"
  fi
  if [[ "$changelog_count" -gt 0 ]]; then
    changes_found=true
    log_info "Found ${changelog_count} new changelog entries"
  else
    log_info "No new changelog entries"
  fi

  # --- 1b. Analyze sync ---
  log_info "Running analyze-sync.sh --since ${since_date} --json ..."
  local sync_output=""
  local sync_exit=0
  sync_output="$(bash "$ANALYZE_SCRIPT" --since "$since_date" --json 2>/dev/null)" || sync_exit=$?

  if [[ "$sync_exit" -eq 3 ]]; then
    log_warn "Network failure in analyze-sync.sh — will retry next run"
    exit 3
  elif [[ "$sync_exit" -ne 0 ]]; then
    log_warn "analyze-sync.sh exited ${sync_exit} — continuing"
    sync_output='{"findings":[],"summary":{"action_required":0,"needs_review":0}}'
  fi

  local action_required=0
  local needs_review=0
  if [[ -n "$sync_output" ]]; then
    action_required="$(printf '%s' "$sync_output" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("summary",{}).get("action_required",0))' 2>/dev/null || echo 0)"
    needs_review="$(printf '%s' "$sync_output" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("summary",{}).get("needs_review",0))' 2>/dev/null || echo 0)"
  fi
  if [[ "$action_required" -gt 0 || "$needs_review" -gt 0 ]]; then
    changes_found=true
    log_info "Sync analysis: ${action_required} action required, ${needs_review} needs review"
  else
    log_info "Sync analysis: no actionable items"
  fi

  # --- 1c. Check schema drift ---
  log_info "Running check-schema-drift.sh ..."
  local drift_exit=0
  bash "$DRIFT_SCRIPT" >/dev/null 2>&1 || drift_exit=$?

  if [[ "$drift_exit" -eq 1 ]]; then
    changes_found=true
    log_info "Schema drift detected"
  elif [[ "$drift_exit" -eq 0 ]]; then
    log_info "No schema drift"
  else
    log_warn "check-schema-drift.sh exited ${drift_exit} — continuing"
  fi

  # --- Write Phase 1 report ---
  python3 -c "
import json, sys
report = {
    'since': sys.argv[1],
    'date': sys.argv[2],
    'changelog_entries': int(sys.argv[3]),
    'sync_action_required': int(sys.argv[4]),
    'sync_needs_review': int(sys.argv[5]),
    'schema_drift': sys.argv[6] == 'true',
    'changes_found': sys.argv[7] == 'true',
    'changelog_raw': json.loads(sys.argv[8]) if sys.argv[8] else [],
    'sync_raw': json.loads(sys.argv[9]) if sys.argv[9] else {}
}
with open(sys.argv[10], 'w') as f:
    json.dump(report, f, indent=2)
    f.write('\n')
" "$since_date" "$today" "$changelog_count" "$action_required" "$needs_review" \
  "$( [[ "$drift_exit" -eq 1 ]] && echo true || echo false )" \
  "$( $changes_found && echo true || echo false )" \
  "${changelog_output:-[]}" \
  "${sync_output:-{}}" \
  "$phase1_report"

  log_info "Phase 1 report written to: ${phase1_report}"

  # Return whether changes were found
  if $changes_found; then
    return 0
  else
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Phase 2: Claude Code Session
# ---------------------------------------------------------------------------

run_phase2() {
  local phase1_report="$1"
  local today
  today="$(python3 -c 'from datetime import date; print(date.today().isoformat())')"
  local summary_report="${REPORTS_DIR}/${today}.md"
  local branch_name="devkit/auto-update-${today}"

  log_step "Phase 2: Claude Code Session"

  # Check claude CLI is available
  if ! command -v claude &>/dev/null; then
    log_error "claude CLI not found in PATH — cannot run Phase 2"
    exit 4
  fi

  local prompt
  prompt="$(cat <<PROMPT
You are running as a scheduled maintenance job for the claude-code-development-kit.

## Context

A Phase 1 detection scan found changes that need attention. The full report is at:
${phase1_report}

Read that file first to understand what was found.

## Your task

Working directory: ${PLUGIN_ROOT}

1. Read the Phase 1 report at ${phase1_report}
2. Create and switch to a new git branch: ${branch_name}
3. Apply ONLY these safe auto-fixes:
   - Update version fields where outdated
   - Normalize field names to kebab-case where inconsistent
   - Add new tools to schemas/tools-enum.json if the changelog mentions new built-in tools
   - Add missing model_rationale fields to agent definitions
   - Regenerate scripts/expected-fields.json if schemas changed (run: bash scripts/check-schema-drift.sh --update)
4. Run the validators to verify your changes: bash evals/validate-plugin.sh .
5. Commit all changes with a descriptive message
6. Write a summary report to ${summary_report} with sections:
   - ## Auto-Fixed: list what you changed and why
   - ## Manual Review Required: list items from the Phase 1 report that need human attention (description rewrites, tool list changes, permission mode changes, structural schema changes)
   - ## Validation Results: pass/fail summary from validators

Do NOT:
- Rewrite descriptions
- Change tool lists on agents or skills
- Change permission modes
- Make structural schema changes
- Delete any files
- Push the branch
PROMPT
)"

  log_info "Spawning Claude Code session ..."

  local claude_exit=0
  claude -p "$prompt" \
    --model sonnet \
    --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
    --dangerously-skip-permissions \
    --no-session-persistence \
    --add-dir "$PLUGIN_ROOT" \
    2>>"$LOG_FILE" || claude_exit=$?

  if [[ "$claude_exit" -ne 0 ]]; then
    log_error "Claude Code session exited with code ${claude_exit}"
    return 4
  fi

  if [[ -f "$summary_report" ]]; then
    log_ok "Summary report written to: ${summary_report}"
  else
    log_warn "Claude session completed but no summary report found at: ${summary_report}"
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  check_deps
  ensure_state_dir
  cleanup_old_reports

  # Determine since date
  local since_date
  if [[ -n "$SINCE_OVERRIDE" ]]; then
    since_date="$SINCE_OVERRIDE"
  else
    since_date="$(read_last_run)"
  fi

  log_info "Devkit cron maintenance starting (since: ${since_date})"

  # Run Phase 1
  local phase1_found_changes=false
  if run_phase1 "$since_date"; then
    phase1_found_changes=true
  fi

  local today
  today="$(python3 -c 'from datetime import date; print(date.today().isoformat())')"
  local phase1_report="${REPORTS_DIR}/${today}-phase1.json"

  # Decision gate
  if $phase1_found_changes || $FORCE; then
    if $FORCE && ! $phase1_found_changes; then
      log_info "No changes found but --force specified — proceeding to Phase 2"
    else
      log_info "Changes detected — proceeding to Phase 2"
    fi

    if $DRY_RUN; then
      log_info "[DRY RUN] Would spawn Claude Code session with Phase 1 report: ${phase1_report}"
      log_info "[DRY RUN] Phase 1 report contents:"
      cat "$phase1_report" >&2
      write_last_run
      exit 0
    fi

    if run_phase2 "$phase1_report"; then
      write_last_run
      log_ok "Maintenance complete — check branch devkit/auto-update-${today}"
    else
      log_error "Phase 2 failed — last-run NOT updated (will retry next run)"
      exit 4
    fi
  else
    log_ok "No changes detected — nothing to do"
    write_last_run
  fi
}

main
```

**Step 2: Make executable and verify syntax**

Run: `chmod +x claude-code-development-kit/scripts/devkit-cron.sh && bash -n claude-code-development-kit/scripts/devkit-cron.sh`
Expected: No output (clean parse)

**Step 3: Verify --help works**

Run: `bash claude-code-development-kit/scripts/devkit-cron.sh --help`
Expected: Usage text printed, exit 0

**Step 4: Verify --dry-run works end-to-end**

Run: `bash claude-code-development-kit/scripts/devkit-cron.sh --dry-run --since 2026-03-01`
Expected: Phase 1 runs all three detection scripts, writes a phase1 JSON report, prints `[DRY RUN]` message instead of spawning Claude. May exit 3 if offline — that's fine.

**Step 5: Commit**

```bash
git add claude-code-development-kit/scripts/devkit-cron.sh
git commit -m "feat(devkit-cron): add two-phase hybrid maintenance orchestrator"
```

---

### Task 3: Create launchd plist

**Files:**
- Create: `claude-code-development-kit/scripts/com.magpie.devkit-cron.plist`

**Step 1: Write the plist**

Create `claude-code-development-kit/scripts/com.magpie.devkit-cron.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.magpie.devkit-cron</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>__PLUGIN_ROOT__/scripts/devkit-cron.sh</string>
    </array>

    <key>WorkingDirectory</key>
    <string>__PLUGIN_ROOT__</string>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>8</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>__STATE_DIR__/launchd-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>__STATE_DIR__/launchd-stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
        <key>NO_COLOR</key>
        <string>1</string>
    </dict>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
```

Note: `__PLUGIN_ROOT__` and `__STATE_DIR__` are placeholders that `install-cron.sh` replaces with actual paths during installation.

**Step 2: Verify plist syntax**

Run: `plutil -lint claude-code-development-kit/scripts/com.magpie.devkit-cron.plist`
Expected: `OK` (plutil validates XML structure)

**Step 3: Commit**

```bash
git add claude-code-development-kit/scripts/com.magpie.devkit-cron.plist
git commit -m "feat(devkit-cron): add launchd plist template for daily scheduling"
```

---

### Task 4: Create install-cron.sh

**Files:**
- Create: `claude-code-development-kit/scripts/install-cron.sh`

**Step 1: Write the install script**

Create `claude-code-development-kit/scripts/install-cron.sh`:

```bash
#!/usr/bin/env bash
# =============================================================================
# install-cron.sh
#
# Purpose: Install or uninstall the devkit-cron launchd agent.
#
# Usage:
#   ./install-cron.sh [--uninstall] [--help]
#
# Exit codes:
#   0  Success
#   1  Error
# =============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename -- "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR SCRIPT_NAME

PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PLUGIN_ROOT

readonly PLIST_TEMPLATE="${SCRIPT_DIR}/com.magpie.devkit-cron.plist"
readonly PLIST_LABEL="com.magpie.devkit-cron"
readonly PLIST_DEST="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"
readonly STATE_DIR="${PLUGIN_ROOT}/local-state/devkit-cron"

# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------

if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BOLD='' RESET=''
fi

log_ok()    { printf "${GREEN}[ok]${RESET}    %s\n" "$*"; }
log_info()  { printf "        %s\n" "$*"; }
log_warn()  { printf "${YELLOW}[warn]${RESET}  %s\n" "$*"; }
log_error() { printf "${RED}[error]${RESET} %s\n" "$*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}Usage:${RESET}
  ${SCRIPT_NAME} [OPTIONS]

${BOLD}Description:${RESET}
  Installs or uninstalls the devkit-cron launchd agent for daily
  maintenance of the claude-code-development-kit.

${BOLD}Options:${RESET}
  --uninstall    Remove the launchd agent and clean up
  --status       Show current installation status
  --help, -h     Show this message and exit
EOF
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

do_install() {
  # Pre-flight checks
  if [[ ! -f "$PLIST_TEMPLATE" ]]; then
    log_error "Plist template not found at: ${PLIST_TEMPLATE}"
    exit 1
  fi

  if [[ ! -f "${SCRIPT_DIR}/devkit-cron.sh" ]]; then
    log_error "devkit-cron.sh not found at: ${SCRIPT_DIR}/devkit-cron.sh"
    exit 1
  fi

  # Check for claude CLI
  if ! command -v claude &>/dev/null; then
    log_warn "claude CLI not found in PATH — Phase 2 will fail until installed"
  fi

  # Create state directories
  mkdir -p "$STATE_DIR/reports"
  log_ok "State directory: ${STATE_DIR}"

  # Seed last-run if not present
  if [[ ! -f "${STATE_DIR}/last-run" ]]; then
    local seed_date
    seed_date="$(python3 -c 'from datetime import date, timedelta; print((date.today() - timedelta(days=7)).isoformat())')"
    printf '%s\n' "$seed_date" > "${STATE_DIR}/last-run"
    log_ok "Seeded last-run to: ${seed_date}"
  else
    log_info "last-run already exists: $(cat "${STATE_DIR}/last-run")"
  fi

  # Generate plist from template (replace placeholders)
  mkdir -p "$(dirname "$PLIST_DEST")"
  sed \
    -e "s|__PLUGIN_ROOT__|${PLUGIN_ROOT}|g" \
    -e "s|__STATE_DIR__|${STATE_DIR}|g" \
    "$PLIST_TEMPLATE" > "$PLIST_DEST"
  log_ok "Plist installed to: ${PLIST_DEST}"

  # Validate generated plist
  if ! plutil -lint "$PLIST_DEST" >/dev/null 2>&1; then
    log_error "Generated plist failed validation — check ${PLIST_DEST}"
    exit 1
  fi

  # Unload first if already loaded (idempotent)
  launchctl bootout "gui/$(id -u)/${PLIST_LABEL}" 2>/dev/null || true

  # Load the agent
  if launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST" 2>/dev/null; then
    log_ok "Launchd agent loaded: ${PLIST_LABEL}"
  else
    # Fallback to legacy load for older macOS
    if launchctl load "$PLIST_DEST" 2>/dev/null; then
      log_ok "Launchd agent loaded (legacy): ${PLIST_LABEL}"
    else
      log_error "Failed to load launchd agent"
      exit 1
    fi
  fi

  printf "\n${GREEN}${BOLD}Installed successfully!${RESET}\n"
  printf "  Schedule: Daily at 08:00\n"
  printf "  Logs:     ${STATE_DIR}/launchd-stdout.log\n"
  printf "  Reports:  ${STATE_DIR}/reports/\n"
  printf "\n  Manual run: bash %s/devkit-cron.sh --dry-run\n" "$SCRIPT_DIR"
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------

do_uninstall() {
  # Unload the agent
  launchctl bootout "gui/$(id -u)/${PLIST_LABEL}" 2>/dev/null || \
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
  log_ok "Launchd agent unloaded"

  # Remove plist
  if [[ -f "$PLIST_DEST" ]]; then
    rm "$PLIST_DEST"
    log_ok "Plist removed: ${PLIST_DEST}"
  else
    log_info "Plist not found (already removed)"
  fi

  printf "\n${GREEN}Uninstalled.${RESET} State files preserved at: ${STATE_DIR}\n"
  printf "  To remove state: rm -rf %s\n" "$STATE_DIR"
}

# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------

do_status() {
  printf "${BOLD}Devkit Cron Status${RESET}\n\n"

  # Check plist
  if [[ -f "$PLIST_DEST" ]]; then
    log_ok "Plist installed: ${PLIST_DEST}"
  else
    log_warn "Plist not found: ${PLIST_DEST}"
  fi

  # Check if loaded
  if launchctl print "gui/$(id -u)/${PLIST_LABEL}" &>/dev/null; then
    log_ok "Agent loaded in launchd"
  else
    log_warn "Agent not loaded"
  fi

  # Check last run
  if [[ -f "${STATE_DIR}/last-run" ]]; then
    log_ok "Last run: $(cat "${STATE_DIR}/last-run")"
  else
    log_warn "No last-run file found"
  fi

  # Count reports
  local report_count=0
  if [[ -d "$REPORTS_DIR" ]]; then
    report_count="$(find "${STATE_DIR}/reports" -name '*.md' -o -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
  fi
  log_info "Reports on disk: ${report_count}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

ACTION="install"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall) ACTION="uninstall"; shift ;;
    --status)    ACTION="status"; shift ;;
    --help|-h)   usage; exit 0 ;;
    *)
      log_error "Unknown argument: ${1}"
      usage >&2
      exit 1
      ;;
  esac
done

readonly REPORTS_DIR="${STATE_DIR}/reports"

case "$ACTION" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  status)    do_status ;;
esac
```

**Step 2: Make executable and verify syntax**

Run: `chmod +x claude-code-development-kit/scripts/install-cron.sh && bash -n claude-code-development-kit/scripts/install-cron.sh`
Expected: No output (clean parse)

**Step 3: Verify --help works**

Run: `bash claude-code-development-kit/scripts/install-cron.sh --help`
Expected: Usage text, exit 0

**Step 4: Commit**

```bash
git add claude-code-development-kit/scripts/install-cron.sh
git commit -m "feat(devkit-cron): add install/uninstall script for launchd agent"
```

---

### Task 5: End-to-end verification

**Step 1: Run dry-run to verify full Phase 1 pipeline**

Run: `bash claude-code-development-kit/scripts/devkit-cron.sh --dry-run`
Expected: All three detection scripts run, Phase 1 report written to `local-state/devkit-cron/reports/`, dry-run message printed.

**Step 2: Inspect the Phase 1 report**

Run: `cat claude-code-development-kit/local-state/devkit-cron/reports/*-phase1.json | python3 -m json.tool | head -20`
Expected: Valid JSON with `since`, `date`, `changelog_entries`, `sync_action_required`, `schema_drift`, `changes_found` fields.

**Step 3: Verify install --status (before install)**

Run: `bash claude-code-development-kit/scripts/install-cron.sh --status`
Expected: Shows "Plist not found" and "Agent not loaded" warnings.

**Step 4: Test force mode triggers Phase 2 prompt construction**

Only if you want to burn API tokens. Otherwise, trust the prompt string construction and skip.

Run: `bash claude-code-development-kit/scripts/devkit-cron.sh --force --since 2026-03-08 2>&1 | head -30`
Expected: Phase 1 runs, then "Spawning Claude Code session..." appears. Cancel with Ctrl+C if you don't want to consume tokens.

**Step 5: Install the launchd agent**

Run: `bash claude-code-development-kit/scripts/install-cron.sh`
Expected: "Installed successfully!" with schedule info printed.

**Step 6: Verify installation**

Run: `bash claude-code-development-kit/scripts/install-cron.sh --status`
Expected: Plist installed, agent loaded, last-run date shown.

**Step 7: Final commit**

```bash
git add -A claude-code-development-kit/local-state/
git commit -m "chore(devkit-cron): verify end-to-end pipeline"
```
