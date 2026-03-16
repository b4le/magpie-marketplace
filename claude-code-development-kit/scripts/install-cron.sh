#!/usr/bin/env bash
# =============================================================================
# install-cron.sh
#
# Purpose: Install, uninstall, or show status of the devkit-cron launchd agent
#          (com.magpie.devkit-cron) on macOS.
#
# Usage:
#   ./install-cron.sh [--uninstall | --status | --help]
#
# Exit codes:
#   0  Success
#   1  Error (validation failure, launchctl failure, etc.)
#
# Dependencies:
#   - bash 4.4+ (macOS system bash is 3.x — use homebrew bash or /usr/bin/env bash)
#   - launchctl  (macOS built-in)
#   - plutil     (macOS built-in)
#   - python3    (stdlib only)
#
# Environment:
#   NO_COLOR   Suppress ANSI colour output
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

readonly PLIST_LABEL="com.magpie.devkit-cron"
readonly PLIST_DEST="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"
readonly PLIST_TEMPLATE="${SCRIPT_DIR}/${PLIST_LABEL}.plist"
readonly STATE_DIR="${PLUGIN_ROOT}/local-state/devkit-cron"
readonly REPORTS_DIR="${STATE_DIR}/reports"
readonly LAST_RUN_FILE="${STATE_DIR}/last-run"
readonly DEVKIT_CRON="${SCRIPT_DIR}/devkit-cron.sh"

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
# Logging helpers (all to stderr so stdout stays clean)
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
  Manages the devkit-cron launchd agent (${PLIST_LABEL}) on macOS.
  The default action (no options) is to install and load the agent.

${BOLD}Options:${RESET}
  --uninstall   Unload and remove the launchd agent plist
  --status      Show current agent status (loaded, last-run, reports)
  --help, -h    Show this message and exit

${BOLD}Install behaviour:${RESET}
  1. Validates prerequisites (devkit-cron.sh, plist template)
  2. Creates state directory: ${STATE_DIR}/reports/
  3. Seeds last-run with 7 days ago if not present
  4. Generates plist from template with real paths
  5. Copies plist to ~/Library/LaunchAgents/
  6. Validates plist with plutil -lint
  7. Loads agent with launchctl bootstrap (idempotent)

${BOLD}State files:${RESET}
  ${STATE_DIR}/last-run
  ${STATE_DIR}/reports/
  ${STATE_DIR}/launchd-stdout.log
  ${STATE_DIR}/launchd-stderr.log

${BOLD}Environment:${RESET}
  NO_COLOR   Suppress ANSI colour output

${BOLD}Exit codes:${RESET}
  0  Success
  1  Error
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

ACTION="install"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall)
      ACTION="uninstall"
      shift
      ;;
    --status)
      ACTION="status"
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

# ---------------------------------------------------------------------------
# Install action
# ---------------------------------------------------------------------------

do_install() {
  log_section "Installing ${PLIST_LABEL}"

  # --- 1. Validate prerequisites ---
  log_info "Checking prerequisites ..."

  if ! command -v claude &>/dev/null; then
    log_warn "claude CLI not found in PATH — devkit-cron Phase 2 will fail at runtime"
    log_warn "Install Claude Code: https://claude.ai/code"
  fi

  if [[ ! -f "$DEVKIT_CRON" ]]; then
    log_error "devkit-cron.sh not found: ${DEVKIT_CRON}"
    exit 1
  fi
  log_ok "devkit-cron.sh found"

  if [[ ! -f "$PLIST_TEMPLATE" ]]; then
    log_error "plist template not found: ${PLIST_TEMPLATE}"
    exit 1
  fi
  log_ok "plist template found"

  # --- 2. Create state directories ---
  log_info "Creating state directories ..."
  mkdir -p "$REPORTS_DIR"
  log_ok "State directory ready: ${STATE_DIR}/reports/"

  # --- 3. Seed last-run if not present ---
  if [[ ! -f "$LAST_RUN_FILE" ]]; then
    local seven_days_ago
    seven_days_ago="$(python3 -c 'import datetime; print((datetime.date.today() - datetime.timedelta(days=7)).isoformat())')"
    printf '%s\n' "$seven_days_ago" > "$LAST_RUN_FILE"
    log_info "Seeded last-run with 7 days ago: ${seven_days_ago}"
  else
    log_info "last-run already exists: $(cat "$LAST_RUN_FILE")"
  fi

  # --- 4. Generate plist from template ---
  log_info "Generating plist from template ..."
  local tmp_plist
  tmp_plist="$(mktemp /tmp/com.magpie.devkit-cron.XXXXXX.plist)"
  trap 'rm -f "${tmp_plist}"' EXIT
  # Two-pass sed: replace __PLUGIN_ROOT__ then __STATE_DIR__
  # Use | as delimiter to avoid clashes with / in paths
  # Escape & in replacement values (sed treats & as "matched text")
  local safe_plugin_root safe_state_dir
  safe_plugin_root="${PLUGIN_ROOT//&/\\&}"
  safe_state_dir="${STATE_DIR//&/\\&}"
  sed \
    -e "s|__PLUGIN_ROOT__|${safe_plugin_root}|g" \
    -e "s|__STATE_DIR__|${safe_state_dir}|g" \
    "$PLIST_TEMPLATE" > "$tmp_plist"
  log_ok "Plist generated"

  # --- 5. Copy to LaunchAgents ---
  log_info "Installing plist to ~/Library/LaunchAgents/ ..."
  mkdir -p "${HOME}/Library/LaunchAgents"
  cp "$tmp_plist" "$PLIST_DEST"
  rm -f "$tmp_plist"
  log_ok "Plist installed: ${PLIST_DEST}"

  # --- 6. Validate with plutil ---
  log_info "Validating plist ..."
  if ! plutil -lint "$PLIST_DEST" >/dev/null 2>&1; then
    log_error "plutil -lint failed — plist is malformed"
    plutil -lint "$PLIST_DEST" >&2 || true
    exit 1
  fi
  log_ok "plist is valid"

  # --- 7. Unload first if already loaded (idempotent) ---
  local uid
  uid="$(id -u)"
  if launchctl print "gui/${uid}/${PLIST_LABEL}" &>/dev/null 2>&1; then
    log_info "Agent already loaded — unloading first (idempotent) ..."
    launchctl bootout "gui/${uid}/${PLIST_LABEL}" 2>/dev/null || true
  fi

  # --- 8. Load agent ---
  log_info "Loading agent with launchctl bootstrap ..."
  if launchctl bootstrap "gui/${uid}" "$PLIST_DEST" 2>/dev/null; then
    log_ok "Agent loaded via launchctl bootstrap"
  else
    log_warn "launchctl bootstrap failed — falling back to legacy launchctl load ..."
    if launchctl load "$PLIST_DEST" 2>/dev/null; then
      log_ok "Agent loaded via launchctl load (legacy)"
    else
      log_error "Failed to load agent with both bootstrap and legacy load"
      exit 1
    fi
  fi

  # --- 9. Success message ---
  printf "\n${GREEN}${BOLD}devkit-cron installed successfully.${RESET}\n" >&2
  printf "\n${BOLD}Schedule:${RESET}       Daily at 08:00\n" >&2
  printf "${BOLD}Stdout log:${RESET}     ${STATE_DIR}/launchd-stdout.log\n" >&2
  printf "${BOLD}Stderr log:${RESET}     ${STATE_DIR}/launchd-stderr.log\n" >&2
  printf "${BOLD}Manual run:${RESET}     bash %s\n" "$DEVKIT_CRON" >&2
  printf "${BOLD}Status check:${RESET}   bash %s --status\n" "$0" >&2
  printf "\n" >&2
}

