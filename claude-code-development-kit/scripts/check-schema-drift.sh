#!/usr/bin/env bash
# =============================================================================
# check-schema-drift.sh
#
# Purpose: Detect drift between live JSON Schema files and the reference
#          property list in expected-fields.json. Run this after editing a
#          schema to confirm expected-fields.json is still in sync, or use
#          --update to regenerate the reference from current schemas.
#
# Usage:
#   ./check-schema-drift.sh [--update] [--help]
#
# Exit codes:
#   0  All schemas match expected-fields.json (or --update completed)
#   1  One or more schemas have drifted from expected-fields.json
#   2  Missing dependency (python3) or file not found
#
# Dependencies:
#   - python3 (stdlib json module only — no third-party packages required)
#
# Environment:
#   NO_COLOR  Set to any non-empty value to suppress ANSI color output
# =============================================================================

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCHEMAS_DIR="${SCRIPT_DIR}/../schemas"
readonly EXPECTED_FILE="${SCRIPT_DIR}/expected-fields.json"
readonly SCRIPT_NAME="$(basename -- "${BASH_SOURCE[0]}")"

# ---------------------------------------------------------------------------
# Color helpers (respect NO_COLOR)
# ---------------------------------------------------------------------------

if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

log_ok()   { printf "${GREEN}  OK${RESET}  %s\n" "$*"; }
log_new()  { printf "${CYAN} NEW${RESET}  %s\n" "$*"; }
log_miss() { printf "${YELLOW}MISS${RESET}  %s\n" "$*"; }
log_err()  { printf "${RED}ERROR${RESET} %s\n" "$*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}Usage:${RESET}
  ${SCRIPT_NAME} [--update] [--help]

${BOLD}Description:${RESET}
  Compares the top-level properties of each JSON Schema in schemas/ against
  the reference list in scripts/expected-fields.json and reports any drift.

  NEW fields   — present in the schema but absent from expected-fields.json
                 Suggests the schema was extended; update the reference file.

  MISSING fields — present in expected-fields.json but absent from the schema
                   Suggests a field was removed; verify this is intentional.

${BOLD}Options:${RESET}
  --update    Regenerate expected-fields.json from current schemas and exit 0
  --help      Show this help message and exit

${BOLD}Environment:${RESET}
  NO_COLOR    Set to suppress ANSI color output

${BOLD}Exit codes:${RESET}
  0  All schemas match (or --update completed successfully)
  1  Drift detected in one or more schemas
  2  Missing dependency or required file not found
EOF
}

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

