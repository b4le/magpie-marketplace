#!/usr/bin/env bash
# =============================================================================
# fetch-changelog.sh
#
# Purpose: Fetch Claude Code release notes from the GitHub Releases API (primary)
#          or CHANGELOG.md (fallback) and parse them into structured output.
#
# Usage:
#   ./fetch-changelog.sh [--since YYYY-MM-DD] [--raw] [--json] [--help]
#
# Exit codes:
#   0  Success (entries found and printed, or no entries since date)
#   1  Argument / validation error
#   2  Missing dependency
#   3  Network unavailable or fetch failed (graceful fallback)
#
# Dependencies:
#   - curl
#   - python3  (stdlib only — no third-party packages required)
#
# Environment:
#   NO_COLOR         Set to any non-empty value to suppress ANSI colour output
#   GITHUB_TOKEN     Optional — set to avoid GitHub API rate-limiting on curl
# =============================================================================

set -Eeuo pipefail
if (( BASH_VERSINFO[0] > 4 || ( BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4 ) )); then
  shopt -s inherit_errexit
fi

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCRIPT_NAME="$(basename -- "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME
readonly RELEASES_API_URL="https://api.github.com/repos/anthropics/claude-code/releases"
readonly CHANGELOG_URL="https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
readonly FALLBACK_URL="https://raw.githubusercontent.com/anthropics/claude-code/refs/heads/main/CHANGELOG.md"

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
# Logging helpers (all to stderr so stdout stays clean for parsed output)
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
  Fetches Claude Code release notes from the GitHub Releases API (primary)
  or CHANGELOG.md (fallback) and extracts version entries released on or
  after the given date.

  Output modes:
    parsed (default) — human-readable structured summary
    --raw            — raw markdown body of each release
    --json           — machine-readable JSON array

${BOLD}Options:${RESET}
  --since YYYY-MM-DD  Only include versions released on or after this date
                      (default: show the 3 most recent versions)
  --raw               Print the raw markdown section instead of parsing it
  --json              Emit JSON array: [{version, date, body, features, fixes, breaking}]
  --help, -h          Show this message and exit

${BOLD}Environment:${RESET}
  NO_COLOR        Suppress ANSI colour output
  GITHUB_TOKEN    GitHub personal-access-token for authenticated requests
                  (avoids rate-limiting on shared IP addresses)

${BOLD}Examples:${RESET}
  ${SCRIPT_NAME} --since 2025-01-01
  ${SCRIPT_NAME} --since 2024-06-01 --raw
  ${SCRIPT_NAME} --since 2025-03-01 --json
  GITHUB_TOKEN=ghp_xxx ${SCRIPT_NAME} --since 2025-03-01

${BOLD}Exit codes:${RESET}
  0  Success
  1  Argument or validation error
  2  Missing dependency
  3  Network unavailable or fetch failed
EOF
}

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