# ---------------------------------------------------------------------------
# Uninstall action
# ---------------------------------------------------------------------------

do_uninstall() {
  log_section "Uninstalling ${PLIST_LABEL}"

  local uid
  uid="$(id -u)"

  # --- 1. Unload agent ---
  if launchctl print "gui/${uid}/${PLIST_LABEL}" &>/dev/null 2>&1; then
    log_info "Unloading agent ..."
    if launchctl bootout "gui/${uid}/${PLIST_LABEL}" 2>/dev/null; then
      log_ok "Agent unloaded via launchctl bootout"
    else
      log_warn "launchctl bootout failed — falling back to legacy launchctl unload ..."
      if [[ -f "$PLIST_DEST" ]]; then
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
        log_ok "Agent unloaded via launchctl unload (legacy)"
      fi
    fi
  else
    log_info "Agent is not currently loaded — nothing to unload"
  fi

  # --- 2. Remove plist ---
  if [[ -f "$PLIST_DEST" ]]; then
    rm -f "$PLIST_DEST"
    log_ok "Plist removed: ${PLIST_DEST}"
  else
    log_info "Plist not found at ${PLIST_DEST} — already removed"
  fi

  printf "\n${GREEN}${BOLD}devkit-cron uninstalled.${RESET}\n" >&2
  printf "${DIM}State files preserved at: ${STATE_DIR}${RESET}\n" >&2
  printf "\n" >&2
}

# ---------------------------------------------------------------------------
# Status action
# ---------------------------------------------------------------------------

do_status() {
  log_section "Status: ${PLIST_LABEL}"

  local uid
  uid="$(id -u)"

  # --- 1. Check plist on disk ---
  if [[ -f "$PLIST_DEST" ]]; then
    log_ok "Plist installed: ${PLIST_DEST}"
  else
    log_warn "Plist NOT installed (${PLIST_DEST} not found)"
  fi

  # --- 2. Check if loaded in launchd ---
  if launchctl print "gui/${uid}/${PLIST_LABEL}" &>/dev/null 2>&1; then
    log_ok "Agent is LOADED in launchd"
  else
    log_warn "Agent is NOT loaded in launchd"
  fi

  # --- 3. Last-run date ---
  if [[ -f "$LAST_RUN_FILE" ]]; then
    local last_run
    last_run="$(tr -d '[:space:]' < "$LAST_RUN_FILE")"
    log_info "Last run:       ${last_run}"
  else
    log_info "Last run:       (never — last-run file not present)"
  fi

  # --- 4. Report count ---
  local report_count=0
  if [[ -d "$REPORTS_DIR" ]]; then
    report_count="$(find "$REPORTS_DIR" -maxdepth 1 -type f \( -name '*.json' -o -name '*.md' \) 2>/dev/null | wc -l | tr -d ' ')"
  fi
  log_info "Reports on disk: ${report_count} (in ${REPORTS_DIR})"

  # --- 5. Log file sizes ---
  local stdout_log="${STATE_DIR}/launchd-stdout.log"
  local stderr_log="${STATE_DIR}/launchd-stderr.log"
  if [[ -f "$stdout_log" ]]; then
    log_info "Stdout log:     ${stdout_log}"
  else
    log_info "Stdout log:     (not yet created)"
  fi
  if [[ -f "$stderr_log" ]]; then
    log_info "Stderr log:     ${stderr_log}"
  else
    log_info "Stderr log:     (not yet created)"
  fi

  printf "\n" >&2
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "$ACTION" in
  install)   do_install   ;;
  uninstall) do_uninstall ;;
  status)    do_status    ;;
esac