check_deps() {
  if ! command -v python3 &>/dev/null; then
    log_err "python3 is required but was not found in PATH."
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Extract top-level property names from a schema file via python3 stdlib
# Prints one property name per line, sorted.
# ---------------------------------------------------------------------------

extract_properties() {
  local schema_file="$1"
  python3 - "$schema_file" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    schema = json.load(f)

props = schema.get("properties", {})
for name in sorted(props.keys()):
    print(name)
PYEOF
}

# ---------------------------------------------------------------------------
# Extract expected property names for a given schema from expected-fields.json
# Prints one property name per line, sorted.
# ---------------------------------------------------------------------------

extract_expected() {
  local schema_name="$1"
  python3 - "$EXPECTED_FILE" "$schema_name" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

schema_name = sys.argv[2]
entry = data.get("schemas", {}).get(schema_name)
if entry is None:
    # Schema not tracked yet — return nothing so caller treats all fields as NEW
    sys.exit(0)

for name in sorted(entry.get("properties", [])):
    print(name)
PYEOF
}

# ---------------------------------------------------------------------------
# --update: rewrite expected-fields.json from current schema files
# ---------------------------------------------------------------------------

run_update() {
  if [[ ! -d "$SCHEMAS_DIR" ]]; then
    log_err "Schemas directory not found at: ${SCHEMAS_DIR}"
    exit 2
  fi

  local today
  today="$(python3 -c 'import datetime; print(datetime.date.today().isoformat())')"

  printf "Regenerating %s from current schemas...\n" "$EXPECTED_FILE"

  python3 - "$SCHEMAS_DIR" "$EXPECTED_FILE" "$today" <<'PYEOF'
import json, os, sys, glob

schemas_dir = sys.argv[1]
output_file = sys.argv[2]
today       = sys.argv[3]

result = {
    "_comment": "Expected top-level properties for each schema. Run scripts/check-schema-drift.sh to compare.",
    "_updated": today,
    "schemas": {}
}

for schema_path in sorted(glob.glob(os.path.join(schemas_dir, "*.schema.json"))):
    schema_name = os.path.basename(schema_path)
    # Skip helper/enum schemas that have no top-level properties block
    with open(schema_path) as f:
        schema = json.load(f)
    props = sorted(schema.get("properties", {}).keys())
    additional = schema.get("additionalProperties", True)
    result["schemas"][schema_name] = {
        "properties": props,
        "additionalProperties": additional
    }

with open(output_file, "w") as f:
    json.dump(result, f, indent=2)
    f.write("\n")

print(f"Updated {output_file} with {len(result['schemas'])} schema(s).")
PYEOF
}

# ---------------------------------------------------------------------------
# Main drift-check logic
# ---------------------------------------------------------------------------

run_check() {
  if [[ ! -f "$EXPECTED_FILE" ]]; then
    log_err "expected-fields.json not found at: ${EXPECTED_FILE}"
    log_err "Run with --update to generate it from current schemas."
    exit 2
  fi

  local drift_found=0
  local schema_count=0

  printf "${BOLD}Schema drift check${RESET} — comparing against %s\n\n" \
    "$(basename "$EXPECTED_FILE")"

  # Iterate over all *.schema.json files in the schemas directory
  while IFS= read -r -d '' schema_file; do
    local schema_name
    schema_name="$(basename "$schema_file")"

    # Skip helper schemas that carry no top-level properties (e.g. tools-enum)
    local actual_props
    actual_props="$(extract_properties "$schema_file")"
    if [[ -z "$actual_props" ]]; then
      continue
    fi

    (( schema_count++ )) || true

    local expected_props
    expected_props="$(extract_expected "$schema_name")"

    # If schema is not yet tracked, all fields are NEW, none MISSING
    if [[ -z "$expected_props" ]]; then
      drift_found=1
      printf "${BOLD}%s${RESET} (not in expected-fields.json)\n" "$schema_name"
      while IFS= read -r field; do
        log_new "  ${field}  (add to expected-fields.json, or run --update)"
      done <<< "$actual_props"
      continue
    fi

    # Compute NEW fields: in actual but not in expected
    local new_fields
    new_fields="$(comm -23 <(printf '%s\n' "$actual_props") \
                            <(printf '%s\n' "$expected_props"))"

    # Compute MISSING fields: in expected but not in actual
    local missing_fields
    missing_fields="$(comm -13 <(printf '%s\n' "$actual_props") \
                               <(printf '%s\n' "$expected_props"))"

    if [[ -z "$new_fields" && -z "$missing_fields" ]]; then
      log_ok "$schema_name"
    else
      drift_found=1
      printf "${BOLD}%s${RESET}\n" "$schema_name"
      if [[ -n "$new_fields" ]]; then
        while IFS= read -r field; do
          log_new "  ${field}  (add to expected-fields.json, or run --update)"
        done <<< "$new_fields"
      fi
      if [[ -n "$missing_fields" ]]; then
        while IFS= read -r field; do
          log_miss "  ${field}  (removed from schema — verify intentional)"
        done <<< "$missing_fields"
      fi
    fi

  done < <(find "$SCHEMAS_DIR" -maxdepth 1 -name '*.schema.json' -print0)

  printf "\n%d schema(s) checked.\n" "$schema_count"

  if [[ "$drift_found" -ne 0 ]]; then
    printf "\n${RED}Drift detected.${RESET} Run with --update to sync expected-fields.json.\n"
    return 1
  else
    printf "${GREEN}All schemas match expected-fields.json.${RESET}\n"
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

mode="check"

for arg in "$@"; do
  case "$arg" in
    --update) mode="update" ;;
    --help|-h) usage; exit 0 ;;
    *)
      log_err "Unknown argument: ${arg}"
      usage >&2
      exit 2
      ;;
  esac
done

check_deps

if [[ "$mode" == "update" ]]; then
  run_update
else
  run_check
fi
