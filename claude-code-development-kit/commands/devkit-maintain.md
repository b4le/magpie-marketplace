---
name: devkit-maintain
description: Run devkit maintenance — audit, sync, validate, cleanup, or full pass
argument-hint: "[mode: audit|sync|validate|cleanup|full]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - WebFetch
  - WebSearch
user-invocable: true
version: 1.0.0
---

Run maintenance on the claude-code-development-kit plugin.

Parse the mode from `$ARGUMENTS`. If no mode is provided, default to `full`.

Valid modes: `audit`, `sync`, `validate`, `cleanup`, `full`.

If the provided mode is not one of the above, respond with an error listing the valid modes and do not proceed.

Load the maintaining-devkit skill for structured playbooks:
@${CLAUDE_PLUGIN_ROOT}/skills/maintaining-devkit/SKILL.md

For the `audit` mode:
1. Run: `bash ${CLAUDE_PLUGIN_ROOT}/evals/validate-plugin.sh ${CLAUDE_PLUGIN_ROOT}`
2. Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-schema-drift.sh`
3. Report results in the structured format from the skill.

For the `sync` mode:
1. Search for the latest Claude Code changelog
2. Compare findings against schemas in `${CLAUDE_PLUGIN_ROOT}/schemas/`
3. Flag drift and propose patches per the changelog-sync-playbook

For the `validate` mode:
1. If `$ARGUMENTS` includes a component path, validate that specific component
2. Otherwise, ask which component to validate
3. Run the appropriate validator from `${CLAUDE_PLUGIN_ROOT}/evals/`

For the `cleanup` mode:
1. Audit `~/.claude/` following the setup-hygiene-checklist
2. Report findings with prioritized recommendations

For the `full` mode:
1. Run audit → sync → validate (failed components) → cleanup in sequence
2. Apply safe auto-fixes per the auto-fix-catalog
3. Re-validate fixed components
4. Present comprehensive maintenance report
