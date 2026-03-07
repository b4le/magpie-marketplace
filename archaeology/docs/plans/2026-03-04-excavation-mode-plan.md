# Excavation Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `/archaeology excavation` mode that discovers all projects, runs survey on each via independent `claude -p` subprocesses, and generates a cross-project portfolio report.

**Architecture:** Shell script handles discovery + concurrency + subprocess management. Skill routes to the script via Bash tool, then reads survey.md outputs and synthesises a portfolio.md report using LLM reasoning. Reference doc `audit-workflow.md` contains the skill-side aggregation logic.

**Tech Stack:** Bash (POSIX-compatible where possible), Claude CLI (`claude -p`), jq-free JSON (printf-based)

---

### Task 1: Create the Excavation Shell Script

**Files:**
- Create: `~/.claude/skills/archaeology/scripts/archaeology-excavation.sh`

**Step 1: Write the script**

The script handles: discovery, filtering, concurrency, progress, and JSON manifest output.

```bash
#!/usr/bin/env bash
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────
DEFAULT_SCAN_PATHS="$HOME/Personal,$HOME/Spotify,$HOME/ai-playground,$HOME/Playground,$HOME/TeamExperimentation"
MAX_CONCURRENT=3
MAX_AGE_DAYS=7
DRY_RUN=false
IGNORE_FILE="$HOME/.claude/archaeology-ignore"
CENTRAL_BASE="$HOME/.claude/data/visibility-toolkit/work-log/archaeology"
LOG_DIR="$CENTRAL_BASE/.excavation-logs"

# ── Argument parsing ─────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan-paths)   SCAN_PATHS_ARG="$2"; shift 2 ;;
    --max-concurrent) MAX_CONCURRENT="$2"; shift 2 ;;
    --max-age)      MAX_AGE_DAYS="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=true; shift ;;
    *)              echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Split scan paths into array
IFS=',' read -ra SCAN_PATHS <<< "${SCAN_PATHS_ARG:-$DEFAULT_SCAN_PATHS}"

# ── Setup ────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"

# Load ignore list
IGNORE_PATTERNS=()
if [[ -f "$IGNORE_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    # Expand ~ to $HOME
    IGNORE_PATTERNS+=("${line/#\~/$HOME}")
  done < "$IGNORE_FILE"
fi

# ── Discovery ────────────────────────────────────────────────────────
discover_projects() {
  local projects=()
  for scan_path in "${SCAN_PATHS[@]}"; do
    [[ -d "$scan_path" ]] || continue
    # Find directories containing .claude/ (depth 1-2 under scan path)
    while IFS= read -r claude_dir; do
      local project_dir
      project_dir="$(dirname "$claude_dir")"

      # Skip ~/.claude itself and anything under it
      [[ "$project_dir" == "$HOME/.claude" ]] && continue
      [[ "$project_dir" == "$HOME/.claude/"* ]] && continue

      # Skip ignored paths
      local skip=false
      for pattern in "${IGNORE_PATTERNS[@]}"; do
        if [[ "$project_dir" == "$pattern" || "$project_dir" == "$pattern/"* ]]; then
          skip=true
          break
        fi
      done
      $skip && continue

      projects+=("$project_dir")
    done < <(find "$scan_path" -maxdepth 3 -name ".claude" -type d 2>/dev/null)
  done

  # Deduplicate
  printf '%s\n' "${projects[@]}" | sort -u
}

# ── Filtering ────────────────────────────────────────────────────────
to_slug() {
  local name
  name="$(basename "$1")"
  echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/^-//; s/-$//'
}

is_survey_fresh() {
  local slug="$1"
  local survey_file="$CENTRAL_BASE/$slug/survey.md"
  [[ -f "$survey_file" ]] || return 1

  local file_age_days
  if [[ "$(uname)" == "Darwin" ]]; then
    local file_mtime
    file_mtime=$(stat -f %m "$survey_file")
    local now
    now=$(date +%s)
    file_age_days=$(( (now - file_mtime) / 86400 ))
  else
    file_age_days=$(( ( $(date +%s) - $(stat -c %Y "$survey_file") ) / 86400 ))
  fi

  [[ $file_age_days -lt $MAX_AGE_DAYS ]]
}

# ── Subprocess launcher ──────────────────────────────────────────────
run_survey() {
  local project_dir="$1"
  local slug="$2"

  (cd "$project_dir" && command claude -p "/archaeology survey" \
    --dangerously-skip-permissions \
    --output-format json \
    --no-session-persistence \
    --add-dir "$HOME/.claude" \
    --max-budget-usd 2.00 \
    2>"$LOG_DIR/${slug}.err" \
    >"$LOG_DIR/${slug}.out")
}

# ── Main ─────────────────────────────────────────────────────────────
mapfile -t ALL_PROJECTS < <(discover_projects)

TOTAL=${#ALL_PROJECTS[@]}
SKIPPED=0
SURVEYED=0
FAILED=0

# Build results array (collected as newline-separated entries, assembled at end)
RESULTS=""

# Classify each project
declare -a TO_SURVEY=()
for project_dir in "${ALL_PROJECTS[@]}"; do
  slug=$(to_slug "$project_dir")

  if is_survey_fresh "$slug"; then
    RESULTS="${RESULTS}{\"path\":\"$project_dir\",\"slug\":\"$slug\",\"status\":\"skipped\",\"reason\":\"fresh_survey\"},"
    SKIPPED=$((SKIPPED + 1))
  else
    TO_SURVEY+=("$project_dir")
  fi
done

SURVEY_TOTAL=${#TO_SURVEY[@]}

if $DRY_RUN; then
  # Dry run: report what would be surveyed
  for project_dir in "${TO_SURVEY[@]}"; do
    slug=$(to_slug "$project_dir")
    RESULTS="${RESULTS}{\"path\":\"$project_dir\",\"slug\":\"$slug\",\"status\":\"would_survey\",\"reason\":null},"
  done
  # Output manifest
  RESULTS="${RESULTS%,}"  # Remove trailing comma
  cat <<MANIFEST
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","projects_discovered":$TOTAL,"projects_skipped":$SKIPPED,"projects_surveyed":0,"projects_failed":0,"dry_run":true,"results":[${RESULTS}]}
MANIFEST
  exit 0
fi

# ── Concurrent execution ─────────────────────────────────────────────
# Track PIDs and their associated project info
declare -A PID_TO_PROJECT=()
declare -A PID_TO_SLUG=()
RUNNING=0
QUEUE_INDEX=0

launch_next() {
  if [[ $QUEUE_INDEX -lt $SURVEY_TOTAL ]]; then
    local project_dir="${TO_SURVEY[$QUEUE_INDEX]}"
    local slug
    slug=$(to_slug "$project_dir")
    QUEUE_INDEX=$((QUEUE_INDEX + 1))

    echo "[${QUEUE_INDEX}/${SURVEY_TOTAL}] Surveying ${slug}..." >&2
    run_survey "$project_dir" "$slug" &
    local pid=$!
    PID_TO_PROJECT[$pid]="$project_dir"
    PID_TO_SLUG[$pid]="$slug"
    RUNNING=$((RUNNING + 1))
  fi
}

# Fill initial pool
while [[ $RUNNING -lt $MAX_CONCURRENT && $QUEUE_INDEX -lt $SURVEY_TOTAL ]]; do
  launch_next
done

# Process completions
while [[ $RUNNING -gt 0 ]]; do
  # wait -n returns exit code of next completed job (bash 4.3+)
  if wait -n -p DONE_PID 2>/dev/null; then
    exit_code=0
  else
    exit_code=$?
    # Get the PID that just finished (bash 5.1+ for -p flag)
    # Fallback: check which PIDs are still running
  fi

  # Find completed PID by checking which tracked PIDs are no longer running
  for pid in "${!PID_TO_PROJECT[@]}"; do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid" 2>/dev/null
      local_exit=$?
      slug="${PID_TO_SLUG[$pid]}"
      project_dir="${PID_TO_PROJECT[$pid]}"

      if [[ $local_exit -eq 0 ]]; then
        RESULTS="${RESULTS}{\"path\":\"$project_dir\",\"slug\":\"$slug\",\"status\":\"success\",\"reason\":null},"
        SURVEYED=$((SURVEYED + 1))
        echo "  [done] $slug (success)" >&2
      else
        RESULTS="${RESULTS}{\"path\":\"$project_dir\",\"slug\":\"$slug\",\"status\":\"failed\",\"reason\":\"exit_code_${local_exit}\"},"
        FAILED=$((FAILED + 1))
        echo "  [fail] $slug (exit $local_exit, see $LOG_DIR/${slug}.err)" >&2
      fi

      unset "PID_TO_PROJECT[$pid]"
      unset "PID_TO_SLUG[$pid]"
      RUNNING=$((RUNNING - 1))

      # Launch next from queue
      launch_next
      break  # Re-enter wait loop
    fi
  done
done

# ── Output manifest ──────────────────────────────────────────────────
RESULTS="${RESULTS%,}"  # Remove trailing comma
cat <<MANIFEST
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","projects_discovered":$TOTAL,"projects_skipped":$SKIPPED,"projects_surveyed":$SURVEYED,"projects_failed":$FAILED,"dry_run":false,"results":[${RESULTS}]}
MANIFEST

echo "" >&2
echo "Excavation complete: $SURVEYED surveyed, $SKIPPED skipped, $FAILED failed (of $TOTAL discovered)" >&2
```

