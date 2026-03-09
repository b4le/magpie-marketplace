#!/usr/bin/env bash
# budget-tracker.sh — UserPromptSubmit command hook
# Reads budget state from /tmp/ and emits threshold warnings via additionalContext.
# Exits silently when no budget file exists (unmanaged session).
#
# Output key: additionalContext (runtime warnings visible to the model)

set -Eeuo pipefail

# Fail-open: any error exits cleanly without disrupting the hook pipeline
trap 'exit 0' EXIT

# Consume stdin (hook input JSON — not used by this hook)
cat > /dev/null

# ---------------------------------------------------------------------------
# Locate the most recent budget state file
# ---------------------------------------------------------------------------
budget_dir="/tmp/claude-session-budget"

if [[ ! -d "$budget_dir" ]]; then
  exit 0
fi

# Pick the most recently modified budget.json across all session subdirectories
budget_file=""
while IFS= read -r -d '' candidate; do
  budget_file="$candidate"
  break
done < <(find "$budget_dir" -maxdepth 2 -name "budget.json" -print0 \
  | xargs -0 ls -t 2>/dev/null \
  | tr '\n' '\0' 2>/dev/null || true)

if [[ -z "$budget_file" || ! -f "$budget_file" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Read fields from budget.json
# ---------------------------------------------------------------------------
if ! jq empty "$budget_file" 2>/dev/null; then
  exit 0
fi

points_completed=$(jq -r '.points_completed // 0' "$budget_file")
points_in_progress=$(jq -r '.points_in_progress // 0' "$budget_file")
ceiling=$(jq -r '.budget_ceiling // 8' "$budget_file")

# Planned task names (status == "planned"), comma-separated
planned_names=$(jq -r '[.tasks[]? | select(.status == "planned") | .name] | join(", ")' "$budget_file")

# ---------------------------------------------------------------------------
# Calculate consumption
# ---------------------------------------------------------------------------
consumed=$(( points_completed + points_in_progress ))
remaining=$(( ceiling - consumed ))

# ---------------------------------------------------------------------------
# Apply thresholds and emit additionalContext
# ---------------------------------------------------------------------------
if (( consumed >= 8 )); then
  message=$(jq -rn \
    --argjson c "$consumed" \
    --argjson ceil "$ceiling" \
    '"Session budget exceeded: \($c)/\($ceil) points consumed. Recommend writing a handoff to ~/.claude/handoffs/ and ending the session. Use /handoff to create a structured handoff."')
  printf '{"additionalContext": %s}\n' "$(jq -rn --arg m "$message" '$m | @json')"

elif (( consumed >= 7 )); then
  message=$(jq -rn \
    --argjson c "$consumed" \
    --argjson ceil "$ceiling" \
    '"Session budget warning: \($c)/\($ceil) points consumed. Only simple tasks (1pt) should be attempted. Consider wrapping up current work."')
  printf '{"additionalContext": %s}\n' "$(jq -rn --arg m "$message" '$m | @json')"

elif (( consumed >= 5 )); then
  if [[ -n "$planned_names" ]]; then
    task_list="Remaining tasks: ${planned_names}"
  else
    task_list="No planned tasks remaining."
  fi
  message=$(jq -rn \
    --argjson c "$consumed" \
    --argjson ceil "$ceiling" \
    --argjson r "$remaining" \
    --arg t "$task_list" \
    '"Session budget: \($c)/\($ceil) points consumed. \($r) points of budget remaining. \($t)"')
  printf '{"additionalContext": %s}\n' "$(jq -rn --arg m "$message" '$m | @json')"

fi

# consumed < 5: exit silently (trap handles exit 0)
