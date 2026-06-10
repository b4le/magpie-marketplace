#!/bin/bash
# validate-scripts.sh — Shell script safety and quality validator for the archaeology plugin.
#
# Checks all 4 scripts in archaeology/scripts/ for:
#   existence, executability, shebang, safety practices, ShellCheck,
#   hardcoded personal paths, Bash 3.2 bashisms, variable quoting,
#   explicit exit codes, and development markers (TODO/FIXME/HACK).
#
# Usage:  ./evals/validate-scripts.sh [--help]
# Exit:   0 = all checks pass (warnings possible), 1 = one or more errors

set -e

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── State ────────────────────────────────────────────────────────────────────
ERRORS=()
WARNINGS=()

# ── Derive paths from script location ────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPTS_DIR="${PLUGIN_ROOT}/scripts"

# ── Expected scripts ─────────────────────────────────────────────────────────
# Bash 3.2 compat: indexed array, not associative
EXPECTED_SCRIPTS=(
  "archaeology-excavation.sh"
  "validate-domains.sh"
  "check-registry-sync.sh"
  "validate-conserve.sh"
)

# ── Logging helpers ───────────────────────────────────────────────────────────
log_error() {
  ERRORS+=("$1")
  printf "${RED}[ERROR]${NC} %s\n" "$1"
}

log_warning() {
  WARNINGS+=("$1")
  printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

log_success() {
  printf "${GREEN}[PASS]${NC} %s\n" "$1"
}

log_info() {
  printf "[INFO] %s\n" "$1"
}

log_section() {
  printf "\n${BLUE}=== %s ===${NC}\n" "$1"
}

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
  cat <<'EOF'
validate-scripts.sh — Shell script safety and quality validator

USAGE:
    ./evals/validate-scripts.sh
    ./evals/validate-scripts.sh --help

DESCRIPTION:
    Validates all 4 shell scripts in archaeology/scripts/ against a suite of
    safety, correctness, and portability checks. The script itself is Bash 3.2
    compatible so it runs on the macOS default shell without modification.

CHECKS:
    1. Existence       — All 4 expected scripts are present in scripts/
    2. Executability   — Each script has +x permission
    3. Shebang         — #!/bin/bash or #!/usr/bin/env bash
    4. Safety          — Uses set -e or set -euo pipefail
    5. ShellCheck      — Static analysis (errors only; skipped if not installed)
    6. Personal paths  — No /Users/<name> or /home/<name> hardcoded paths
    7. Bash 3.2 compat — No declare -A, |&, ${var,,}, ${var^^}, readarray/mapfile
    8. Variable quoting — Unquoted $VAR after rm, in [ ] tests, or in loops
    9. Exit codes      — Explicit exit 0 or exit 1 present
   10. Dev markers     — No TODO, FIXME, or HACK comments

EXIT CODES:
    0    All checks pass (warnings may be present)
    1    One or more errors found

EXAMPLES:
    cd archaeology && ./evals/validate-scripts.sh
    bash evals/validate-scripts.sh
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_help
  exit 0
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo "=========================================="
echo "Archaeology Scripts Validator"
echo "Plugin root: ${PLUGIN_ROOT}"
echo "=========================================="

# ── Section 1: Existence ──────────────────────────────────────────────────────
log_section "1. Script Existence"

if [[ ! -d "${SCRIPTS_DIR}" ]]; then
  log_error "scripts/ directory not found at: ${SCRIPTS_DIR}"
  echo ""
  echo "=========================================="
  echo "SCRIPTS: FAILED"
  echo "=========================================="
  echo "Cannot continue — scripts/ directory missing."
  exit 1
fi

log_info "scripts/ directory found: ${SCRIPTS_DIR}"

MISSING_SCRIPTS=()
for script_name in "${EXPECTED_SCRIPTS[@]}"; do
  script_path="${SCRIPTS_DIR}/${script_name}"
  if [[ -f "${script_path}" ]]; then
    log_success "${script_name} exists"
  else
    log_error "${script_name} not found in scripts/"
    MISSING_SCRIPTS+=("${script_name}")
  fi
done

# ── Section 2: Executability ──────────────────────────────────────────────────
log_section "2. Executability (+x permission)"

for script_name in "${EXPECTED_SCRIPTS[@]}"; do
  script_path="${SCRIPTS_DIR}/${script_name}"
  [[ ! -f "${script_path}" ]] && continue  # already flagged as missing

  if [[ -x "${script_path}" ]]; then
    log_success "${script_name} is executable"
  else
    log_error "${script_name} is not executable (missing +x)"
  fi
done

# ── Section 3: Shebang ───────────────────────────────────────────────────────
log_section "3. Shebang Line"

for script_name in "${EXPECTED_SCRIPTS[@]}"; do
  script_path="${SCRIPTS_DIR}/${script_name}"
  [[ ! -f "${script_path}" ]] && continue

  # Read only the first line for efficiency
  first_line=$(head -1 "${script_path}")

  case "${first_line}" in
    "#!/bin/bash"|"#!/usr/bin/env bash")
      log_success "${script_name}: shebang '${first_line}'"
      ;;
    \#!*)
      log_error "${script_name}: unexpected shebang '${first_line}' (expected #!/bin/bash or #!/usr/bin/env bash)"
      ;;
    *)
      log_error "${script_name}: no shebang line found"
      ;;
  esac
