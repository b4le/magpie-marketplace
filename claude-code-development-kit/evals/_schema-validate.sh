#!/bin/bash
# _schema-validate.sh - Shared schema validation functions for Claude Code validators
# Source this file from other validator scripts:
#   source "$(dirname "${BASH_SOURCE[0]}")/_schema-validate.sh"
#
# Provides:
#   validate_json_schema <schema-file> <json-file>
#   validate_frontmatter_schema <schema-file> <md-file>
#
# Return codes:
#   0 = validation passed
#   1 = validation failed (schema errors found)
#   2 = validation tool not available (fail-open)
#
# Environment variables:
#   REQUIRE_SCHEMA_VALIDATION=1  — fail-closed: treat missing tools as error (RC=1 instead of RC=2)
#                                  Set this in CI/eval runners to enforce schema validation.

# Schema directory (relative to this file)
_SCHEMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../schemas" && pwd)"

# Cache the tool-availability check so we only probe once per session
_SCHEMA_TOOL_CHECKED="${_SCHEMA_TOOL_CHECKED:-false}"
_SCHEMA_TOOL_AVAILABLE="${_SCHEMA_TOOL_AVAILABLE:-false}"

_check_schema_tools() {
    if [[ "$_SCHEMA_TOOL_CHECKED" == "true" ]]; then
        if [[ "$_SCHEMA_TOOL_AVAILABLE" == "true" ]]; then
            return 0
        elif [[ "${REQUIRE_SCHEMA_VALIDATION:-0}" == "1" ]]; then
            return 1
        else
            return 2
        fi
    fi
    _SCHEMA_TOOL_CHECKED=true

    if python3 -c "import jsonschema, json" 2>/dev/null; then
        _SCHEMA_TOOL_AVAILABLE=true
        return 0
    fi

    _SCHEMA_TOOL_AVAILABLE=false
    if [[ "${REQUIRE_SCHEMA_VALIDATION:-0}" == "1" ]]; then
        return 1
    fi
    return 2
}

# validate_json_schema <schema-file> <json-file>
# Validates a JSON file against a JSON Schema.
# Prints validation errors to stdout. Returns 0/1/2.
validate_json_schema() {
    local schema_file="$1"
    local json_file="$2"

    _check_schema_tools
    local _rc=$?
    if [[ $_rc -ne 0 ]]; then
        if [[ $_rc -eq 1 ]]; then
            echo "[SCHEMA] FAILED — python3 jsonschema required but not available (pip install jsonschema)"
            return 1
        fi
        echo "[SCHEMA] Skipped — python3 jsonschema not available (pip install jsonschema)"
        return 2
    fi

    local schema_dir
    schema_dir="$(cd "$(dirname "$schema_file")" && pwd)"

    python3 -W ignore::DeprecationWarning -c "
import sys, json, os
from jsonschema import Draft7Validator
try:
    from jsonschema import RefResolver
except ImportError:
    from referencing import Registry
    RefResolver = None

schema_path = sys.argv[1]
instance_path = sys.argv[2]
schema_dir = sys.argv[3]

with open(schema_path) as f:
    schema = json.load(f)
with open(instance_path) as f:
    instance = json.load(f)

import glob as g

# Pre-load all schemas in the directory, keyed by their \$id
store = {}
for sf in g.glob(os.path.join(schema_dir, '*.json')):
    with open(sf) as fh:
        s = json.load(fh)
    if '\$id' in s:
        store[s['\$id']] = s
    # Also key by bare filename for relative refs
    store[os.path.basename(sf)] = s

if RefResolver is not None:
    resolver = RefResolver(
        base_uri='file://' + schema_dir + '/',
        referrer=schema,
        store=store,
    )
    validator = Draft7Validator(schema, resolver=resolver)
else:
    # jsonschema >= 4.18 uses referencing
    import referencing, referencing.jsonschema, pathlib
    def retrieve(uri):
        # Strip common \$id base URIs to resolve to local filenames
        for prefix in ['https://claude.ai/schemas/', 'file://' + schema_dir + '/']:
            if uri.startswith(prefix):
                uri = uri[len(prefix):]
                break
        path = pathlib.Path(schema_dir) / uri
        with open(path) as f:
            contents = json.load(f)
        return referencing.Resource.from_contents(contents)
    registry = Registry(retrieve=retrieve)
    validator = Draft7Validator(schema, registry=registry)

errors = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
if errors:
    for e in errors[:10]:
        path = '/'.join(str(p) for p in e.path) or '(root)'
        print(f'Schema error at {path}: {e.message}')
    sys.exit(1)
sys.exit(0)
" "$schema_file" "$json_file" "$schema_dir" 2>&1
    return $?
}