**Step 2: Make executable**

Run: `chmod +x ~/.claude/skills/archaeology/scripts/archaeology-excavation.sh`

**Step 3: Validate with shellcheck**

Run: `shellcheck ~/.claude/skills/archaeology/scripts/archaeology-excavation.sh`
Expected: No errors (warnings about `local` in non-function context are acceptable)

**Step 4: Test dry-run mode**

Run: `~/.claude/skills/archaeology/scripts/archaeology-excavation.sh --dry-run 2>/dev/null | python3 -m json.tool`
Expected: Valid JSON with `dry_run: true` and a list of projects with `would_survey` status

**Step 5: Commit**

```bash
git add ~/.claude/skills/archaeology/scripts/archaeology-excavation.sh
git commit -m "feat(archaeology): add excavation shell script for cross-project surveying"
```

---

### Task 2: Create the Audit Workflow Reference

**Files:**
- Create: `~/.claude/skills/archaeology/references/audit-workflow.md`

**Step 1: Write the workflow reference**

This file defines the skill-side logic that runs after the shell script completes. It mirrors the pattern of `survey-workflow.md`.

```markdown
# Excavation Workflow Reference

> This file is referenced from `SKILL.md`. It defines the full excavation workflow (Steps E1-E6).
> The shell script `scripts/archaeology-excavation.sh` handles discovery and subprocess management.
> This workflow handles the skill-side aggregation after the script completes.

## Excavation Workflow

When excavation mode is triggered, execute these steps.

### Excavation Step E1: Launch Shell Script

Run the excavation script with user-provided flags:

\`\`\`javascript
// Parse flags from user input
DRY_RUN = args.includes('--dry-run');
MAX_CONCURRENT = extract_flag_value(args, '--max-concurrent') || 3;
SCAN_PATHS = extract_flag_value(args, '--scan-paths') || null;
MAX_AGE = extract_flag_value(args, '--max-age') || 7;

SCRIPT_PATH = '~/.claude/skills/archaeology/scripts/archaeology-excavation.sh';

// Build command
cmd = `${SCRIPT_PATH}`;
if (SCAN_PATHS) cmd += ` --scan-paths "${SCAN_PATHS}"`;
if (MAX_CONCURRENT !== 3) cmd += ` --max-concurrent ${MAX_CONCURRENT}`;
if (MAX_AGE !== 7) cmd += ` --max-age ${MAX_AGE}`;
if (DRY_RUN) cmd += ' --dry-run';

// Execute via Bash tool (captures stdout as JSON manifest, stderr shows progress)
manifest_json = Bash(cmd);
manifest = JSON.parse(manifest_json);
\`\`\`

If `DRY_RUN`, display the discovery results and stop:
\`\`\`
Excavation Dry Run

Discovered {N} projects | {S} would skip (fresh survey) | {M} would survey

Projects to survey:
  {slug} — {path}
  ...

Skipped (fresh survey):
  {slug} — last surveyed < {MAX_AGE} days ago

Run without --dry-run to execute surveys.
\`\`\`

### Excavation Step E2: Read Survey Results

For each project with status `success` in the manifest, read its survey.md from the central work-log:

\`\`\`javascript
CENTRAL_BASE = '~/.claude/data/visibility-toolkit/work-log/archaeology';

surveys = {};
for (result of manifest.results.filter(r => r.status === 'success' || r.status === 'skipped')) {
  survey_path = `${CENTRAL_BASE}/${result.slug}/survey.md`;
  if (exists(survey_path)) {
    surveys[result.slug] = Read(survey_path);
  }
}
\`\`\`

### Excavation Step E3: Parse Survey Data

Extract structured data from each survey.md. The survey contract format (from survey-workflow.md S6) has stable, parseable sections:

\`\`\`javascript
project_data = [];
for ([slug, survey_content] of Object.entries(surveys)) {
  // Parse header: "> Scanned on {date} | {N} conversation files | {M} source files"
  header = extract_blockquote(survey_content);
  scan_date = extract_date(header);
  session_count = extract_number(header, 'conversation files');

  // Parse domain scores table
  // Format: | domain | signal | confidence | score | rationale |
  domain_rows = extract_table_rows(survey_content, 'Recommended Domains');
  top_domain = domain_rows[0] || null;  // Already sorted by score desc

  // Parse project profile section
  profile = extract_key_values(survey_content, 'Project Profile');

  // Parse suggested deep dives
  deep_dives = extract_bullet_items(survey_content, 'Suggested Deep Dives');

  project_data.push({
    slug: slug,
    scan_date: scan_date,
    sessions: session_count,
    top_domain: top_domain ? { id: top_domain.domain, signal: top_domain.signal } : null,
    languages: profile['Primary languages'] || 'Unknown',
    deep_dives: deep_dives,
    all_domains: domain_rows
  });
}
\`\`\`

### Excavation Step E4: Synthesise Portfolio

Using the parsed data, generate the cross-project portfolio. The Project Overview table is mechanical (from parsed data). The Cross-Project Patterns and Recommended Next Steps sections use LLM synthesis.

\`\`\`javascript
// Build Project Overview table
overview_rows = project_data
  .sort((a, b) => (b.sessions || 0) - (a.sessions || 0))
  .map(p => {
    action = p.top_domain && p.top_domain.signal !== 'none'
      ? `/archaeology ${p.top_domain.id}`
      : 'skip';
    return `| ${p.slug} | ${p.sessions || '?'} | ${p.top_domain?.id || '-'} | ${p.top_domain?.signal || 'none'} | ${p.scan_date} | \`${action}\` |`;
  }).join('\n');

