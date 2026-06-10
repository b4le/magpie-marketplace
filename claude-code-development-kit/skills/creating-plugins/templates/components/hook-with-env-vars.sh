#!/bin/bash
# Hook script with environment variables

echo "Plugin root: ${CLAUDE_PLUGIN_ROOT}"
echo "Project dir: ${CLAUDE_PROJECT_DIR}"
echo "Config dir: ${CLAUDE_CONFIG_DIR}"

# Load plugin utilities
source "${CLAUDE_PLUGIN_ROOT}/utils.sh"

# Check project configuration
if [ -f "${CLAUDE_PROJECT_DIR}/.claude/CLAUDE.md" ]; then
  echo "Project has memory file"
fi