done

# ── Section 4: Safety Practices ──────────────────────────────────────────────
# NOTE: Claude Code does not itself require scripts to use set -e.  These
# scripts are invoked by the skill via the Bash tool at runtime.  However,
# because several of them are validators that report pass/fail via exit code,
# set -e is a best-practice enforcement to prevent silent failures from
# masking real issues.  Treated as an error to maintain script reliability.
log_section "4. Safety Practices (set -e / set -euo pipefail)"

for script_name in "${EXPECTED_SCRIPTS[@]}"; do
  script_path="${SCRIPTS_DIR}/${script_name}"
  [[ ! -f "${script_path}" ]] && continue

  # Accept any set invocation that includes -e (covers -e, -eu, -euo, -euo pipefail, etc.)
  if grep -qE '^[[:space:]]*set[[:space:]]+-[a-zA-Z]*e' "${script_path}"; then
    # Distinguish minimal -e from recommended -euo pipefail
    if grep -qE '^[[:space:]]*set[[:space:]]+-[a-zA-Z]*e[a-zA-Z]*[[:space:]]+pipefail|^[[:space:]]*set[[:space:]]+-[a-zA-Z]*e[a-zA-Z]*o[[:space:]]+pipefail' "${script_path}"; then
      log_success "${script_name}: uses set -euo pipefail"
    else
      log_success "${script_name}: uses set -e"
      log_warning "${script_name}: only 'set -e' found; 'set -euo pipefail' is recommended"
    fi
  else
    log_error "${script_name}: no 'set -e' or 'set -euo pipefail' found"
  fi
done

# ── Section 5: ShellCheck ─────────────────────────────────────────────────────
log_section "5. ShellCheck Static Analysis"

if ! command -v shellcheck >/dev/null 2>&1; then
  log_warning "shellcheck not installed — skipping static analysis (install via: brew install shellcheck)"
else
  SHELLCHECK_VERSION=$(shellcheck --version 2>/dev/null | grep "^version:" | awk '{print $2}' || printf "unknown")
  log_info "shellcheck version: ${SHELLCHECK_VERSION}"

  for script_name in "${EXPECTED_SCRIPTS[@]}"; do
    script_path="${SCRIPTS_DIR}/${script_name}"
    [[ ! -f "${script_path}" ]] && continue

    # Run shellcheck; capture output; only treat SC errors (not warnings SC2xxx style notes)
    # --severity=error: only report errors, not warnings/info/style
    sc_output=""
    sc_exit=0
    sc_output=$(shellcheck --severity=error --shell=bash "${script_path}" 2>&1) || sc_exit=$?

    if [[ ${sc_exit} -eq 0 ]]; then
      log_success "${script_name}: shellcheck (errors only) passed"
    else
      log_error "${script_name}: shellcheck found errors"
      # Indent and emit each error line
      while IFS= read -r sc_line; do
        [[ -z "${sc_line}" ]] && continue
        printf "    %s\n" "${sc_line}"
      done <<< "${sc_output}"
    fi

    # Also run at warning level and report as warnings (not errors)
    sc_warn_output=""
    sc_warn_exit=0
    sc_warn_output=$(shellcheck --severity=warning --shell=bash "${script_path}" 2>&1) || sc_warn_exit=$?

    if [[ ${sc_warn_exit} -ne 0 && -n "${sc_warn_output}" ]]; then
      warn_count=$(printf '%s\n' "${sc_warn_output}" | grep -c "^In " || true)
      log_warning "${script_name}: shellcheck found ${warn_count} warning(s) (not failing)"
    fi
  done
