# Design: Devkit Cron Maintenance

**Date:** 2026-03-10
**Status:** Approved

## Problem

The claude-code-development-kit has comprehensive maintenance infrastructure (changelog sync, schema drift detection, validators, devkit-maintainer agent) but relies entirely on manual triggers or session-start hooks. Claude Code releases updates regularly, and schema/validator drift accumulates silently between manual maintenance runs.

## Solution

A two-phase hybrid pipeline that runs daily via macOS launchd:

- **Phase 1 (shell):** Cheap detection using existing scripts — no API tokens consumed
- **Phase 2 (Claude Code):** Only spawned when changes are detected — applies safe auto-fixes and reports on manual-review items

## Architecture

```
launchd (daily)
  └─ devkit-cron.sh
       ├─ Phase 1: Shell Detection
       │    ├─ fetch-changelog.sh --since <last-run>
       │    ├─ analyze-sync.sh --since <last-run> --json
       │    ├─ check-schema-drift.sh
       │    └─ Decision gate: any actionable findings?
       │         ├─ No  → log "no changes", update last-run, exit 0
       │         └─ Yes → proceed to Phase 2
       │
       └─ Phase 2: Claude Code Session
            ├─ claude -p "run devkit-maintainer sync+audit with this report: <phase1-report>"
            ├─ Agent applies safe auto-fixes
            ├─ Creates branch: devkit/auto-update-YYYY-MM-DD
            └─ Writes summary report
```

## Components

### 1. `devkit-cron.sh` — Orchestrator Script

**Location:** `claude-code-development-kit/scripts/devkit-cron.sh`

**Responsibilities:**
- Read last-run timestamp from state file
- Execute Phase 1 detection scripts sequentially
- Parse results for actionable items
- If changes found: spawn Claude Code session with Phase 1 report as context
- Update last-run timestamp
- Write execution log

**State files:**
- `local-state/devkit-cron/last-run` — ISO 8601 timestamp of last successful run
- `local-state/devkit-cron/reports/YYYY-MM-DD.md` — daily report (kept 30 days)
- `local-state/devkit-cron/reports/YYYY-MM-DD-phase1.json` — raw Phase 1 output

### 2. Phase 1: Detection

Reuses existing scripts with no modification:

| Script | Purpose | Actionable signal |
|--------|---------|-------------------|
| `fetch-changelog.sh --since <date>` | New releases since last run | Any new entries found |
| `analyze-sync.sh --since <date> --json` | Schema gap analysis | "Action Required" or "Needs Review" items |
| `check-schema-drift.sh` | Field drift from baseline | Exit code 1 (drift detected) |

**Decision gate:** If all three report no actionable items, skip Phase 2.

### 3. Phase 2: Claude Code Session

**Trigger command:**
```bash
claude -p "<prompt>" \
  --allowedTools "Read,Write,Edit,Bash,Glob,Grep,WebFetch,WebSearch" \
  --dangerously-skip-permissions
```

**Prompt template:** Instructs the devkit-maintainer to:
1. Read the Phase 1 report from disk
2. Run sync mode to apply safe auto-fixes (version fields, enum updates, kebab-case, tool enums, missing model_rationale)
3. Run audit mode to validate all components post-fix
4. Create a git branch `devkit/auto-update-YYYY-MM-DD`
5. Commit changes with descriptive message
6. Write a summary report listing: what was auto-fixed, what needs manual review

**Safe auto-fix scope** (from devkit's existing auto-fix catalog):
- Version field updates
- Field name normalization (kebab-case)
- Tool enum updates (adding new tools to tools-enum.json)
- Missing model_rationale field addition
- expected-fields.json regeneration

**Requires manual review** (reported but not auto-fixed):
- Description rewrites
- Tool list changes on agents/skills
- Permission mode changes
- Structural schema changes
- File deletion

### 4. `com.magpie.devkit-cron.plist` — launchd Configuration

**Location:** `claude-code-development-kit/scripts/com.magpie.devkit-cron.plist`

**Schedule:** Daily at 08:00 local time
**Working directory:** Project root
**Stdout/stderr:** Logged to `local-state/devkit-cron/launchd.log`

### 5. Installation Script

**Location:** `claude-code-development-kit/scripts/install-cron.sh`

**Actions:**
- Validates prerequisites (claude CLI, scripts exist, permissions)
- Creates `local-state/devkit-cron/` directory structure
- Copies plist to `~/Library/LaunchAgents/`
- Loads the agent via `launchctl load`
- Seeds initial last-run timestamp

**Uninstall:** `install-cron.sh --uninstall` reverses the process.

## File Layout

```
claude-code-development-kit/
├── scripts/
│   ├── devkit-cron.sh              # NEW — orchestrator
│   ├── install-cron.sh             # NEW — install/uninstall helper
│   ├── com.magpie.devkit-cron.plist # NEW — launchd plist
│   ├── fetch-changelog.sh          # existing
│   ├── analyze-sync.sh             # existing
│   └── check-schema-drift.sh       # existing
└── local-state/
    └── devkit-cron/
        ├── last-run                 # timestamp
        ├── launchd.log              # stdout/stderr
        └── reports/
            ├── 2026-03-10.md        # human-readable report
            └── 2026-03-10-phase1.json # raw detection output
```

## Error Handling

- **Network failure in Phase 1:** `fetch-changelog.sh` exits 3 — script logs warning, skips Phase 2, does NOT update last-run (will retry next day)
- **Claude Code unavailable:** Phase 2 fails — script logs error, does NOT update last-run
- **Partial Phase 2 failure:** Any git changes are on a branch, never touching main
- **Report retention:** Reports older than 30 days auto-deleted on each run

## Security Considerations

- `--dangerously-skip-permissions` is scoped: only runs in the devkit project directory
- Phase 2 prompt is hardcoded in the script (not user-injectable)
- Git changes are always on a branch, never force-pushed
- `GITHUB_TOKEN` can be set in environment for API rate limits but is optional

## Future Extensions

- Slack notification when manual-review items are found
- PR auto-creation via `gh pr create`
- Cross-project devkit sync (if multiple projects use the kit)