// Aggregate domain signals across projects for cross-project analysis
domain_cross = {};
for (p of project_data) {
  for (d of p.all_domains) {
    if (d.signal === 'none') continue;
    if (!domain_cross[d.domain]) domain_cross[d.domain] = [];
    domain_cross[d.domain].push({ project: p.slug, signal: d.signal, score: d.score });
  }
}

// Aggregate uncovered themes from deep dives
all_deep_dives = project_data.flatMap(p =>
  p.deep_dives.map(d => ({ ...d, project: p.slug }))
);

// Build failed/skipped table
skipped_failed = manifest.results
  .filter(r => r.status === 'skipped' || r.status === 'failed')
  .map(r => `| ${r.slug} | ${r.reason === 'fresh_survey' ? 'Fresh survey (< ' + MAX_AGE + ' days)' : r.reason} |`)
  .join('\n');
\`\`\`

**LLM synthesis prompt (internal — used to generate the cross-project sections):**

The skill should use its own reasoning to generate:
1. **Cross-Project Patterns** — which domains appear across multiple projects, what that means, any uncovered themes appearing in 2+ projects
2. **Recommended Next Steps** — ranked list of which project+domain to run first (strongest signal * most sessions), new domains to create, projects to skip

These sections are written directly by the skill's LLM capabilities based on the `domain_cross`, `all_deep_dives`, and `project_data` context.

### Excavation Step E5: Write Portfolio

\`\`\`javascript
PORTFOLIO_PATH = `${CENTRAL_BASE}/portfolio.md`;

portfolio_content = `# Archaeology Portfolio — ${current_date()}

