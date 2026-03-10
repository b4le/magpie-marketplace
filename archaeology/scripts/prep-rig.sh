#!/bin/bash
# prep-rig.sh — prepare cleaned session files for spelunker agents
#
# Usage:
#   prep-rig.sh --sessions "/abs/a.jsonl,/abs/b.jsonl" \
#               --output-dir "/tmp/dig/slug/rigs/tunnel-id" \
#               [--slab-size 150] \
#               [--overlap 20] \
#               [--tunnel-id "tunnel-fan-out"] \
#               [--confidence "high,medium"]
#
# Exit 0: success (even if some sessions were skipped)
# Exit 1: fatal error (output dir not writable, slab write failure)
#
# Bash 3.2 compatible (macOS default)

# --------------------------------------------------------------------------
# jq / jaq setup
# --------------------------------------------------------------------------

JQ="${JQ:-jaq}"
command -v "$JQ" >/dev/null 2>&1 || JQ="jq"
command -v "$JQ" >/dev/null 2>&1 || {
  printf "prep-rig: jq or jaq is required\n" >&2
  exit 1
}

# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------

SESSIONS=""
OUTPUT_DIR=""
SLAB_SIZE=150
OVERLAP=20
TUNNEL_ID=""
CONFIDENCE_LIST=""

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --sessions)
      SESSIONS="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --slab-size)
      SLAB_SIZE="$2"
      shift 2
      ;;
    --overlap)
      OVERLAP="$2"
      shift 2
      ;;
    --tunnel-id)
      TUNNEL_ID="$2"
      shift 2
      ;;
    --confidence)
      CONFIDENCE_LIST="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      printf "prep-rig: unknown argument: %s\n" "$1" >&2
      exit 1
      ;;
  esac
done

# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------

if [ -z "$SESSIONS" ]; then
  printf "prep-rig: --sessions is required\n" >&2
  exit 1
fi

if [ -z "$OUTPUT_DIR" ]; then
  printf "prep-rig: --output-dir is required\n" >&2
  exit 1
fi

if ! printf '%s' "$SLAB_SIZE" | grep -qE '^[0-9]+$' || [ "$SLAB_SIZE" -lt 1 ]; then
  printf "prep-rig: --slab-size must be a positive integer, got: %s\n" "$SLAB_SIZE" >&2
  exit 1
fi

if ! printf '%s' "$OVERLAP" | grep -qE '^[0-9]+$'; then
  printf "prep-rig: --overlap must be a non-negative integer, got: %s\n" "$OVERLAP" >&2
  exit 1
fi

if [ "$OVERLAP" -ge "$SLAB_SIZE" ]; then
  printf "prep-rig: --overlap (%s) must be less than --slab-size (%s)\n" "$OVERLAP" "$SLAB_SIZE" >&2
  exit 1
fi

# --------------------------------------------------------------------------
# Output directory setup
# --------------------------------------------------------------------------

if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir -p -- "$OUTPUT_DIR" 2>/dev/null || {
    printf "prep-rig: cannot create output directory: %s\n" "$OUTPUT_DIR" >&2
    exit 1
  }
fi

if [ ! -w "$OUTPUT_DIR" ]; then
  printf "prep-rig: output directory not writable: %s\n" "$OUTPUT_DIR" >&2
  exit 1
fi

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

# warn — print a warning to stderr
warn() {
  printf "prep-rig: WARNING: %s\n" "$1" >&2
}

# session_slug — derive the slug from a session file path
# Strips directory and extension, returns the bare filename stem.
session_slug() {
  local path="$1"
  local base
  base=$(basename -- "$path")
  printf '%s' "${base%.jsonl}"
}

# split_csv — print each comma-separated field on its own line
split_csv() {
  printf '%s' "$1" | tr ',' '\n'
}

# nth_field — return the Nth (1-based) comma-separated field from a string
nth_field() {
  local str="$1"
  local n="$2"
  printf '%s' "$str" | tr ',' '\n' | sed -n "${n}p"
}

# --------------------------------------------------------------------------
# Process sessions
# --------------------------------------------------------------------------

# Build parallel arrays from comma-separated inputs.
# Bash 3.2 has no associative arrays, so we track session list as
# newline-delimited variables and index by position.

session_paths=""
session_confidences=""
session_count=0

while IFS= read -r path; do
  [ -z "$path" ] && continue
  session_count=$((session_count + 1))
  if [ -z "$session_paths" ]; then
    session_paths="$path"
  else
    session_paths="${session_paths}
${path}"
  fi
done <<EOF
$(split_csv "$SESSIONS")
EOF

