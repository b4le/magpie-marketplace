# Plugin Conflicts Reference

Known overlapping plugins that can cause confusion. When both are enabled, prefer the first option.

## High Severity (Same Functionality)

| Conflict | Plugins | Resolution |
|----------|---------|------------|
| Multi-agent Orchestration | `orchestration-toolkit@content-platform-marketplace` vs `agent-teams@claude-code-workflows` vs `agent-orchestration@claude-code-workflows` | Use `orchestration-toolkit` as primary |
| TDD Workflows | `superpowers@claude-plugins-official` vs `tdd-workflows@claude-code-workflows` | `superpowers` includes TDD; disable standalone |
| Debugging | `superpowers@claude-plugins-official` vs `debugging-toolkit@claude-code-workflows` | `superpowers` includes debugging; disable standalone |
| Code Review | `superpowers@claude-plugins-official` vs `comprehensive-review@claude-code-workflows` | Use `superpowers` for standard review |

## Medium Severity (Similar Purpose)

| Conflict | Plugins | Resolution |
|----------|---------|------------|
| Code Refactoring | `code-simplifier@claude-plugins-official` vs `code-refactoring@claude-code-workflows` | `code-simplifier` for simplification; `code-refactoring` for legacy modernization |
| Security | `security-guidance@claude-plugins-official` vs `developing-securely@content-platform-marketplace` vs `security-scanning@claude-code-workflows` | Different aspects; can coexist |

## How to Check for Conflicts

Run the validation script to detect conflicts in your current configuration:

```bash
./scripts/validate.sh /path/to/project
```

The script outputs JSON with any detected conflicts and suggested resolutions:
- Exit code 0: No conflicts
- Exit code 1: Conflicts found (advisory)
- Exit code 2: Error (missing jq, invalid JSON)

## Resolution Strategy

1. **Auto-resolve**: Profiles pre-emptively disable secondary plugins (see `core.yaml`)
2. **Interactive**: The SKILL.md workflow asks user when conflicts are detected
3. **Manual**: Edit `.claude/settings.local.json` to disable conflicting plugins

## LSP Plugins

Language Server Protocol (LSP) plugins do **not** conflict with each other. Each LSP handles a different language. However, the `core` profile disables all LSPs by default to avoid loading unnecessary servers. Language-specific profiles (python, typescript, etc.) enable the appropriate LSP.

## Conflict Pairs (Reference)

Documented conflict pairs for reference (validate.sh uses these internally):

```yaml
conflicts:
  - primary: superpowers@claude-plugins-official
    secondary: tdd-workflows@claude-code-workflows
    severity: high
  - primary: superpowers@claude-plugins-official
    secondary: debugging-toolkit@claude-code-workflows
    severity: high
  - primary: superpowers@claude-plugins-official
    secondary: comprehensive-review@claude-code-workflows
    severity: high
  - primary: orchestration-toolkit@content-platform-marketplace
    secondary: agent-teams@claude-code-workflows
    severity: high
  - primary: orchestration-toolkit@content-platform-marketplace
    secondary: agent-orchestration@claude-code-workflows
    severity: high
```
