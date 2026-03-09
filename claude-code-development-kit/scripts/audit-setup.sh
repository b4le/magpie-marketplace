#!/usr/bin/env bash
# =============================================================================
# audit-setup.sh
#
# Purpose: Audit the ~/.claude/ directory for common maintenance issues:
#          disk usage anomalies, empty todo files, disabled plugins, stale
#          teams, and settings files that may contain secrets.
#
# Usage:
#   ./audit-setup.sh [--json] [--claude-dir PATH] [--help]
#
# Exit codes:
#   0  Audit complete — no HIGH-severity findings
#   1  Audit complete — one or more HIGH-severity findings detected
#   2  Argument / validation error
#   3  Missing dependency
#
# Dependencies:
#   - find, du, stat (POSIX / macOS / GNU Linux)
#   - python3  (stdlib only — for JSON output and date arithmetic)
#
# Environment:
#   NO_COLOR   Set to any non-empty value to suppress ANSI colour output
#   CLAUDE_DIR Override the scanned directory (default: ~/.claude)
# =============================================================================

set -Eeuo pipefail
# inherit_errexit propagates ERR traps into subshells — requires Bash 4.4+
if (( BASH_VERSINFO[0] > 4 || ( BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4 ) )); then
  shopt -s inherit_errexit
fi

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_NAME="$(basename -- "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME
readonly STALE_DAYS=30
readonly EMPTY_FILE_BYTES=4        # files smaller than this are "empty"
readonly SECRET_PATTERNS=(
  'token'
  'secret'
  'password'
  'api_key'
  'apikey'
  'private_key'
  'client_secret'
  'access_key'
  'auth_token'
)

# ---------------------------------------------------------------------------
# Colour helpers (respect NO_COLOR and non-interactive output)
# ---------------------------------------------------------------------------

if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BOLD='' DIM='' RESET=''
fi

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

log_info()  { printf "${DIM}[info]${RESET}  %s\n" "$*" >&2; }
log_warn()  { printf "${YELLOW}[warn]${RESET}  %s\n" "$*" >&2; }
log_error() { printf "${RED}[error]${RESET} %s\n" "$*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}Usage:${RESET}
  ${SCRIPT_NAME} [OPTIONS]

${BOLD}Description:${RESET}
  Scans the ~/.claude/ directory and reports potential maintenance issues,
  each tagged with a severity level (HIGH / MEDIUM / LOW).

  Checks performed:
    • Disk usage by subdirectory
    • Empty todo files (< ${EMPTY_FILE_BYTES} bytes)
    • Disabled plugins
    • Stale teams (not modified in > ${STALE_DAYS} days)
    • Settings / config files containing potential secret patterns

${BOLD}Options:${RESET}
  --json              Emit findings as a JSON array instead of human-readable text
  --claude-dir PATH   Override the directory to scan (default: ~/.claude)
  --help, -h          Show this message and exit

${BOLD}Environment:${RESET}
  NO_COLOR    Suppress ANSI colour output
  CLAUDE_DIR  Equivalent to --claude-dir

${BOLD}Exit codes:${RESET}
  0  Audit complete — no HIGH-severity findings
  1  Audit complete — one or more HIGH-severity findings detected
  2  Argument / validation error
  3  Missing dependency
EOF
}

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

check_deps() {
  local -a missing=()
  local cmd
  for cmd in find du python3; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ "${#missing[@]}" -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    exit 3
  fi
}

# ---------------------------------------------------------------------------
# Portable last-modification time in seconds-since-epoch
# Works on macOS (BSD stat) and GNU/Linux
# ---------------------------------------------------------------------------

file_mtime_epoch() {
  local path="$1"
  if stat --version &>/dev/null 2>&1; then
    # GNU stat
    stat --format='%Y' -- "$path" 2>/dev/null || printf '0'
  else
    # BSD/macOS stat
    stat -f '%m' -- "$path" 2>/dev/null || printf '0'
  fi
}

# ---------------------------------------------------------------------------
# Check: disk usage by first-level subdirectory
# Appends findings to the shared arrays FINDINGS / SEVERITIES / CATEGORIES
# ---------------------------------------------------------------------------

