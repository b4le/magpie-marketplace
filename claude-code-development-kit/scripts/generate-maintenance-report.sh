#!/usr/bin/env bash
# =============================================================================
# generate-maintenance-report.sh
#
# Purpose: Aggregate pass/fail results from one or more validator runs and
#          format them as a unified maintenance report for the devkit-maintainer
#          agent's output template.
#
# Accepts input in two ways:
#   1. Piped stdin — a stream of validator output lines (JSON or plain text)
#   2. --files     — one or more paths to validator result files
#
# Usage:
#   # Pipe multiple validators:
#   { ./validate-plugin.sh plugin-a; ./validate-agent.sh agent-b; } \
#       | ./generate-maintenance-report.sh
#
#   # From saved result files:
#   ./generate-maintenance-report.sh --files result-a.txt result-b.txt
#
#   # Write to file:
#   ./generate-maintenance-report.sh --files results/*.txt --output report.md
#
# Exit codes:
#   0  Report generated — all validators passed
#   1  Report generated — one or more validators failed
#   2  Argument / validation error
#   3  Missing dependency
#
# Dependencies:
#   - python3  (stdlib only — no third-party packages required)
#
# Environment:
#   NO_COLOR   Set to any non-empty value to suppress ANSI colour output
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
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR

# ---------------------------------------------------------------------------
# Colour helpers (respect NO_COLOR and non-interactive output)
# ---------------------------------------------------------------------------

if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  RED='' YELLOW='' BOLD='' DIM='' RESET=''
fi

# ---------------------------------------------------------------------------
# Logging helpers (all to stderr so stdout stays clean for the report)
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
  Reads validator output (from stdin or --files) and emits a consolidated
  maintenance report showing pass/fail counts, individual item status, and
  a summary verdict, formatted for the devkit-maintainer agent template.

  Input lines are matched against known pass/fail patterns from the devkit
  validators (validate-plugin.sh, validate-agent.sh, validate-research-output.sh).
  Unrecognised lines are collected as informational notes.

${BOLD}Input modes:${RESET}
  stdin       Pipe validator output directly (or concatenate multiple runs)
  --files     Pass one or more validator result files as arguments

  At least one input source is required.

${BOLD}Options:${RESET}
  --files PATH ...     One or more validator result file paths to aggregate
  --title TEXT         Custom report title (default: "Maintenance Report")
  --output PATH        Write report to this file instead of stdout
  --json               Emit report as JSON instead of Markdown
  --help, -h           Show this message and exit

${BOLD}Environment:${RESET}
  NO_COLOR   Suppress ANSI colour output

${BOLD}Exit codes:${RESET}
  0  All validators passed
  1  One or more validators failed
  2  Argument or validation error
  3  Missing dependency