> Scanned ${manifest.projects_discovered} projects | ${manifest.projects_surveyed} newly surveyed | ${manifest.projects_skipped} skipped | ${manifest.projects_failed} failed

## Project Overview

| Project | Sessions | Top Domain | Signal | Last Survey | Action |
|---------|----------|------------|--------|-------------|--------|
${overview_rows}

## Cross-Project Patterns

${cross_project_patterns}

## Recommended Next Steps

${recommended_next_steps}

## Skipped & Failed

| Project | Reason |
|---------|--------|
${skipped_failed || '| _(none)_ | |'}

---
*Generated by archaeology excavation — ${current_date()}*
`;

Write(PORTFOLIO_PATH, portfolio_content);
\`\`\`

### Excavation Step E6: Completion Display

\`\`\`
Archaeology Excavation Complete

Discovered ${TOTAL} projects | Surveyed ${SURVEYED} | Skipped ${SKIPPED} | Failed ${FAILED}

Portfolio: ~/.claude/data/visibility-toolkit/work-log/archaeology/portfolio.md
Logs:      ~/.claude/data/visibility-toolkit/work-log/archaeology/.excavation-logs/

Top recommendations:
  1. /archaeology {domain} on {project} (strongest signal)
  2. ...

Run /archaeology {domain} in a project directory to extract patterns.
\`\`\`

### Excavation Completion Criteria

Excavation run is complete when:
- [ ] Shell script executed successfully (or --dry-run displayed results)
- [ ] All survey.md files read from central work-log
- [ ] Survey data parsed (domain scores, profiles, deep dives)
- [ ] Portfolio.md generated with cross-project synthesis
- [ ] Portfolio.md written to central work-log root
- [ ] Completion summary displayed with recommendations
```

