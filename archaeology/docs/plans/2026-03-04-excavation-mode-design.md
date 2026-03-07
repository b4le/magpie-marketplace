# Excavation Mode Design

> Cross-project portfolio scan for archaeology. Discovers all projects, runs survey on each, produces a portfolio view.

## Architecture

Three components with clean separation:

```
/archaeology excavation [--dry-run] [--max-concurrent N] [--scan-paths "path1,path2"]
       |
       v
+---------------------------+
|  SKILL.md excavation      |  ~30 words routing
|  routing                  |  references/audit-workflow.md
+-------------+-------------+
              | Bash tool
              v
+-------------------------------------+
|  scripts/archaeology-excavation.sh  |  Shell script (~200 lines)
|                                     |
|  1. Discover projects               |  find dirs with .claude/
|  2. Filter (ignore, freshness)      |  check ignore list + survey age
|  3. Launch claude -p per project    |  bash wait -n concurrency
|  4. Track progress + failures       |  stdout: JSON manifest
+-------------+-----------------------+
              | Script stdout (JSON)
              v
+-------------------------------------+
|  Audit workflow (skill context)     |  references/audit-workflow.md
|                                     |
|  1. Parse script results            |
|  2. Read all survey.md files        |
|  3. Synthesise portfolio.md         |  LLM-powered cross-project
|  4. Display completion summary      |
+-------------------------------------+
```

**Principle:** Shell script handles subprocess management. Skill handles intelligence.

## Project Discovery

Default scan paths (configurable via `--scan-paths`):
- `~/Personal/`
- `~/Spotify/`
- `~/ai-playground/`
- `~/Playground/`
- `~/TeamExperimentation/`

Detection signal: `.claude/` directory exists (has Claude history).

Filtering:
- Skip paths in `~/.claude/archaeology-ignore` (one per line)
- Skip `~/.claude` itself and anything under it
- Skip if `survey.md` exists in central work-log AND is < 7 days old (configurable via `--max-age`)

## Shell Script: `archaeology-excavation.sh`

### Interface

```bash
archaeology-excavation.sh [OPTIONS]
  --scan-paths "path1,path2,..."   # Override default scan directories
  --max-concurrent N               # Parallel limit (default: 3)
  --max-age N                      # Skip surveys fresher than N days (default: 7)
  --dry-run                        # Discover + filter only, no launches
```

### Per-Project Subprocess

```bash
(cd "$project_dir" && command claude -p "/archaeology survey" \
  --dangerously-skip-permissions \
  --output-format json \
  --no-session-persistence \
  --add-dir "$HOME/.claude" \
  --max-budget-usd 2.00 \
  2>"$LOG_DIR/${slug}.err" \
  >"$LOG_DIR/${slug}.out")
```

### Concurrency: Bash `wait -n` Pattern

```bash
MAX_JOBS=3
for project in "${projects[@]}"; do
  run_survey "$project" &
  while (( $(jobs -rp | wc -l) >= MAX_JOBS )); do wait -n; done
done
wait
```

Direct exit code access per job, no external dependencies, easy progress tracking.

### Output: JSON Manifest to stdout

```json
{
  "timestamp": "2026-03-04T14:30:00Z",
  "projects_discovered": 20,
  "projects_skipped": 5,
  "projects_surveyed": 15,
  "projects_failed": 1,
  "results": [
    {"path": "/Users/.../talent-snapshots", "slug": "talent-snapshots", "status": "success"},
    {"path": "/Users/.../old-thing", "slug": "old-thing", "status": "skipped", "reason": "fresh_survey"},
    {"path": "/Users/.../broken", "slug": "broken", "status": "failed", "reason": "exit_code_1"}
  ]
}
```

Progress on stderr: `[3/15] Surveying talent-snapshots...`

Logs: `~/.claude/data/visibility-toolkit/work-log/archaeology/.excavation-logs/`

## Skill-Side Aggregation (`audit-workflow.md`)

After script completes:

1. **A1: Parse manifest** — read JSON from script stdout
2. **A2: Read surveys** — read all `survey.md` files from central work-log for successful projects
3. **A3: Extract data** — parse domain scores tables, project profiles, suggested dives from each survey
4. **A4: Synthesise** — LLM generates cross-project patterns and recommendations
5. **A5: Write portfolio** — `~/.claude/data/visibility-toolkit/work-log/archaeology/portfolio.md`
6. **A6: Display summary** — completion output with stats and file locations

## Portfolio Output Format

Location: `~/.claude/data/visibility-toolkit/work-log/archaeology/portfolio.md`

```markdown
# Archaeology Portfolio -- {date}

> Scanned {N} projects | {M} with signal | {K} newly surveyed | {F} failed

## Project Overview

| Project | Sessions | Top Domain | Signal | Last Survey | Action |
|---------|----------|------------|--------|-------------|--------|
| ...     | ...      | ...        | ...    | ...         | ...    |

## Cross-Project Patterns

[LLM-synthesised: domains appearing across projects, recurring uncovered tools]

## Recommended Next Steps

[Ranked: which project+domain first, new domains to create, projects to skip]

## Skipped & Failed

| Project | Reason |
|---------|--------|
| ...     | ...    |
```

## File Ownership

| File | Action |
|------|--------|
| `SKILL.md` | Add excavation routing (~30 words) |
| `references/audit-workflow.md` | New: aggregation + portfolio logic |
| `scripts/archaeology-excavation.sh` | New: discovery + concurrency script |
| `~/.claude/archaeology-ignore` | New: user-editable ignore list |
| `portfolio.md` (in work-log) | Generated output |

## Constraints

- SKILL.md must stay under 3,000 words
- Each project survey runs as independent `claude -p` process
- Default concurrency: 3 parallel sessions
- Must handle partial failures (some fail, report still generates)
- Audit always exports (portfolio depends on central work-log data)
- Discovery paths configurable (not hardcoded)

## Review Gates

1. **Shell scripting review** — bash-pro agent reviews excavation script
2. **Skill review** — skill-reviewer validates SKILL.md changes + audit-workflow.md
3. **Plugin validation** — plugin-validator checks overall structure

## Technical Foundation

- Claude CLI v2.1.63: `-p` for non-interactive, `--dangerously-skip-permissions` for tool access
- No `--cwd` flag — use `cd` in subshell
- `command claude` bypasses shell function wrapper
- `--no-session-persistence` avoids session clutter from audit runs
- `--max-budget-usd 2.00` caps per-project spend
- `--add-dir ~/.claude` ensures access to skill files and work-log