${BOLD}Examples:${RESET}
  # Aggregate live validator runs via pipe
  { ./evals/validate-plugin.sh plugin-a 2>&1; \\
    ./evals/validate-agent.sh  agent-b  2>&1; } \\
    | ${SCRIPT_NAME}

  # Aggregate saved result files
  ${SCRIPT_NAME} --files results/plugin-a.txt results/agent-b.txt

  # Write Markdown report to a file
  ${SCRIPT_NAME} --files results/*.txt --output maintenance-report.md
EOF
}

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

check_deps() {
  if ! command -v python3 &>/dev/null; then
    log_error "python3 is required but was not found in PATH."
    exit 3
  fi
}

# ---------------------------------------------------------------------------
# Validate that a given file path exists and is readable
# ---------------------------------------------------------------------------

validate_input_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    log_error "Input file not found: ${f}"
    exit 2
  fi
  if [[ ! -r "$f" ]]; then
    log_error "Input file is not readable: ${f}"
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Core aggregation and formatting via python3
#
# Reads combined validator output from stdin, parses it into pass/fail
# records, and formats the maintenance report.
# ---------------------------------------------------------------------------

generate_report() {
  local title="$1"
  local output_format="$2"   # "markdown" or "json"
  local input_file="$3"      # path to temp file containing combined validator output

  python3 - "$title" "$output_format" "$input_file" <<'PYEOF'
import sys
import re
import json
from datetime import datetime, timezone

title         = sys.argv[1]
output_format = sys.argv[2]
input_file    = sys.argv[3]

with open(input_file) as fh:
    lines = fh.read().splitlines()

# ---- Pattern matching for devkit validator output ----
# validate-plugin.sh / validate-agent.sh emit lines like:
#   PASS  plugin-name  description
#   FAIL  plugin-name  description
#   SKIP  plugin-name  description
#   WARN  agent-name   description
# Also handle ShellCheck-style "OK" / "ERROR" lines and bats "ok / not ok" TAP output

PASS_RE = re.compile(
    r'(?:'
    r'^\s*(?:PASS|OK|✓|✔|passed?)\s'       # explicit PASS / OK
    r'|^ok\s+\d+\s'                          # TAP ok N
    r'|^\s*\[PASS\]'                         # [PASS] prefix
    r')',
    re.IGNORECASE
)

FAIL_RE = re.compile(
    r'(?:'
    r'^\s*(?:FAIL|ERROR|✗|✘|FAILED?)\s'     # explicit FAIL / ERROR
    r'|^not ok\s+\d+\s'                      # TAP not ok N
    r'|^\s*\[FAIL\]'                         # [FAIL] prefix
    r')',
    re.IGNORECASE
)

WARN_RE = re.compile(
    r'(?:'
    r'^\s*(?:WARN|WARNING|⚠)\s'
    r'|^\s*\[WARN\]'
    r')',
    re.IGNORECASE
)

SKIP_RE = re.compile(
    r'(?:'
    r'^\s*(?:SKIP|SKIPPED?)\s'
    r'|^\s*\[SKIP\]'
    r')',
    re.IGNORECASE
)

# Validator header lines to detect which tool produced the block
HEADER_RE = re.compile(
    r'(?:Validating|Running|Checking)\s+(.+)',
    re.IGNORECASE
)

records = []
notes   = []
current_validator = "unknown"

for raw_line in lines:
    line = raw_line.strip()
    if not line:
        continue

    header_m = HEADER_RE.match(line)
    if header_m and not PASS_RE.match(line) and not FAIL_RE.match(line):
        current_validator = header_m.group(1).strip()
        continue

    if PASS_RE.match(line):
        records.append({"status": "PASS", "validator": current_validator, "message": line})
    elif FAIL_RE.match(line):
        records.append({"status": "FAIL", "validator": current_validator, "message": line})
    elif WARN_RE.match(line):
        records.append({"status": "WARN", "validator": current_validator, "message": line})
    elif SKIP_RE.match(line):
        records.append({"status": "SKIP", "validator": current_validator, "message": line})
    else:
        notes.append(line)

# Summarise
pass_count = sum(1 for r in records if r["status"] == "PASS")
fail_count = sum(1 for r in records if r["status"] == "FAIL")
warn_count = sum(1 for r in records if r["status"] == "WARN")
skip_count = sum(1 for r in records if r["status"] == "SKIP")
total      = len(records)

overall = "PASS" if fail_count == 0 else "FAIL"
generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# ---- JSON output ----
if output_format == "json":
    report = {
        "title":        title,
        "generated_at": generated_at,
        "overall":      overall,
        "summary": {
            "total":   total,
            "passed":  pass_count,
            "failed":  fail_count,
            "warned":  warn_count,
            "skipped": skip_count,
        },
        "records": records,
        "notes":   notes[:20],  # cap to avoid bloat
    }
    print(json.dumps(report, indent=2))
    sys.exit(0 if overall == "PASS" else 1)

# ---- Markdown output ----
verdict_icon = "✅" if overall == "PASS" else "❌"

print(f"# {title}")
print(f"\n_Generated: {generated_at}_")
print(f"\n## Overall: {verdict_icon} {overall}\n")

print("### Summary\n")
print(f"| Status  | Count |")
print(f"|---------|-------|")
print(f"| ✅ Pass  | {pass_count:5} |")
print(f"| ❌ Fail  | {fail_count:5} |")
print(f"| ⚠️ Warn  | {warn_count:5} |")
print(f"| ⏭ Skip  | {skip_count:5} |")
print(f"| **Total** | **{total}** |")

if fail_count > 0:
    print("\n### Failures\n")
    for r in records:
        if r["status"] == "FAIL":
            print(f"- ❌ `{r['validator']}` — {r['message']}")

if warn_count > 0:
    print("\n### Warnings\n")
    for r in records:
        if r["status"] == "WARN":
            print(f"- ⚠️ `{r['validator']}` — {r['message']}")

if pass_count > 0:
    print("\n### Passing checks\n")
    for r in records:
        if r["status"] == "PASS":
            print(f"- ✅ `{r['validator']}` — {r['message']}")

if skip_count > 0:
    print("\n### Skipped\n")
    for r in records:
        if r["status"] == "SKIP":
            print(f"- ⏭ `{r['validator']}` — {r['message']}")

if notes:
    # Show up to 10 note lines to keep report readable
    print("\n### Notes\n")
    for note in notes[:10]:
        print(f"> {note}")
    if len(notes) > 10:
        print(f"\n_(and {len(notes) - 10} more lines — rerun with full output for details)_")

print()  # trailing newline

sys.exit(0 if overall == "PASS" else 1)
PYEOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

REPORT_TITLE="Maintenance Report"
OUTPUT_PATH=""
OUTPUT_FORMAT="markdown"
INPUT_FILES=()
HAS_STDIN=false

# Detect piped stdin before parsing arguments
if [[ ! -t 0 ]]; then
  HAS_STDIN=true
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --files)
      shift
      # Consume all remaining non-option arguments as file paths
      while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
        INPUT_FILES+=("$1")
        shift
      done
      if [[ "${#INPUT_FILES[@]}" -eq 0 ]]; then
        log_error "--files requires at least one PATH argument"
        usage >&2
        exit 2
      fi
      ;;
    --title)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        log_error "--title requires a TEXT argument"
        usage >&2
        exit 2
      fi
      REPORT_TITLE="$2"
      shift 2
      ;;
    --title=*)
      REPORT_TITLE="${1#*=}"
      shift
      ;;
    --output)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        log_error "--output requires a PATH argument"
        usage >&2
        exit 2
      fi
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --output=*)
      OUTPUT_PATH="${1#*=}"
      shift
      ;;
    --json)
      OUTPUT_FORMAT="json"
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

# Require at least one input source
if [[ "$HAS_STDIN" == "false" && "${#INPUT_FILES[@]}" -eq 0 ]]; then
  log_error "No input provided. Pipe validator output or use --files."
  usage >&2
  exit 2
fi

# Validate all input files exist before doing any work
for f in "${INPUT_FILES[@]+"${INPUT_FILES[@]}"}"; do
  validate_input_file "$f"
done

check_deps

# ---------------------------------------------------------------------------
# Build combined input stream
# ---------------------------------------------------------------------------

# If writing to a file, ensure parent directory exists
if [[ -n "$OUTPUT_PATH" ]]; then
  output_dir="$(dirname -- "$OUTPUT_PATH")"
  if [[ ! -d "$output_dir" ]]; then
    log_error "Output directory does not exist: ${output_dir}"
    exit 2
  fi
fi

log_info "Aggregating validator output (title='${REPORT_TITLE}', format=${OUTPUT_FORMAT}) ..."

# ---------------------------------------------------------------------------
# Collect all input into a single temp file.
#
# python3 reads via a heredoc which occupies its stdin; passing the combined
# content as a file path argument avoids stdin contention entirely. We also
# buffer stdin early so it is available before any subshell pipeline is
# established.
# ---------------------------------------------------------------------------

COMBINED_INPUT="$(mktemp)"
tmp_report=""
trap 'rm -f -- "${COMBINED_INPUT:-}" "${tmp_report:-}"' EXIT

# Read piped stdin into the combined file first (must happen before any pipeline)
if [[ "$HAS_STDIN" == "true" ]]; then
  cat - >> "$COMBINED_INPUT"
fi

# Append any --files content, separated by blank lines
for f in "${INPUT_FILES[@]+"${INPUT_FILES[@]}"}"; do
  cat -- "$f" >> "$COMBINED_INPUT"
  printf '\n' >> "$COMBINED_INPUT"
done

# ---------------------------------------------------------------------------
# Generate and emit the report
# ---------------------------------------------------------------------------

report_exit=0

if [[ -n "$OUTPUT_PATH" ]]; then
  # Atomic write: generate to temp file then move into place only on success
  tmp_report="$(mktemp)"
  if generate_report "$REPORT_TITLE" "$OUTPUT_FORMAT" "$COMBINED_INPUT" \
    > "$tmp_report"; then
    mv -- "$tmp_report" "$OUTPUT_PATH"
    log_info "Report written to: ${OUTPUT_PATH}"
  else
    report_exit=$?
    rm -f -- "$tmp_report"
  fi
else
  generate_report "$REPORT_TITLE" "$OUTPUT_FORMAT" "$COMBINED_INPUT" \
    || report_exit=$?
fi

exit "$report_exit"