**Step 2: Commit**

```bash
git add ~/.claude/skills/archaeology/references/audit-workflow.md
git commit -m "feat(archaeology): add excavation workflow reference for portfolio aggregation"
```

---

### Task 3: Wire Excavation into SKILL.md

**Files:**
- Modify: `~/.claude/skills/archaeology/SKILL.md:3-4` (description + argument-hint)
- Modify: `~/.claude/skills/archaeology/SKILL.md:13-21` (invocation patterns)
- Modify: `~/.claude/skills/archaeology/SKILL.md:25-28` (available commands)
- Modify: `~/.claude/skills/archaeology/SKILL.md:36-51` (routing logic)

**Step 1: Update frontmatter description and argument-hint**

In `SKILL.md` line 3, add "excavation" and "portfolio" to the trigger description:

```
description: This skill should be used when the user says "archaeology", "extract patterns", "mine my history", "what patterns have I used", "export findings", "save findings", "save pattern", "capture learnings", "document what worked", "survey", "scan my history", "scan project", "what domains", "list domains", "excavation", or "portfolio". Analyzes past Claude Code sessions for reusable patterns, extracts learnings from usage history, and preserves findings for future reference across multiple knowledge domains.
```

In `SKILL.md` line 4, update argument-hint:

```
argument-hint: "[survey|excavation|{domain}|list] [project-name] [--no-export] [--dry-run] [--max-concurrent N]"
```

**Step 2: Add excavation to invocation patterns**

After line 21 (the last current invocation pattern), add:

```bash
/archaeology excavation                # Excavation mode — survey all projects, generate portfolio
/archaeology excavation --dry-run      # Show what would be surveyed without running
/archaeology excavation --max-concurrent 5  # Override parallel limit (default: 3)
/archaeology excavation --scan-paths "~/Work,~/Side"  # Override scan directories
/archaeology excavation --max-age 14   # Skip surveys fresher than 14 days (default: 7)
```

**Step 3: Add excavation to available commands**

After the existing commands list (~line 28), add:

```markdown
- **excavation** - Cross-project portfolio scan: discover projects, survey each, generate portfolio report
```

**Step 4: Add excavation routing to the routing logic**

In the routing block (~lines 36-51), add excavation routing BEFORE the survey check:

```javascript
args = parse_arguments(user_input);

if (args.command === 'list') {
  list_domains();
  return;
}

if (args.command === 'excavation') {
  // Branch to Excavation workflow (see references/audit-workflow.md)
  execute_excavation(args);
  return;
}

if (args.command === undefined || args.command === 'survey') {
  // Branch to Survey workflow (see references/survey-workflow.md)
  execute_survey(args);
  return;
}

// Otherwise: continue to Step 1 (domain extraction workflow)
```

