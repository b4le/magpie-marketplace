#!/usr/bin/env bash
# =============================================================================
# analyze-sync.sh
#
# Purpose: Automated changelog-to-schema sync analysis. Fetches recent Claude
#          Code releases, scans for schema-relevant signal phrases, cross-refs
#          against current schemas, and produces an actionable checklist.
#
# Usage:
#   ./analyze-sync.sh [--since YYYY-MM-DD] [--json] [--output PATH] [--help]
#
# Exit codes:
#   0  Success (report generated)
#   1  Argument / validation error
#   2  Missing dependency
#   3  Network / fetch failure (from fetch-changelog.sh)
#
# Dependencies:
#   - bash 4.4+
#   - python3  (stdlib only)
#   - fetch-changelog.sh (in same directory)
#
# Environment:
#   NO_COLOR         Suppress ANSI colour output
#   GITHUB_TOKEN     Optional — passed through to fetch-changelog.sh
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

readonly EXPECTED_FIELDS="${SCRIPT_DIR}/expected-fields.json"
readonly FETCH_SCRIPT="${SCRIPT_DIR}/fetch-changelog.sh"
readonly SCHEMAS_DIR="${PLUGIN_ROOT}/schemas"

# ---------------------------------------------------------------------------
# Colour helpers
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
# Logging helpers (stderr)
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
  Fetches recent Claude Code releases, scans for schema-relevant changes,
  cross-references against the devkit schemas, and produces a categorized
  sync report.

  Output categories:
    Action Required  — confirmed schema gap (signal matched, schema missing it)
    Needs Review     — signal matched but field name could not be auto-extracted
    Already Covered  — signal matched, schema already has it
    Informational    — no schema-relevant changes in release

${BOLD}Options:${RESET}
  --since YYYY-MM-DD  Analyze releases since this date
                      (default: reads _updated from expected-fields.json)
  --json              Emit JSON instead of markdown checklist
  --output PATH       Write report to file instead of stdout
  --help, -h          Show this message and exit

${BOLD}Environment:${RESET}
  NO_COLOR        Suppress colour output
  GITHUB_TOKEN    Passed to fetch-changelog.sh for authenticated requests

${BOLD}Examples:${RESET}
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --since 2026-03-04
  ${SCRIPT_NAME} --json --output /tmp/sync-report.json
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
  if [[ ! -x "$FETCH_SCRIPT" && ! -f "$FETCH_SCRIPT" ]]; then
    log_error "fetch-changelog.sh not found at: ${FETCH_SCRIPT}"
    exit 2
  fi
  if [[ "${#missing[@]}" -gt 0 ]]; then
    log_error "Missing required commands: ${missing[*]}"
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Validate date
# ---------------------------------------------------------------------------