# validate_frontmatter_schema <schema-file> <md-file>
# Extracts YAML frontmatter from a markdown file, converts to JSON,
# and validates against a JSON Schema. Returns 0/1/2.
validate_frontmatter_schema() {
    local schema_file="$1"
    local md_file="$2"

    _check_schema_tools
    local _rc=$?
    if [[ $_rc -ne 0 ]]; then
        if [[ $_rc -eq 1 ]]; then
            echo "[SCHEMA] FAILED — python3 jsonschema required but not available (pip install jsonschema)"
            return 1
        fi
        echo "[SCHEMA] Skipped — python3 jsonschema not available (pip install jsonschema)"
        return 2
    fi

    # Also need pyyaml for frontmatter conversion
    if ! python3 -c "import yaml" 2>/dev/null; then
        if [[ "${REQUIRE_SCHEMA_VALIDATION:-0}" == "1" ]]; then
            echo "[SCHEMA] FAILED — python3 pyyaml required but not available (pip install pyyaml)"
            return 1
        fi
        echo "[SCHEMA] Skipped — python3 pyyaml not available (pip install pyyaml)"
        return 2
    fi

    local schema_dir
    schema_dir="$(cd "$(dirname "$schema_file")" && pwd)"

    # Extract frontmatter with awk, pipe to Python for YAML→JSON→validate
    local frontmatter
    frontmatter=$(awk '/^---$/{if(++n==2)exit;next}n==1' "$md_file")

    if [[ -z "$frontmatter" ]]; then
        echo "Schema error: No YAML frontmatter found"
        return 1
    fi

    echo "$frontmatter" | python3 -W ignore::DeprecationWarning -c "
import sys, json, os, yaml, datetime
from jsonschema import Draft7Validator
try:
    from jsonschema import RefResolver
except ImportError:
    from referencing import Registry
    RefResolver = None

schema_path = sys.argv[1]
schema_dir = sys.argv[2]

frontmatter_yaml = sys.stdin.read()
instance = yaml.safe_load(frontmatter_yaml)
if instance is None:
    instance = {}

# PyYAML auto-converts dates to datetime.date objects; convert back to ISO strings
def stringify_dates(obj):
    if isinstance(obj, dict):
        return {k: stringify_dates(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [stringify_dates(v) for v in obj]
    if isinstance(obj, (datetime.date, datetime.datetime)):
        return obj.isoformat()
    return obj
instance = stringify_dates(instance)

with open(schema_path) as f:
    schema = json.load(f)

import glob as g

# Pre-load all schemas in the directory, keyed by their \$id
store = {}
for sf in g.glob(os.path.join(schema_dir, '*.json')):
    with open(sf) as fh:
        s = json.load(fh)
    if '\$id' in s:
        store[s['\$id']] = s
    store[os.path.basename(sf)] = s

if RefResolver is not None:
    resolver = RefResolver(
        base_uri='file://' + schema_dir + '/',
        referrer=schema,
        store=store,
    )
    validator = Draft7Validator(schema, resolver=resolver)
else:
    import referencing, referencing.jsonschema, pathlib
    def retrieve(uri):
        # Strip common \$id base URIs to resolve to local filenames
        for prefix in ['https://claude.ai/schemas/', 'file://' + schema_dir + '/']:
            if uri.startswith(prefix):
                uri = uri[len(prefix):]
                break
        path = pathlib.Path(schema_dir) / uri
        with open(path) as f:
            contents = json.load(f)
        return referencing.Resource.from_contents(contents)
    registry = Registry(retrieve=retrieve)
    validator = Draft7Validator(schema, registry=registry)

errors = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
if errors:
    for e in errors[:10]:
        path = '/'.join(str(p) for p in e.path) or '(root)'
        print(f'Schema error at {path}: {e.message}')
    sys.exit(1)
sys.exit(0)
" "$schema_file" "$schema_dir" 2>&1
    return $?
}