check_disk_usage() {
  local claude_dir="$1"
  log_info "Checking disk usage ..."

  local usage_output
  # du -sh on each subdir — avoid globbing hidden-dir issues with find
  while IFS= read -r -d '' subdir; do
    local size
    size="$(du -sh -- "$subdir" 2>/dev/null | awk '{print $1}')"
    local size_bytes
    size_bytes="$(du -sk -- "$subdir" 2>/dev/null | awk '{print $1}')"
    local severity="LOW"
    # Flag subdirs consuming >500 MB as MEDIUM, >1 GB as HIGH
    if [[ "$size_bytes" -gt 1048576 ]]; then
      severity="HIGH"
    elif [[ "$size_bytes" -gt 512000 ]]; then
      severity="MEDIUM"
    fi
    local label
    label="$(basename -- "$subdir")"
    FINDINGS+=("Subdirectory '${label}' uses ${size} of disk space")
    SEVERITIES+=("$severity")
    CATEGORIES+=("disk-usage")
  done < <(find "$claude_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
}

# ---------------------------------------------------------------------------
# Check: empty todo files
# ---------------------------------------------------------------------------

check_empty_todos() {
  local claude_dir="$1"
  log_info "Checking for empty todo files ..."

  local count=0
  while IFS= read -r -d '' f; do
    (( count++ )) || true
  done < <(find "$claude_dir" -maxdepth 3 \
             \( -name 'todos.md' -o -name 'todo.md' -o -name 'TODO.md' \) \
             -size "-${EMPTY_FILE_BYTES}c" -print0 2>/dev/null)

  if [[ "$count" -gt 0 ]]; then
    FINDINGS+=("${count} empty or near-empty todo file(s) found (< ${EMPTY_FILE_BYTES} bytes)")
    SEVERITIES+=("LOW")
    CATEGORIES+=("empty-todos")
  fi
}

# ---------------------------------------------------------------------------
# Check: disabled plugins
# ---------------------------------------------------------------------------

check_disabled_plugins() {
  local claude_dir="$1"
  log_info "Checking for disabled plugins ..."

  local disabled_dir="${claude_dir}/plugins/disabled"
  if [[ ! -d "$disabled_dir" ]]; then
    return 0
  fi

  local count=0
  while IFS= read -r -d '' f; do
    (( count++ )) || true
  done < <(find "$disabled_dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

  if [[ "$count" -gt 0 ]]; then
    FINDINGS+=("${count} disabled plugin(s) in ${disabled_dir}")
    SEVERITIES+=("LOW")
    CATEGORIES+=("disabled-plugins")
  fi
}

# ---------------------------------------------------------------------------
# Check: stale teams
# ---------------------------------------------------------------------------

check_stale_teams() {
  local claude_dir="$1"
  log_info "Checking for stale teams (>${STALE_DAYS} days) ..."

  local teams_dir="${claude_dir}/teams"
  if [[ ! -d "$teams_dir" ]]; then
    return 0
  fi

  local now_epoch
  now_epoch="$(python3 -c 'import time; print(int(time.time()))')"
  local stale_threshold=$(( now_epoch - STALE_DAYS * 86400 ))

  local count=0
  local stale_names=()
  while IFS= read -r -d '' team_dir; do
    local mtime
    mtime="$(file_mtime_epoch "$team_dir")"
    if [[ "$mtime" -lt "$stale_threshold" ]]; then
      (( count++ )) || true
      stale_names+=("$(basename -- "$team_dir")")
    fi
  done < <(find "$teams_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

  if [[ "$count" -gt 0 ]]; then
    local names_str
    names_str="$(printf '%s, ' "${stale_names[@]}")"
    names_str="${names_str%, }"
    FINDINGS+=("${count} stale team(s) not modified in >${STALE_DAYS} days: ${names_str}")
    SEVERITIES+=("MEDIUM")
    CATEGORIES+=("stale-teams")
  fi
}

# ---------------------------------------------------------------------------
# Check: settings files with potential secrets
# Looks for key=value or "key": "value" patterns matching common secret names
# ---------------------------------------------------------------------------

check_secret_patterns() {
  local claude_dir="$1"
  log_info "Checking settings files for potential secrets ..."

  # Build a grep pattern from the array
  local pattern
  pattern="$(printf '%s|' "${SECRET_PATTERNS[@]}")"
  pattern="${pattern%|}"  # trim trailing pipe

  local -a flagged_files=()
  while IFS= read -r -d '' settings_file; do
    # Case-insensitive search; only flag if a likely assignment is present
    if grep -qiE "(${pattern})\s*[:=]" -- "$settings_file" 2>/dev/null; then
      flagged_files+=("$settings_file")
    fi
  done < <(find "$claude_dir" -maxdepth 4 \
             \( -name 'settings.json' -o -name 'settings.local.json' \
                -o -name '.env' -o -name '*.env' \) \
             -print0 2>/dev/null)

  if [[ "${#flagged_files[@]}" -gt 0 ]]; then
    for f in "${flagged_files[@]}"; do
      local rel="${f#"${claude_dir}/"}"
      FINDINGS+=("Possible secret in settings file: ${rel}")
      SEVERITIES+=("HIGH")
      CATEGORIES+=("potential-secrets")
    done
  fi
}

# ---------------------------------------------------------------------------
# Map a severity label to its ANSI colour escape
# ---------------------------------------------------------------------------

sev_colour_for() {
  case "$1" in
    HIGH)   printf '%s' "$RED"    ;;
    MEDIUM) printf '%s' "$YELLOW" ;;
    LOW)    printf '%s' "$GREEN"  ;;
    *)      printf '%s' ""        ;;
  esac
}

# ---------------------------------------------------------------------------
# Emit findings as plain text, sorted by severity (HIGH first)
# ---------------------------------------------------------------------------