check_deps() {
  local -a missing=()
  local cmd
  for cmd in curl python3; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ "${#missing[@]}" -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
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
# Build curl auth args (shared by both fetch functions)
# ---------------------------------------------------------------------------

curl_auth_args() {
  local -a args=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    args+=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  printf '%s\n' "${args[@]}"
}

# ---------------------------------------------------------------------------
# Fetch releases from GitHub Releases API (primary source)
# Returns: JSON array on stdout, or returns non-zero on failure
# ---------------------------------------------------------------------------

fetch_releases() {
  local -a curl_args=(
    --silent
    --fail
    --location
    --max-time 15
    --retry 2
    --retry-delay 1
    --header "Accept: application/vnd.github+json"
  )

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  # Fetch up to 100 releases (most recent first by default)
  curl "${curl_args[@]}" -- "${RELEASES_API_URL}?per_page=100" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Fetch raw CHANGELOG.md content (fallback)
# ---------------------------------------------------------------------------

fetch_raw_changelog() {
  local -a curl_args=(
    --silent
    --fail
    --location
    --max-time 15
    --retry 2
    --retry-delay 1
  )

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  local url
  for url in "$CHANGELOG_URL" "$FALLBACK_URL"; do
    if curl "${curl_args[@]}" -- "$url" 2>/dev/null; then
      return 0
    fi
    log_warn "Fetch failed for ${url}, trying fallback..."
  done

  return 1
}

# ---------------------------------------------------------------------------
# Process releases/changelog through Python parser
#
# Arguments:
#   $1  since date (YYYY-MM-DD, or empty string for "latest 3")
#   $2  "raw" | "parsed" | "json"
#   $3  "api" | "changelog" — indicates input format
# Stdin: either GitHub API JSON or raw CHANGELOG.md text
# ---------------------------------------------------------------------------

process_entries() {
  local since_date="$1"
  local output_mode="$2"
  local input_format="$3"
  local content="$4"

  # Write content to a temp file so it doesn't conflict with the heredoc stdin
  local tmpfile
  tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' RETURN
  printf '%s' "$content" > "$tmpfile"

  python3 - "$since_date" "$output_mode" "$input_format" "$tmpfile" <<'PYEOF'
import sys
import re
import json
from datetime import date, datetime

since_arg    = sys.argv[1]   # YYYY-MM-DD or empty
output_mode  = sys.argv[2]   # "raw", "parsed", or "json"
input_format = sys.argv[3]   # "api" or "changelog"
tmpfile      = sys.argv[4]

with open(tmpfile) as f:
    content = f.read()

# -------------------------------------------------------------------------
# Parse input into a normalized list of entries
# -------------------------------------------------------------------------

entries = []

if input_format == "api":
    # GitHub Releases API JSON
    try:
        releases = json.loads(content)
    except json.JSONDecodeError:
        print("Failed to parse GitHub API response as JSON.", file=sys.stderr)
        sys.exit(1)

    for rel in releases:
        tag = rel.get("tag_name", "")
        # Strip leading 'v' from tag (e.g., v2.1.68 -> 2.1.68)
        version = tag.lstrip("v") if tag else rel.get("name", "unknown")
        pub_date = rel.get("published_at", "")
        # published_at is ISO8601: "2026-03-05T14:22:00Z"
        if pub_date:
            release_date = pub_date[:10]
        else:
            release_date = ""
        body = rel.get("body", "") or ""
        entries.append({
            "version": version,
            "date": release_date,
            "body": body,
        })

else:
    # Raw CHANGELOG.md — handles both "## [1.2.3] - DATE" and "## 1.2.3" formats
    # Pattern 1: ## [1.2.3] - 2025-01-15  or  ## [1.2.3] (2025-01-15)
    # Pattern 2: ## 1.2.3  (no brackets, no date)
    VERSION_RE = re.compile(
        r'^##\s+'
        r'(?:\[(?P<ver_bracket>[^\]]+)\]|(?P<ver_bare>\d+\.\d+(?:\.\d+)*))'
        r'(?:\s*[-–]\s*(?P<date1>\d{4}-\d{2}-\d{2}))?'
        r'(?:\s*\((?P<date2>\d{4}-\d{2}-\d{2})\))?',
        re.MULTILINE
    )

    matches = list(VERSION_RE.finditer(content))

    for idx, m in enumerate(matches):
        start = m.start()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(content)
        version = m.group("ver_bracket") or m.group("ver_bare")
        release_date = m.group("date1") or m.group("date2") or ""
        entries.append({
            "version": version,
            "date": release_date,
            "body": content[start:end].strip(),
        })

# -------------------------------------------------------------------------
# Filter by date
# -------------------------------------------------------------------------

if since_arg:
    since = date.fromisoformat(since_arg)
    filtered = []
    for e in entries:
        if e["date"]:
            try:
                if date.fromisoformat(e["date"]) >= since:
                    filtered.append(e)
            except ValueError:
                filtered.append(e)  # include if date is unparseable
        # If no date available (changelog fallback), include everything
        # and warn the user
        elif input_format == "changelog":
            filtered.append(e)
    entries = filtered
else:
    entries = entries[:3]

if not entries:
    print("No changelog entries found for the specified range.", file=sys.stderr)
    sys.exit(0)

# -------------------------------------------------------------------------
# Helper: extract bullet lines from a section
# -------------------------------------------------------------------------

BREAKING_RE = re.compile(r'(?i)(?:^###?\s*breaking|BREAKING)', re.MULTILINE)
FEATURE_RE  = re.compile(r'(?i)^###?\s*(?:features?|added|new|what\'s\s+changed)', re.MULTILINE)
FIX_RE      = re.compile(r'(?i)^###?\s*(?:bug\s*fixes?|fixed|fixes?)', re.MULTILINE)

def extract_bullets(text, section_re):
    """Return bullet lines from the first matching section heading."""
    m = section_re.search(text)
    if not m:
        return []
    section_start = m.end()
    next_section = re.search(r'^###?', text[section_start:], re.MULTILINE)
    section_text = (text[section_start: section_start + next_section.start()]
                    if next_section else text[section_start:])
    bullets = [
        line.lstrip('*- ').strip()
        for line in section_text.splitlines()
        if line.strip().startswith(('-', '*', '\u2022'))
    ]
    return bullets

def all_bullets(text):
    """Extract all bullet lines from text."""
    return [
        line.lstrip('*- ').strip()
        for line in text.splitlines()
        if line.strip().startswith(('-', '*', '\u2022'))
    ]

# -------------------------------------------------------------------------
# Raw mode
# -------------------------------------------------------------------------

if output_mode == "raw":
    for e in entries:
        if e["date"]:
            print(f"## {e['version']} ({e['date']})")
        else:
            print(f"## {e['version']}")
        print()
        print(e["body"])
        print()
    sys.exit(0)

# -------------------------------------------------------------------------
# Build structured data for each entry (used by both parsed and json modes)
# -------------------------------------------------------------------------

structured = []
for e in entries:
    body = e["body"]
    features = extract_bullets(body, FEATURE_RE)
    fixes = extract_bullets(body, FIX_RE)
    breaking = bool(BREAKING_RE.search(body))

    # If no features found via headings, try top-level bullets
    if not features and not fixes:
        features = all_bullets(body)

    structured.append({
        "version": e["version"],
        "date": e["date"],
        "body": body,
        "features": features,
        "fixes": fixes,
        "breaking": breaking,
    })

# -------------------------------------------------------------------------
# JSON mode
# -------------------------------------------------------------------------

if output_mode == "json":
    print(json.dumps(structured, indent=2))
    sys.exit(0)

# -------------------------------------------------------------------------
# Parsed (human-readable) mode
# -------------------------------------------------------------------------

for s in structured:
    date_str = f"  ({s['date']})" if s["date"] else ""
    breaking_str = " [BREAKING CHANGES]" if s["breaking"] else ""
    print(f"=== {s['version']}{date_str}{breaking_str}")
    if s["features"]:
        print("  Features:")
        for b in s["features"]:
            print(f"    \u2022 {b}")
    if s["fixes"]:
        print("  Bug fixes:")
        for b in s["fixes"]:
            print(f"    \u2022 {b}")
    if not s["features"] and not s["fixes"]:
        print("  (no categorized changes)")
    print()

PYEOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

SINCE_DATE=""
OUTPUT_MODE="parsed"

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --raw)
      OUTPUT_MODE="raw"
      shift
      ;;
    --json)
      OUTPUT_MODE="json"
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
# Main — try GitHub Releases API first, fall back to CHANGELOG.md
# ---------------------------------------------------------------------------

log_info "Fetching releases from github.com/anthropics/claude-code ..."

api_content=""
input_format=""

if api_content="$(fetch_releases 2>/dev/null)" && [[ -n "$api_content" ]]; then
  input_format="api"
  log_info "Using GitHub Releases API (has dates and structured bodies)"
else
  log_warn "GitHub Releases API unavailable — falling back to raw CHANGELOG.md"
  if [[ -n "$SINCE_DATE" ]]; then
    log_warn "--since filtering may be degraded (CHANGELOG.md may lack dates)"
  fi
  if ! api_content="$(fetch_raw_changelog)"; then
    log_warn "Network unavailable or fetch failed — cannot retrieve changelog."
    log_warn "Check your connection or set GITHUB_TOKEN to avoid rate-limiting."
    exit 3
  fi
  if [[ -z "$api_content" ]]; then
    log_warn "Fetched an empty response — changelog may have moved."
    exit 3
  fi
  input_format="changelog"
fi

log_info "Parsing entries (since=${SINCE_DATE:-'latest 3'}, mode=${OUTPUT_MODE}, source=${input_format}) ..."

process_entries "$SINCE_DATE" "$OUTPUT_MODE" "$input_format" "$api_content"