validate_date() {
  local date_str="$1"
  if [[ ! "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    log_error "Invalid date format '${date_str}' — expected YYYY-MM-DD"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Stage 1: Read sync window from expected-fields.json
# ---------------------------------------------------------------------------

read_sync_date() {
  python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    print(data.get('_updated', ''))
except Exception as e:
    print(f'Error reading expected-fields.json: {e}', file=sys.stderr)
    sys.exit(1)
" "${EXPECTED_FIELDS}"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

SINCE_DATE=""
OUTPUT_MODE="markdown"
OUTPUT_PATH=""

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
    --json)
      OUTPUT_MODE="json"
      shift
      ;;
    --output)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        log_error "--output requires a file path argument"
        usage >&2
        exit 1
      fi
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --output=*)
      OUTPUT_PATH="${1#*=}"
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

check_deps

# ---------------------------------------------------------------------------
# Stage 1: Determine sync window
# ---------------------------------------------------------------------------

if [[ -z "$SINCE_DATE" ]]; then
  log_info "Stage 1: Reading sync date from expected-fields.json ..."
  SINCE_DATE="$(read_sync_date)"
  if [[ -z "$SINCE_DATE" ]]; then
    log_warn "No _updated date found in expected-fields.json — using 30 days ago"
    SINCE_DATE="$(python3 -c "from datetime import date, timedelta; print((date.today() - timedelta(days=30)).isoformat())")"
  fi
  log_info "Sync window: since ${SINCE_DATE}"
else
  validate_date "$SINCE_DATE"
  log_info "Stage 1: Using provided sync date: ${SINCE_DATE}"
fi

# ---------------------------------------------------------------------------
# Stage 2: Fetch changelog entries as JSON
# ---------------------------------------------------------------------------

log_info "Stage 2: Fetching changelog entries since ${SINCE_DATE} ..."

changelog_json=""
if ! changelog_json="$(bash "$FETCH_SCRIPT" --since "$SINCE_DATE" --json 2>/dev/null)"; then
  # Try again with stderr visible for diagnostics
  if ! changelog_json="$(bash "$FETCH_SCRIPT" --since "$SINCE_DATE" --json)"; then
    log_error "fetch-changelog.sh failed — see warnings above"
    exit 3
  fi
fi

if [[ -z "$changelog_json" || "$changelog_json" == "[]" ]]; then
  log_info "No changelog entries found since ${SINCE_DATE}. Nothing to analyze."
  if [[ "$OUTPUT_MODE" == "json" ]]; then
    echo '{"since":"'"$SINCE_DATE"'","entries":[],"findings":[]}'
  else
    echo "# Sync Analysis Report"
    echo ""
    echo "**Since:** ${SINCE_DATE}"
    echo ""
    echo "No new releases found. Schemas are up to date."
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Stages 3-5: Signal scanning, schema cross-ref, report generation
#
# All done in a single Python process for efficiency
# ---------------------------------------------------------------------------

log_info "Stages 3-5: Scanning signals, cross-referencing schemas, generating report ..."

# Build the report via Python
report="$(python3 - "$changelog_json" "$SINCE_DATE" "$OUTPUT_MODE" "$SCHEMAS_DIR" <<'PYEOF'
import sys
import json
import re
import os
from pathlib import Path

changelog_json = sys.argv[1]
since_date     = sys.argv[2]
output_mode    = sys.argv[3]  # "markdown" or "json"
schemas_dir    = sys.argv[4]

# -------------------------------------------------------------------------
# Parse changelog entries
# -------------------------------------------------------------------------

try:
    entries = json.loads(changelog_json)
except json.JSONDecodeError as e:
    print(f"Failed to parse changelog JSON: {e}", file=sys.stderr)
    sys.exit(1)

# -------------------------------------------------------------------------
# Load schemas for cross-referencing
# -------------------------------------------------------------------------

schemas = {}
schema_files = [
    "hooks.schema.json",
    "agent-frontmatter.schema.json",
    "skill-frontmatter.schema.json",
    "plugin.schema.json",
    "command-frontmatter.schema.json",
    "tools-enum.json",
]

for sf in schema_files:
    path = os.path.join(schemas_dir, sf)
    if os.path.exists(path):
        with open(path) as f:
            schemas[sf] = json.load(f)

# -------------------------------------------------------------------------
# Helper: extract known hook events from schema regex
# -------------------------------------------------------------------------

def get_hook_events():
    """Extract event names from the hooksMap patternProperties key."""
    hooks = schemas.get("hooks.schema.json", {})
    hooks_map = hooks.get("definitions", {}).get("hooksMap", {})
    pattern_keys = list(hooks_map.get("patternProperties", {}).keys())
    if not pattern_keys:
        return set()
    # Parse the regex alternation: ^(A|B|C)(\/...)?$
    m = re.match(r'^\^\(([^)]+)\)', pattern_keys[0])
    if m:
        return set(m.group(1).split("|"))
    return set()

def get_schema_properties(schema_name):
    """Get top-level property names from a schema."""
    s = schemas.get(schema_name, {})
    return set(s.get("properties", {}).keys())

def get_tool_enum():
    """Get known built-in tool names."""
    te = schemas.get("tools-enum.json", {})
    defs = te.get("definitions", {}).get("toolName", {})
    for item in defs.get("oneOf", []):
        if "enum" in item:
            return set(item["enum"])
    return set()

def get_model_enum():
    """Get known model shorthand values."""
    agent = schemas.get("agent-frontmatter.schema.json", {})
    model_def = agent.get("properties", {}).get("model", {})
    return set(model_def.get("enum", []))

def get_permission_enum():
    """Get known permissionMode values."""
    agent = schemas.get("agent-frontmatter.schema.json", {})
    pm = agent.get("properties", {}).get("permissionMode", {})
    return set(pm.get("enum", []))

known_hook_events = get_hook_events()
agent_properties = get_schema_properties("agent-frontmatter.schema.json")
skill_properties = get_schema_properties("skill-frontmatter.schema.json")
plugin_properties = get_schema_properties("plugin.schema.json")
command_properties = get_schema_properties("command-frontmatter.schema.json")
known_tools = get_tool_enum()
known_models = get_model_enum()
known_permissions = get_permission_enum()

# -------------------------------------------------------------------------
# Stage 3: Signal phrase rules
#
# Each rule: (regex_pattern, schema_area, extraction_fn_or_None)
# extraction_fn takes the match and body text, returns extracted item name
# -------------------------------------------------------------------------

# Helper to extract PascalCase or camelCase identifiers near a match
NOISE_WORDS = {
    "Added", "Fixed", "Removed", "Updated", "Improved", "Changed",
    "The", "This", "When", "Use", "Set", "See", "For", "With",
    "New", "Now", "Not", "Also", "Only", "Some", "All", "Any",
    "Bug", "API", "URL", "CLI", "MCP", "LSP", "JSON", "YAML",
    "HTTP", "HTML", "CSS", "HTTPS", "EOF", "BREAKING",
}

def extract_pascal_near(match_obj, text, window=80):
    """Extract PascalCase identifiers near the match, filtering noise words."""
    start = max(0, match_obj.start() - window)
    end = min(len(text), match_obj.end() + window)
    snippet = text[start:end]
    candidates = re.findall(r'`([A-Z][a-zA-Z0-9]+)`', snippet)
    if not candidates:
        candidates = re.findall(r'\b([A-Z][a-zA-Z0-9]{2,})\b', snippet)
    return [c for c in candidates if c not in NOISE_WORDS]

def extract_camel_near(match_obj, text, window=80):
    """Extract camelCase identifiers near the match."""
    start = max(0, match_obj.start() - window)
    end = min(len(text), match_obj.end() + window)
    snippet = text[start:end]
    candidates = re.findall(r'`([a-z][a-zA-Z0-9]+)`', snippet)
    return candidates

SIGNAL_RULES = [
    # Hook events
    {
        "pattern": re.compile(r'(?i)(?:(?:new|added?)\s+)?(?:hook\s+|lifecycle\s+)event[s]?\b.*?(?:`([A-Z][a-zA-Z]+)`)?', re.MULTILINE),
        "schema_area": "hooks.schema.json",
        "category": "hook_event",
        "label": "Hook Event",
    },
    # Hook type
    {
        "pattern": re.compile(r'(?i)(?:new\s+)?hook\s+(?:type|handler)\b.*?(?:`(\w+)`)?', re.MULTILINE),
        "schema_area": "hooks.schema.json",
        "category": "hook_type",
        "label": "Hook Type",
    },
    # Hook property
    {
        "pattern": re.compile(r'(?i)hook\s+propert(?:y|ies)\b.*?(?:`(\w+)`)?', re.MULTILINE),
        "schema_area": "hooks.schema.json",
        "category": "hook_property",
        "label": "Hook Property",
    },
    # Agent field
    {
        "pattern": re.compile(r'(?i)agent\s+(?:field|propert(?:y|ies)|frontmatter)\b.*?(?:`(\w+)`)?', re.MULTILINE),
        "schema_area": "agent-frontmatter.schema.json",
        "category": "agent_field",
        "label": "Agent Field",
    },
    # Skill field
    {
        "pattern": re.compile(r'(?i)skill\s+(?:field|propert(?:y|ies)|frontmatter)\b.*?(?:`(\w+)`)?', re.MULTILINE),
        "schema_area": "skill-frontmatter.schema.json",
        "category": "skill_field",
        "label": "Skill Field",
    },
    # Plugin field
    {
        "pattern": re.compile(r'(?i)(?:plugin\.json|plugin\s+(?:field|propert(?:y|ies)|manifest))\b.*?(?:`(\w+)`)?', re.MULTILINE),
        "schema_area": "plugin.schema.json",
        "category": "plugin_field",
        "label": "Plugin Field",
    },
    # Tool name / renamed tool
    {
        "pattern": re.compile(r'(?i)(?:(?:new|renamed?|added?|removed?)\s+(?:built-?in\s+)?tool|tool\s+(?:name|renamed?|added|removed))\b.*?(?:`([A-Z][a-zA-Z]+)`)?', re.MULTILINE),
        "schema_area": "tools-enum.json",
        "category": "tool_name",
        "label": "Tool Name",
    },
    # Model shorthand
    {
        "pattern": re.compile(r'(?i)(?:new\s+)?model\s+(?:shorthand|alias|name)\b.*?(?:`(\w+)`)?', re.MULTILINE),
        "schema_area": "agent-frontmatter.schema.json",
        "category": "model",
        "label": "Model Shorthand",
    },
    # permissionMode
    {
        "pattern": re.compile(r'(?i)permission\s*[Mm]ode\b.*?(?:`(\w+)`)?', re.MULTILINE),
        "schema_area": "agent-frontmatter.schema.json",
        "category": "permission_mode",
        "label": "Permission Mode",
    },
    # settings
    {
        "pattern": re.compile(r'(?i)(?:plugin\s+settings\.json|plugin\.json\s+settings|plugin\s+settings\b)', re.MULTILINE),
        "schema_area": "plugin.schema.json",
        "category": "settings",
        "label": "Plugin Settings",
    },
    # Command field
    {
        "pattern": re.compile(r'(?i)command\s+(?:field|propert(?:y|ies)|frontmatter)\b.*?(?:`(\w+)`)?', re.MULTILINE),
        "schema_area": "command-frontmatter.schema.json",
        "category": "command_field",
        "label": "Command Field",
    },
]

# -------------------------------------------------------------------------
# Stage 3 & 4: Scan each entry and cross-reference
# -------------------------------------------------------------------------

findings = []

for entry in entries:
    version = entry.get("version", "unknown")
    date = entry.get("date", "")
    body = entry.get("body", "")
    features = entry.get("features", [])
    fixes = entry.get("fixes", [])
    breaking = entry.get("breaking", False)

    # Combine all text for scanning
    all_text = body + "\n" + "\n".join(features) + "\n" + "\n".join(fixes)
    entry_findings = []

    for rule in SIGNAL_RULES:
        for match in rule["pattern"].finditer(all_text):
            extracted_name = match.group(1) if match.lastindex and match.group(1) else None

            # Try to extract identifiers near the match if none captured
            if not extracted_name:
                if rule["category"] in ("hook_event", "tool_name"):
                    candidates = extract_pascal_near(match, all_text)
                    extracted_name = candidates[0] if candidates else None
                elif rule["category"] in ("agent_field", "skill_field", "plugin_field", "hook_property", "command_field"):
                    candidates = extract_camel_near(match, all_text)
                    if not candidates:
                        candidates = extract_pascal_near(match, all_text)
                    extracted_name = candidates[0] if candidates else None

            # Cross-reference against schema
            status = "needs_review"
            schema_area = rule["schema_area"]

            if rule["category"] == "hook_event" and extracted_name:
                if extracted_name in known_hook_events:
                    status = "already_covered"
                else:
                    status = "action_required"

            elif rule["category"] == "hook_type" and extracted_name:
                # Check if handler type exists in oneOf
                hooks_schema = schemas.get("hooks.schema.json", {})
                handler_defs = hooks_schema.get("definitions", {}).get("hookHandler", {}).get("oneOf", [])
                existing_types = set()
                for hd in handler_defs:
                    for prop_name, prop_val in hd.get("properties", {}).items():
                        if prop_name == "type" and "const" in prop_val:
                            existing_types.add(prop_val["const"])
                if extracted_name.lower() in existing_types:
                    status = "already_covered"
                else:
                    status = "action_required"

            elif rule["category"] == "hook_property" and extracted_name:
                # Check if property exists on any handler type
                hooks_schema = schemas.get("hooks.schema.json", {})
                handler_defs = hooks_schema.get("definitions", {}).get("hookHandler", {}).get("oneOf", [])
                all_props = set()
                for hd in handler_defs:
                    all_props.update(hd.get("properties", {}).keys())
                # Also check hookEntry properties
                entry_props = hooks_schema.get("definitions", {}).get("hookEntry", {}).get("properties", {}).keys()
                all_props.update(entry_props)
                if extracted_name in all_props:
                    status = "already_covered"
                else:
                    status = "action_required"

            elif rule["category"] == "agent_field" and extracted_name:
                if extracted_name in agent_properties:
                    status = "already_covered"
                else:
                    status = "action_required"

            elif rule["category"] == "skill_field" and extracted_name:
                if extracted_name in skill_properties:
                    status = "already_covered"
                else:
                    status = "action_required"

            elif rule["category"] == "plugin_field" and extracted_name:
                if extracted_name in plugin_properties:
                    status = "already_covered"
                else:
                    status = "action_required"

            elif rule["category"] == "command_field" and extracted_name:
                if extracted_name in command_properties:
                    status = "already_covered"
                else:
                    status = "action_required"

            elif rule["category"] == "tool_name" and extracted_name:
                if extracted_name in known_tools:
                    status = "already_covered"
                else:
                    status = "action_required"

            elif rule["category"] == "model" and extracted_name:
                if extracted_name in known_models:
                    status = "already_covered"
                else:
                    status = "action_required"

            elif rule["category"] == "permission_mode" and extracted_name:
                if extracted_name in known_permissions:
                    status = "already_covered"
                else:
                    status = "action_required"

            elif rule["category"] == "settings":
                if "settings" in plugin_properties:
                    status = "already_covered"
                else:
                    status = "action_required"
                extracted_name = "settings"

            # Build the matched line for context
            line_start = all_text.rfind("\n", 0, match.start()) + 1
            line_end = all_text.find("\n", match.end())
            if line_end == -1:
                line_end = len(all_text)
            matched_line = all_text[line_start:line_end].strip()

            finding = {
                "version": version,
                "date": date,
                "category": rule["category"],
                "label": rule["label"],
                "schema_area": schema_area,
                "extracted_name": extracted_name,
                "status": status,
                "matched_line": matched_line[:200],
                "breaking": breaking,
            }

            # Deduplicate: skip if we already have a finding for same version+category+extracted_name
            key = (version, rule["category"], extracted_name)
            if key not in {(f["version"], f["category"], f["extracted_name"]) for f in entry_findings}:
                entry_findings.append(finding)

    if not entry_findings:
        findings.append({
            "version": version,
            "date": date,
            "category": "informational",
            "label": "Informational",
            "schema_area": "",
            "extracted_name": None,
            "status": "informational",
            "matched_line": "(no schema-relevant signal phrases detected)",
            "breaking": breaking,
        })
    else:
        findings.extend(entry_findings)

# -------------------------------------------------------------------------
# Stage 5: Report generation
# -------------------------------------------------------------------------

if output_mode == "json":
    report = {
        "since": since_date,
        "entries_analyzed": len(entries),
        "versions": [e["version"] for e in entries],
        "findings": findings,
        "summary": {
            "action_required": sum(1 for f in findings if f["status"] == "action_required"),
            "needs_review": sum(1 for f in findings if f["status"] == "needs_review"),
            "already_covered": sum(1 for f in findings if f["status"] == "already_covered"),
            "informational": sum(1 for f in findings if f["status"] == "informational"),
        }
    }
    print(json.dumps(report, indent=2))

else:
    # Markdown checklist
    lines = []
    lines.append("# Sync Analysis Report")
    lines.append("")
    lines.append(f"**Since:** {since_date}")
    lines.append(f"**Releases analyzed:** {len(entries)}")
    lines.append(f"**Versions:** {', '.join(e['version'] for e in entries)}")
    lines.append("")

    # Summary counts
    action_count = sum(1 for f in findings if f["status"] == "action_required")
    review_count = sum(1 for f in findings if f["status"] == "needs_review")
    covered_count = sum(1 for f in findings if f["status"] == "already_covered")
    info_count = sum(1 for f in findings if f["status"] == "informational")

    lines.append("## Summary")
    lines.append("")
    lines.append(f"| Category | Count |")
    lines.append(f"|----------|-------|")
    lines.append(f"| Action Required | {action_count} |")
    lines.append(f"| Needs Review | {review_count} |")
    lines.append(f"| Already Covered | {covered_count} |")
    lines.append(f"| Informational | {info_count} |")
    lines.append("")

    # Action Required
    action_items = [f for f in findings if f["status"] == "action_required"]
    if action_items:
        lines.append("## Action Required")
        lines.append("")
        for f in action_items:
            name = f"**{f['extracted_name']}**" if f["extracted_name"] else "_(unknown)_"
            breaking_tag = " [BREAKING]" if f["breaking"] else ""
            lines.append(f"- [ ] {f['label']}: {name} — `{f['schema_area']}`{breaking_tag}")
            lines.append(f"  - Version: {f['version']} ({f['date']})")
            lines.append(f"  - Context: {f['matched_line']}")
        lines.append("")

    # Needs Review
    review_items = [f for f in findings if f["status"] == "needs_review"]
    if review_items:
        lines.append("## Needs Review")
        lines.append("")
        for f in review_items:
            name = f"**{f['extracted_name']}**" if f["extracted_name"] else "_(could not extract field name)_"
            lines.append(f"- [ ] {f['label']}: {name} — `{f['schema_area']}`")
            lines.append(f"  - Version: {f['version']} ({f['date']})")
            lines.append(f"  - Context: {f['matched_line']}")
        lines.append("")

    # Already Covered
    covered_items = [f for f in findings if f["status"] == "already_covered"]
    if covered_items:
        lines.append("## Already Covered")
        lines.append("")
        for f in covered_items:
            name = f"**{f['extracted_name']}**" if f["extracted_name"] else "_(unknown)_"
            lines.append(f"- [x] {f['label']}: {name} — `{f['schema_area']}`")
            lines.append(f"  - Version: {f['version']} ({f['date']})")
        lines.append("")

    # Informational
    info_items = [f for f in findings if f["status"] == "informational"]
    if info_items:
        lines.append("## Informational")
        lines.append("")
        for f in info_items:
            lines.append(f"- {f['version']} ({f['date']}): {f['matched_line']}")
        lines.append("")

    print("\n".join(lines))

PYEOF
)"

# ---------------------------------------------------------------------------
# Output handling
# ---------------------------------------------------------------------------

if [[ -n "$OUTPUT_PATH" ]]; then
  echo "$report" > "$OUTPUT_PATH"
  log_info "Report written to: ${OUTPUT_PATH}"
else
  echo "$report"
fi

log_info "Analysis complete."