fi

# ── Section 6: Hardcoded Personal Paths ──────────────────────────────────────
log_section "6. Hardcoded Personal Paths"

# Pattern matches /Users/<any-word> or /home/<any-word> but excludes
# generic placeholder words that appear in examples or documentation.
GENERIC_NAMES="username|user|yourname|you|example|dev|name|someone|person"

for script_name in "${EXPECTED_SCRIPTS[@]}"; do
  script_path="${SCRIPTS_DIR}/${script_name}"
  [[ ! -f "${script_path}" ]] && continue

  # Extract matching lines, then filter out generic placeholders
  personal_lines=""
  while IFS= read -r match_line; do
    [[ -z "${match_line}" ]] && continue
    # Skip lines that only contain generic placeholder names
    if printf '%s' "${match_line}" | grep -qE "/Users/(${GENERIC_NAMES})|/home/(${GENERIC_NAMES})"; then
      continue
    fi
    personal_lines="${personal_lines}${match_line}"$'\n'
  done < <(grep -nE '/Users/[a-zA-Z][a-zA-Z0-9._-]+|/home/[a-zA-Z][a-zA-Z0-9._-]+' "${script_path}" 2>/dev/null || true)

  if [[ -n "${personal_lines}" ]]; then
    log_error "${script_name}: hardcoded personal path(s) found"
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      printf "    %s\n" "${line}"
    done <<< "${personal_lines}"
  else
    log_success "${script_name}: no hardcoded personal paths"
  fi
done

# ── Section 7: Bash 3.2 Compatibility ────────────────────────────────────────
log_section "7. Bash 3.2 Compatibility (macOS default shell)"

# Each entry: "PATTERN|DESCRIPTION"
# Patterns use grep -E on the script source text.
# Bash 3.2 bashisms that break on macOS default bash:
#
# declare -A           associative arrays (bash 4+)
# |&                   pipe stderr+stdout (bash 4+)
# ${var,,} ${var^^}    case modification (bash 4+)
# readarray / mapfile  array from stream  (bash 4+)
#
# Each check uses a tight pattern to avoid false positives on comments.

check_bashism() {
  local script_name="$1"
  local script_path="$2"
  local pattern="$3"
  local description="$4"

  local matched_lines
  matched_lines=""

  # Skip lines that are pure comments (leading #)
  while IFS= read -r match_line; do
    [[ -z "${match_line}" ]] && continue
    # Strip leading whitespace then check for comment marker
    trimmed="${match_line#"${match_line%%[! ]*}"}"
    case "${trimmed}" in
      \#*) continue ;;  # pure comment line — skip
    esac
    matched_lines="${matched_lines}${match_line}"$'\n'
  done < <(grep -nE "${pattern}" "${script_path}" 2>/dev/null || true)

  if [[ -n "${matched_lines}" ]]; then
    log_error "${script_name}: Bash 4+ feature '${description}' found (breaks on Bash 3.2)"
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      printf "    %s\n" "${line}"
    done <<< "${matched_lines}"
    return 1
  fi
  return 0
}

for script_name in "${EXPECTED_SCRIPTS[@]}"; do
  script_path="${SCRIPTS_DIR}/${script_name}"
  [[ ! -f "${script_path}" ]] && continue

  script_clean=true

  # declare -A (associative arrays)
  check_bashism "${script_name}" "${script_path}" \
    'declare[[:space:]]+-[a-zA-Z]*A' \
    'declare -A (associative arrays)' || script_clean=false

  # |& (pipe stderr + stdout, bash 4+)
  check_bashism "${script_name}" "${script_path}" \
    '[|][&]' \
    '|& (pipe-both operator)' || script_clean=false

  # ${var,,} or ${var^^} (case modification)
  check_bashism "${script_name}" "${script_path}" \
    '\$\{[a-zA-Z_][a-zA-Z0-9_]*([,][,]|[\^][\^])' \
    '${var,,} or ${var^^} (case modification)' || script_clean=false

  # readarray or mapfile
  check_bashism "${script_name}" "${script_path}" \
    '^[[:space:]]*(readarray|mapfile)[[:space:]]' \
    'readarray / mapfile' || script_clean=false

  # [[ ... =~ ... ]] with regex stored in a variable (unreliable in 3.2)
  # Pattern: =~ $varname inside [[ ]] — stored regex variable
  check_bashism "${script_name}" "${script_path}" \
    '\[\[.*=~[[:space:]]+\$[a-zA-Z_]' \
    '[[ =~ $regex_var ]] (stored regex unreliable in 3.2)' || script_clean=false

  if [[ "${script_clean}" == true ]]; then
    log_success "${script_name}: no Bash 4+ bashisms found"
  fi
