#!/usr/bin/env bash
set -euo pipefail

# harvest.sh - Stage 3: Copy included sources to local staging area
# Reads ranked.json (from triage stage) and copies files marked with decision="include"
# Creates manifest.json documenting all harvested files

# Configuration
HARVEST_DIR=".harvest/sources"
MANIFEST_FILE=".harvest/manifest.json"

# Create workspace directory
mkdir -p "$HARVEST_DIR"

# Determine input source
if [[ -n "${1:-}" && -f "$1" ]]; then
    INPUT_FILE="$1"
else
    INPUT_FILE="/dev/stdin"
fi

# Temporary file for manifest entries (as JSON array)
MANIFEST_ENTRIES=$(mktemp)
trap "rm -f '$MANIFEST_ENTRIES'" EXIT

# Initialize the manifest entries array
echo "[]" > "$MANIFEST_ENTRIES"

# Process each entry with decision="include"
# Using jq to transform entries into a flattened structure for processing
jq -r '.[] | select(.decision=="include") | "\(.id)|\(.path)|\(.metadata.size_bytes // 0)"' < "$INPUT_FILE" | while IFS='|' read -r id source_path size_bytes; do
    # Validate that source file exists and path doesn't contain dangerous characters
    if [[ ! -f "$source_path" ]]; then
        echo "WARNING: Source file not found: $source_path (id: $id)" >&2
        continue
    fi

    # Enhanced path validation: check for dangerous shell metacharacters
    # Reject paths with: $ ` \ " ; | & < > ( ) { } newlines
    if [[ "$source_path" =~ [\$\`\\\"\;\|\&\<\>\(\)\{\}] ]] || [[ "$source_path" =~ $'\n' ]] || [[ "$source_path" =~ $'\r' ]]; then
        echo "WARNING: Skipping file with dangerous characters in path: $source_path" >&2
        continue
    fi

    # Additional check: reject null bytes (shouldn't appear in normal paths)
    if [[ "$source_path" == *$'\0'* ]]; then
        echo "WARNING: Skipping file with null byte in path: $source_path" >&2
        continue
    fi

    # Extract filename from path and create subdirectory for this source
    filename=$(basename "$source_path")
    source_subdir="$HARVEST_DIR/$id"
    mkdir -p "$source_subdir"

    # Copy file preserving timestamps
    if cp -p "$source_path" "$source_subdir/$filename" 2>/dev/null; then
        harvest_path="$source_subdir/$filename"

        # Append entry to manifest entries array using jq
        jq \
            --arg id "$id" \
            --arg source_path "$source_path" \
            --arg harvest_path "$harvest_path" \
            --arg size_bytes "$size_bytes" \
            '. += [{
                id: $id,
                source_path: $source_path,
                harvest_path: $harvest_path,
                size_bytes: ($size_bytes | tonumber)
            }]' \
            "$MANIFEST_ENTRIES" > "$MANIFEST_ENTRIES.tmp" && \
            mv "$MANIFEST_ENTRIES.tmp" "$MANIFEST_ENTRIES"

        echo "Copied: $id -> $harvest_path" >&2
    else
        echo "ERROR: Failed to copy file: $source_path (id: $id)" >&2
        continue
    fi
done

# Read manifest entries and generate final manifest.json
FILES_HARVESTED=$(jq 'length' "$MANIFEST_ENTRIES")
TOTAL_SIZE=$(jq '[.[].size_bytes] | add // 0' "$MANIFEST_ENTRIES")

# Generate manifest.json with all harvested file entries
jq -n \
    --arg timestamp "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --arg files_harvested "$FILES_HARVESTED" \
    --arg total_size "$TOTAL_SIZE" \
    --slurpfile files "$MANIFEST_ENTRIES" \
    '{
        harvest_timestamp: $timestamp,
        files_harvested: ($files_harvested | tonumber),
        total_size_bytes: ($total_size | tonumber),
        files: $files[0]
    }' > "$MANIFEST_FILE"

# Report results
echo "Harvest complete: $FILES_HARVESTED files copied to $HARVEST_DIR" >&2
echo "Total size: $TOTAL_SIZE bytes" >&2
echo "Manifest: $MANIFEST_FILE" >&2

exit 0
