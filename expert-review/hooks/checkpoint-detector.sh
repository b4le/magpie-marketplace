#!/bin/bash
# Minimal, thematic checkpoint detection
# Fires on Stop event, outputs suggestion only on clear review checkpoints

set -e

# Dependency check
command -v jq >/dev/null 2>&1 || { echo "jq required for checkpoint detection" >&2; exit 1; }

# Read the hook input (JSON with session context)
# Stop events may have empty/closed stdin - exit silently rather than error
# Use bash built-in read with timeout (macOS doesn't have GNU timeout)
if ! read -t 2 -r FIRST_LINE; then
  # No input available or stdin closed
  exit 0
fi

# Read remaining input (if any) with a reasonable limit
INPUT="$FIRST_LINE"
while IFS= read -t 1 -r LINE; do
  INPUT="$INPUT"$'\n'"$LINE"
  # Safety limit: ~100KB to prevent memory issues
  if [ ${#INPUT} -gt 102400 ]; then
    break
  fi
done

# Validate JSON before processing
if ! echo "$INPUT" | jq empty 2>/dev/null; then
  echo "Warning: Invalid JSON input, skipping checkpoint detection" >&2
  exit 0
fi

# Extract last response snippet if available
# Note: Stop event has limited transcript visibility
# Use safe array access pattern to handle missing/empty transcript
LAST_RESPONSE=$(echo "$INPUT" | jq -r '.transcript // [] | .[-1].content // ""' 2>/dev/null || echo "")

# If no transcript in input, exit silently
if [ -z "$LAST_RESPONSE" ]; then
  exit 0
fi

# Quick exit if not a checkpoint pattern
if ! echo "$LAST_RESPONSE" | grep -qiE \
  'ready for feedback|batch.*(complete|done)|shall i continue|awaiting.*input|checkpoint|ready for.*review'; then
  exit 0
fi

# It's a checkpoint - output simple suggestion to stderr
echo "──────────────────────────────────────" >&2
echo "Review checkpoint detected." >&2
echo "Run: /expert-review" >&2
echo "──────────────────────────────────────" >&2

exit 0
