#!/bin/bash
# Plugin Hook Template
# ⚠️ SECURITY WARNING: Review this script carefully before use

# Hook Configuration
# This script demonstrates a pre-commit hook with safety checks

# Exit immediately on any error
set -e

# Debugging: Uncomment to enable verbose output
# set -x

# Environment Variables
echo "Plugin root: ${CLAUDE_PLUGIN_ROOT}"
echo "Project dir: ${CLAUDE_PROJECT_DIR}"
echo "Config dir: ${CLAUDE_CONFIG_DIR}"

# Safety: Validate inputs before processing
if [ -z "$CLAUDE_PROJECT_DIR" ]; then
    echo "Error: No project directory specified"
    exit 1
fi

# Example pre-commit hook functionality
main() {
    echo "Running pre-commit hook..."

    # Linting check
    echo "Running linter..."
    if command -v npm &> /dev/null; then
        npm run lint
    else
        echo "Warning: npm not found, skipping linter"
    fi

    # Test check
    echo "Running tests..."
    if command -v npm &> /dev/null; then
        npm test
    else
        echo "Warning: npm not found, skipping tests"
    fi

    # Additional custom checks can be added here
}

# Run main function and capture its exit status
main || {
    echo "Pre-commit hook failed"
    exit 1
}

# Exit with success
exit 0

# Security Recommendations:
# 1. Always validate and sanitize inputs
# 2. Use command -v to check for command availability
# 3. Set -e to exit on errors
# 4. Avoid using sudo in hooks
# 5. Limit filesystem and network access
# 6. Log activities securely
# 7. Never store secrets in hook scripts