done

# ── Section 8: Variable Quoting ───────────────────────────────────────────────
log_section "8. Variable Quoting (dangerous positions)"

# Check for unquoted variable expansions in high-risk positions:
#   rm $VAR        — could expand to multiple args or empty
#   [ $VAR ... ]   — classic unquoted test variable
#   for x in $VAR  — word-splits on IFS

for script_name in "${EXPECTED_SCRIPTS[@]}"; do
  script_path="${SCRIPTS_DIR}/${script_name}"
  [[ ! -f "${script_path}" ]] && continue

  script_has_issues=false

  # rm with unquoted variable (rm $VAR or rm -rf $VAR, not rm "$VAR")
  rm_issues=""
  while IFS= read -r match_line; do
    [[ -z "${match_line}" ]] && continue
    trimmed="${match_line#"${match_line%%[! ]*}"}"
    case "${trimmed}" in \#*) continue ;; esac
    rm_issues="${rm_issues}${match_line}"$'\n'
  done < <(grep -nE '[[:space:]]rm[[:space:]]+(--[[:space:]]+)?\$[^({"'"'"']|[[:space:]]rm[[:space:]]+-[a-z]+[[:space:]]+\$[^({"'"'"']' \
    "${script_path}" 2>/dev/null || true)

  if [[ -n "${rm_issues}" ]]; then
    log_warning "${script_name}: possible unquoted variable after 'rm'"
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      printf "    %s\n" "${line}"
    done <<< "${rm_issues}"
    script_has_issues=true
  fi

  # [ $VAR ] test — unquoted variable in POSIX single-bracket tests only.
  # [[ ]] handles unquoted integers safely; only flag single [ ] usage.
  # Match lines where [ is not immediately preceded by another [ .
  bracket_issues=""
  while IFS= read -r match_line; do
    [[ -z "${match_line}" ]] && continue
    trimmed="${match_line#"${match_line%%[! ]*}"}"
    case "${trimmed}" in \#*) continue ;; esac
    # Skip lines that contain [[ (double-bracket — quoting not required)
    if printf '%s' "${match_line}" | grep -qE '\[\['; then
      continue
    fi
    bracket_issues="${bracket_issues}${match_line}"$'\n'
  done < <(grep -nE '\[[[:space:]]+\$[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]' \
    "${script_path}" 2>/dev/null || true)

  if [[ -n "${bracket_issues}" ]]; then
    log_warning "${script_name}: possible unquoted variable in [ ] test"
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      printf "    %s\n" "${line}"
    done <<< "${bracket_issues}"
    script_has_issues=true
  fi

  # for x in $VAR — word-splits on IFS (unquoted variable in for..in)
  # Honor shellcheck disable=SC2086 directives on the preceding line — when
  # the author has explicitly marked the word-split as intentional, suppress
  # the warning.
  for_issues=""
  while IFS= read -r match_line; do
    [[ -z "${match_line}" ]] && continue
    trimmed="${match_line#"${match_line%%[! ]*}"}"
    case "${trimmed}" in \#*) continue ;; esac

    # Extract line number from the grep -n output (format: "LINENO:content")
    match_lineno="${match_line%%:*}"
    if [[ "${match_lineno}" =~ ^[0-9]+$ ]] && [[ "${match_lineno}" -gt 1 ]]; then
      prev_lineno=$((match_lineno - 1))
      prev_line=$(sed -n "${prev_lineno}p" "${script_path}")
      # Skip if preceding line has shellcheck disable=SC2086 (intentional word-split)
      if printf '%s' "${prev_line}" | grep -qE 'shellcheck[[:space:]]+disable=.*SC2086'; then
        continue
      fi
    fi

    for_issues="${for_issues}${match_line}"$'\n'
  done < <(grep -nE 'for[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+in[[:space:]]+\$[a-zA-Z_][a-zA-Z0-9_]*([[:space:]]|;|$)' \
    "${script_path}" 2>/dev/null || true)

  if [[ -n "${for_issues}" ]]; then
    log_warning "${script_name}: unquoted variable in 'for x in \$VAR' (word-splits)"
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      printf "    %s\n" "${line}"
    done <<< "${for_issues}"
    script_has_issues=true
  fi

  if [[ "${script_has_issues}" == false ]]; then
    log_success "${script_name}: no obvious variable quoting issues found"
  fi