**Step 5: Verify word count**

Run: `wc -w ~/.claude/skills/archaeology/SKILL.md`
Expected: Under 3,000 words (currently ~1,356, adding ~80 words for excavation routing)

**Step 6: Commit**

```bash
git add ~/.claude/skills/archaeology/SKILL.md
git commit -m "feat(archaeology): wire excavation mode into SKILL.md routing"
```

---

### Task 4: Create Ignore File

**Files:**
- Create: `~/.claude/archaeology-ignore`

**Step 1: Write seed ignore file**

```
# Archaeology excavation ignore list
# One path per line. Lines starting with # are comments.
# Paths are matched as prefixes (~/Playground/old-thing matches ~/Playground/old-thing/sub).

# Meta directories (not real projects)
~/.claude
~/Documents

# Add project paths to skip:
# ~/Playground/old-prototype
```

**Step 2: Commit**

```bash
git add ~/.claude/archaeology-ignore
git commit -m "feat(archaeology): seed excavation ignore list"
```

---

### Task 5: Shell Script Review

**Agent:** `shell-scripting:bash-pro` sub-agent

**Review scope:** `~/.claude/skills/archaeology/scripts/archaeology-excavation.sh`

**Review checklist:**
- [ ] Defensive patterns (set -euo pipefail, quoting, error handling)
- [ ] No shellcheck errors/warnings
- [ ] Concurrency correctness (wait -n, PID tracking, race conditions)
- [ ] macOS + Linux compatibility (stat flags, bash version requirements)
- [ ] JSON output correctness (special characters in paths escaped?)
- [ ] Edge cases: empty scan paths, no projects found, all skipped, all failed

Fix any issues found before proceeding.

---

### Task 6: Skill & Plugin Review

**Agent 1:** `plugin-dev:skill-reviewer` sub-agent

**Review scope:** SKILL.md changes + `references/audit-workflow.md`

**Review checklist:**
- [ ] SKILL.md description triggers are effective
- [ ] Invocation patterns are clear and complete
- [ ] Routing logic is correct (excavation before survey check)
- [ ] audit-workflow.md follows skill reference patterns
- [ ] Word count under 3,000

**Agent 2:** `plugin-dev:plugin-validator` sub-agent

**Review scope:** Overall archaeology skill structure

**Review checklist:**
- [ ] Plugin manifest valid
- [ ] All referenced files exist
- [ ] No broken cross-references

Fix any issues found before proceeding.

---

### Task 7: Integration Test

**Step 1: Test dry-run mode end-to-end**

Run: `/archaeology excavation --dry-run`
Expected: Lists discovered projects, shows which would be surveyed vs skipped, no subprocesses launched.

**Step 2: Test with 2 real projects**

Run: `/archaeology excavation --scan-paths "~/Personal/workspace-mcp,~/Spotify/talent-snapshots" --max-concurrent 2`
Expected:
- talent-snapshots: skipped (has fresh survey from earlier testing)
- workspace-mcp: surveyed (new survey.md created)
- portfolio.md generated at `~/.claude/data/visibility-toolkit/work-log/archaeology/portfolio.md`

**Step 3: Verify portfolio content**

Read: `~/.claude/data/visibility-toolkit/work-log/archaeology/portfolio.md`
Expected: Project Overview table with both projects, Cross-Project Patterns section, Recommended Next Steps

**Step 4: Test ignore list**

Add `~/Personal/workspace-mcp` to `~/.claude/archaeology-ignore`, re-run dry-run.
Expected: workspace-mcp no longer appears in discovered projects.

**Step 5: Test freshness skip**

Run excavation again immediately after Step 2.
Expected: All projects skipped (surveys are < 7 days old). Portfolio regenerated from existing surveys.

---

### Task 8: Update Restructure Todos

**Files:**
- Modify: `~/.claude/projects/-Users-benpurslow/memory/archaeology-restructure-todos.md`

**Step 1: Add excavation mode to the todos file**

Add excavation to the "Future: Invocation Modes" table as implemented. Update the "Done" section with excavation mode completion.

**Step 2: Update MEMORY.md**

Add excavation mode status to the Archaeology section in MEMORY.md.