# Build confidence list (same order as sessions)
confidence_count=0
while IFS= read -r conf; do
  [ -z "$conf" ] && continue
  confidence_count=$((confidence_count + 1))
  if [ -z "$session_confidences" ]; then
    session_confidences="$conf"
  else
    session_confidences="${session_confidences}
${conf}"
  fi
done <<EOF
$(split_csv "$CONFIDENCE_LIST")
EOF

# --------------------------------------------------------------------------
# Manifest accumulation
# --------------------------------------------------------------------------

# We build the slabs JSON array incrementally as a newline-delimited list
# of JSON objects, then assemble them at the end.
MANIFEST_SLABS=""
SLABS_WRITTEN=0

# --------------------------------------------------------------------------
# Main processing loop
# --------------------------------------------------------------------------

session_index=0

while IFS= read -r session_path; do
  [ -z "$session_path" ] && continue
  session_index=$((session_index + 1))

  # Resolve confidence for this session (default: "medium" if not supplied)
  session_confidence=$(printf '%s\n' "$session_confidences" | sed -n "${session_index}p")
  if [ -z "$session_confidence" ]; then
    session_confidence="medium"
  fi

  # Check file exists
  if [ ! -f "$session_path" ]; then
    warn "session file not found, skipping: ${session_path}"
    continue
  fi

  slug=$(session_slug "$session_path")

  # ------------------------------------------------------------------
  # Step 1 & 2: Parse JSONL and strip tool_result/tool_use noise.
  #
  # Strategy:
  #   - Skip lines that are not valid JSON (warn)
  #   - Exclude top-level messages where type == "tool_result"
  #   - For assistant messages with content arrays, strip content blocks
  #     where type is "tool_result" or "tool_use" AND the block's string
  #     content (text field) exceeds 500 characters
  #   - Keep all other messages intact
  # ------------------------------------------------------------------

  stripped_tmp=$(mktemp "${OUTPUT_DIR}/.strip-${slug}.XXXXXX")

  # Process line by line: validate JSON, apply stripping filter
  line_num=0
  while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))
    [ -z "$line" ] && continue

    # Validate JSON
    if ! printf '%s\n' "$line" | "$JQ" empty 2>/dev/null; then
      warn "malformed JSON at line ${line_num} in ${session_path}, skipping line"
      continue
    fi

    # Apply stripping filter via jq
    result=$(printf '%s\n' "$line" | "$JQ" -c '
      # Skip top-level tool_result messages entirely
      if .type == "tool_result" then empty

      # For assistant messages, strip noisy content blocks from content arrays
      elif .type == "assistant" then
        if (.message.content | type) == "array" then
          .message.content |= [
            .[] |
            if (type == "object") and
               (.type == "tool_result" or .type == "tool_use") and
               ((.text // (.content // "") | tostring | length) > 500)
            then empty
            else .
            end
          ] |
          # Re-wrap in message envelope
          . as $content |
          # Return full message with filtered content
          input_line_number as $_ |
          .
        else .
        end

      # All other message types pass through unchanged
      else .
      end
    ' 2>/dev/null)

    # jq outputs nothing (empty) for filtered-out messages — that is correct
    if [ -n "$result" ]; then
      printf '%s\n' "$result" >> "$stripped_tmp"
    fi
  done < "$session_path"

  # Count messages in stripped output
  msg_count=0
  while IFS= read -r _line; do
    [ -n "$_line" ] && msg_count=$((msg_count + 1))
  done < "$stripped_tmp"

  if [ "$msg_count" -eq 0 ]; then
    warn "session is empty after stripping, skipping: ${session_path}"
    rm -f -- "$stripped_tmp"
    continue
  fi

  # ------------------------------------------------------------------
  # Step 3 & 4: Slab the stripped messages and write slab files
  # ------------------------------------------------------------------

  if [ "$msg_count" -le "$SLAB_SIZE" ]; then
    # Single slab — all messages
    slab_file="${OUTPUT_DIR}/${slug}-slab-0.jsonl"
    slab_tmp="${slab_file}.tmp"

    cp -- "$stripped_tmp" "$slab_tmp" || {
      printf "prep-rig: failed to write slab tmp: %s\n" "$slab_tmp" >&2
      rm -f -- "$stripped_tmp" "$slab_tmp"
      exit 1
    }

    mv -- "$slab_tmp" "$slab_file" || {
      printf "prep-rig: failed to rename slab: %s\n" "$slab_file" >&2
      rm -f -- "$stripped_tmp" "$slab_tmp"
      exit 1
    }

    # Append manifest slab entry
    slab_entry=$(
      "$JQ" -n \
        --arg slab_file "$slab_file" \
        --arg source_session "$session_path" \
        --arg range "all" \
        --argjson message_count "$msg_count" \
        --arg confidence "$session_confidence" \
        '{
          slab_file: $slab_file,
          source_session: $source_session,
          range: $range,
          message_count: $message_count,
          confidence: $confidence
        }'
    )

    if [ -z "$MANIFEST_SLABS" ]; then
      MANIFEST_SLABS="$slab_entry"
    else
      MANIFEST_SLABS="${MANIFEST_SLABS}
${slab_entry}"
    fi
    SLABS_WRITTEN=$((SLABS_WRITTEN + 1))

  else
    # Multiple overlapping slabs
    stride=$((SLAB_SIZE - OVERLAP))
    slab_index=0
    window_start=0

    # Read all stripped messages into a temp file for indexed access
    # We will use line-number access (sed -n) to extract windows
    while [ "$window_start" -lt "$msg_count" ]; do
      window_end=$((window_start + SLAB_SIZE - 1))
      if [ "$window_end" -ge "$msg_count" ]; then
        window_end=$((msg_count - 1))
      fi

      slab_file="${OUTPUT_DIR}/${slug}-slab-${slab_index}.jsonl"
      slab_tmp="${slab_file}.tmp"

      # sed line numbers are 1-based; window_start is 0-based
      sed_start=$((window_start + 1))
      sed_end=$((window_end + 1))

      sed -n "${sed_start},${sed_end}p" "$stripped_tmp" > "$slab_tmp" || {
        printf "prep-rig: failed to write slab tmp: %s\n" "$slab_tmp" >&2
        rm -f -- "$stripped_tmp" "$slab_tmp"
        exit 1
      }

      # Count actual lines written (last window may be shorter)
      actual_count=0
      while IFS= read -r _l; do
        [ -n "$_l" ] && actual_count=$((actual_count + 1))
      done < "$slab_tmp"

      mv -- "$slab_tmp" "$slab_file" || {
        printf "prep-rig: failed to rename slab: %s\n" "$slab_file" >&2
        rm -f -- "$stripped_tmp" "$slab_tmp"
        exit 1
      }

      # Build range string (1-based, human-readable)
      range_start=$((window_start + 1))
      range_end=$((window_end + 1))
      range_str="msg:${range_start}-${range_end}"

      slab_entry=$(
        "$JQ" -n \
          --arg slab_file "$slab_file" \
          --arg source_session "$session_path" \
          --arg range "$range_str" \
          --argjson message_count "$actual_count" \
          --arg confidence "$session_confidence" \
          '{
            slab_file: $slab_file,
            source_session: $source_session,
            range: $range,
            message_count: $message_count,
            confidence: $confidence
          }'
      )

      if [ -z "$MANIFEST_SLABS" ]; then
        MANIFEST_SLABS="$slab_entry"
      else
        MANIFEST_SLABS="${MANIFEST_SLABS}
${slab_entry}"
      fi
      SLABS_WRITTEN=$((SLABS_WRITTEN + 1))

      slab_index=$((slab_index + 1))
      window_start=$((window_start + stride))

      # Stop if the last window already covered to end-of-file
      if [ "$window_end" -ge "$((msg_count - 1))" ]; then
        break
      fi
    done
  fi

  rm -f -- "$stripped_tmp"

done <<EOF
$session_paths
EOF

# --------------------------------------------------------------------------
# Step 5: Write manifest.json (atomic)
# --------------------------------------------------------------------------

manifest_path="${OUTPUT_DIR}/manifest.json"
manifest_tmp="${manifest_path}.tmp"

generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build slabs JSON array from accumulated newline-delimited objects
if [ -z "$MANIFEST_SLABS" ]; then
  slabs_json="[]"
else
  # Each line is a valid JSON object; wrap in array
  slabs_json=$(printf '%s\n' "$MANIFEST_SLABS" | "$JQ" -s '.')
fi

"$JQ" -n \
  --arg tunnel_id "$TUNNEL_ID" \
  --arg generated_at "$generated_at" \
  --argjson slabs "$slabs_json" \
  '{
    tunnel_id: $tunnel_id,
    generated_at: $generated_at,
    slabs: $slabs
  }' > "$manifest_tmp" || {
  printf "prep-rig: failed to write manifest tmp: %s\n" "$manifest_tmp" >&2
  rm -f -- "$manifest_tmp"
  exit 1
}

mv -- "$manifest_tmp" "$manifest_path" || {
  printf "prep-rig: failed to rename manifest: %s\n" "$manifest_path" >&2
  rm -f -- "$manifest_tmp"
  exit 1
}

printf "prep-rig: wrote %d slab(s) to %s\n" "$SLABS_WRITTEN" "$OUTPUT_DIR" >&2
printf "prep-rig: manifest: %s\n" "$manifest_path" >&2

exit 0