done

# ── Section 9: Explicit Exit Codes ───────────────────────────────────────────
log_section "9. Explicit Exit Codes"

for script_name in "${EXPECTED_SCRIPTS[@]}"; do
  script_path="${SCRIPTS_DIR}/${script_name}"
  [[ ! -f "${script_path}" ]] && continue

  has_exit_0=false
  has_exit_1=false

  if grep -qE '^[[:space:]]*exit[[:space:]]+0([[:space:]]|$)' "${script_path}"; then
    has_exit_0=true
  fi
  if grep -qE '^[[:space:]]*exit[[:space:]]+1([[:space:]]|$)|\[\[? .*-gt 0.*\]\]? && exit 1|exit \$\?' "${script_path}"; then
    has_exit_1=true
  fi

  if [[ "${has_exit_0}" == true && "${has_exit_1}" == true ]]; then
    log_success "${script_name}: explicit exit 0 and exit 1 both present"
  elif [[ "${has_exit_0}" == true ]]; then
    log_warning "${script_name}: explicit exit 0 found but no explicit exit 1 (relies on implicit non-zero)"
  elif [[ "${has_exit_1}" == true ]]; then
    log_warning "${script_name}: explicit exit 1 found but no explicit exit 0 (relies on implicit zero)"
  else
    log_error "${script_name}: no explicit exit 0 or exit 1 found"
  fi
done

# ── Section 10: Development Markers ──────────────────────────────────────────
log_section "10. Development Markers (TODO / FIXME / HACK)"

for script_name in "${EXPECTED_SCRIPTS[@]}"; do
  script_path="${SCRIPTS_DIR}/${script_name}"
  [[ ! -f "${script_path}" ]] && continue

  marker_lines=""
  while IFS= read -r match_line; do
    [[ -z "${match_line}" ]] && continue
    marker_lines="${marker_lines}${match_line}"$'\n'
  done < <(grep -niE '[[:space:]#](TODO|FIXME|HACK)[[:space:]:!]' "${script_path}" 2>/dev/null || true)

  if [[ -n "${marker_lines}" ]]; then
    log_warning "${script_name}: development markers found"
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      printf "    %s\n" "${line}"
    done <<< "${marker_lines}"
  else
    log_success "${script_name}: no TODO/FIXME/HACK markers"
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "VALIDATION SUMMARY"
echo "=========================================="
echo "Plugin:   ${PLUGIN_ROOT}"
echo "Scripts:  ${SCRIPTS_DIR}"
echo ""
printf "Errors:   %d\n" "${#ERRORS[@]}"
printf "Warnings: %d\n" "${#WARNINGS[@]}"
echo ""

TOTAL_ERRORS=${#ERRORS[@]}

if [[ ${TOTAL_ERRORS} -gt 0 ]]; then
  printf "${RED}SCRIPTS: FAILED${NC}\n"
  echo ""
  echo "Errors:"
  for error in "${ERRORS[@]}"; do
    printf "  - %s\n" "${error}"
  done

  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "Warnings:"
    for warning in "${WARNINGS[@]}"; do
      printf "  - %s\n" "${warning}"
    done
  fi
  exit 1
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  printf "${YELLOW}SCRIPTS: PASSED WITH WARNINGS${NC}\n"
  echo ""
  echo "Warnings:"
  for warning in "${WARNINGS[@]}"; do
    printf "  - %s\n" "${warning}"
  done
else
  printf "${GREEN}SCRIPTS: PASSED${NC}\n"
fi

exit 0
