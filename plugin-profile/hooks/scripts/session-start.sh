#!/bin/bash
# SessionStart hook for plugin-profile
# Detects when a project has no plugin configuration and suggests running /plugin-profile:init

# Check if .claude/settings.local.json exists and has at least one entry in enabledPlugins.
# If not, emit a hookSpecificOutput reminder to the user via Claude's additionalContext field.

if test -f .claude/settings.local.json && \
   jq -e '.enabledPlugins | length > 0' .claude/settings.local.json > /dev/null 2>&1; then
  # Plugin configuration already present — do nothing
  exit 0
fi

# No plugin configuration found — surface a suggestion to the user
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<system-reminder>New project detected without plugin configuration. Consider suggesting: /plugin-profile:init</system-reminder>"}}
EOF