emit_text() {
  local claude_dir="$1"
  local high_count=0

  printf "${BOLD}Claude setup audit${RESET} — scanning %s\n\n" "$claude_dir"

  # Print in severity order: HIGH → MEDIUM → LOW
  # Use case statement instead of associative array for Bash 3.2 compat
  local order=("HIGH" "MEDIUM" "LOW")
  local sev
  for sev in "${order[@]}"; do
    local i
    for (( i=0; i<${#FINDINGS[@]}; i++ )); do
      if [[ "${SEVERITIES[$i]}" == "$sev" ]]; then
        local colour
        colour="$(sev_colour_for "$sev")"
        printf "  ${colour}%-6s${RESET}  [%s]  %s\n" \
          "$sev" "${CATEGORIES[$i]}" "${FINDINGS[$i]}"
        if [[ "$sev" == "HIGH" ]]; then
          (( high_count++ )) || true
        fi
      fi
    done
  done

  printf "\n%d finding(s) total.\n" "${#FINDINGS[@]}"

  if [[ "$high_count" -gt 0 ]]; then
    printf "${RED}%d HIGH-severity finding(s) require attention.${RESET}\n" "$high_count"
    return 1
  else
    printf "${GREEN}No HIGH-severity findings.${RESET}\n"
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Emit findings as JSON
# ---------------------------------------------------------------------------

emit_json() {
  python3 - <<'PYEOF'
import sys, json

# Arguments arrive as flat triplets encoded separately — reconstruct from globals
# passed in via environment variables
import os

findings_raw   = [x for x in os.environ.get("_FINDINGS",    "").split("\x1f") if x]
severities_raw = [x for x in os.environ.get("_SEVERITIES",  "").split("\x1f") if x]
categories_raw = [x for x in os.environ.get("_CATEGORIES",  "").split("\x1f") if x]
claude_dir     = os.environ.get("_CLAUDE_DIR",  "")

output = {
    "claude_dir": claude_dir,
    "finding_count": len(findings_raw),
    "high_count": sum(1 for s in severities_raw if s == "HIGH"),
    "findings": [
        {
            "severity": severities_raw[i] if i < len(severities_raw) else "UNKNOWN",
            "category": categories_raw[i] if i < len(categories_raw) else "unknown",
            "message":  findings_raw[i],
        }
        for i in range(len(findings_raw))
    ]
}
print(json.dumps(output, indent=2))
PYEOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

JSON_MODE=false
CLAUDE_DIR="${CLAUDE_DIR:-${HOME}/.claude}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_MODE=true
      shift
      ;;
    --claude-dir)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        log_error "--claude-dir requires a PATH argument"
        usage >&2
        exit 2
      fi
      CLAUDE_DIR="$2"
      shift 2
      ;;
    --claude-dir=*)
      CLAUDE_DIR="${1#*=}"
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
      exit 2
      ;;
  esac
done

# Validate the target directory exists
if [[ ! -d "$CLAUDE_DIR" ]]; then
  log_error "Directory does not exist: ${CLAUDE_DIR}"
  exit 2
fi

check_deps

# ---------------------------------------------------------------------------
# Shared result arrays (populated by each check_ function)
# ---------------------------------------------------------------------------

FINDINGS=()
SEVERITIES=()
CATEGORIES=()

# ---------------------------------------------------------------------------
# Run all checks
# ---------------------------------------------------------------------------

check_disk_usage      "$CLAUDE_DIR"
check_empty_todos     "$CLAUDE_DIR"
check_disabled_plugins "$CLAUDE_DIR"
check_stale_teams     "$CLAUDE_DIR"
check_secret_patterns "$CLAUDE_DIR"

# ---------------------------------------------------------------------------
# Emit results
# ---------------------------------------------------------------------------

if [[ "$JSON_MODE" == "true" ]]; then
  # Pass arrays to python3 via env vars using record-separator (\x1f)
  sep=$'\x1f'
  _FINDINGS="$(printf "%s${sep}" "${FINDINGS[@]+"${FINDINGS[@]}"}")"
  _SEVERITIES="$(printf "%s${sep}" "${SEVERITIES[@]+"${SEVERITIES[@]}"}")"
  _CATEGORIES="$(printf "%s${sep}" "${CATEGORIES[@]+"${CATEGORIES[@]}"}")"
  _FINDINGS="${_FINDINGS%"${sep}"}"
  _SEVERITIES="${_SEVERITIES%"${sep}"}"
  _CATEGORIES="${_CATEGORIES%"${sep}"}"

  export _FINDINGS _SEVERITIES _CATEGORIES
  export _CLAUDE_DIR="$CLAUDE_DIR"
  emit_json
  # Exit 1 if any HIGH findings
  high=0
  for s in "${SEVERITIES[@]+"${SEVERITIES[@]}"}"; do
    [[ "$s" == "HIGH" ]] && (( high++ )) || true
  done
  [[ "$high" -eq 0 ]] && exit 0 || exit 1
else
  emit_text "$CLAUDE_DIR"
fi
