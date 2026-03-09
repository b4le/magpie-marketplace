---
name: expert-review
description: Orchestrate parallel expert reviews of code changes using specialized agents in isolated worktrees. Use at checkpoints or after completing features. Supports auto-detection or explicit expertise specification.
argument-hint: "[expertise-areas] [--report-only]"
---

# Expert Review Orchestration

Spawn expert sub-agents to review, iterate, and improve your work.

## Quick Start

```text
/expert-review                      # Auto-detect relevant experts
/expert-review security backend     # Specify expertise areas
/expert-review --report-only        # Recommendations only, no changes
```

## Spawning Agents

Use the **Task** tool to spawn sub-agents:

```python
Task(
    subagent_type="expert-review:domain-reviewer",
    prompt="Review src/auth/ for security vulnerabilities. Output JSON findings.",
    description="Security review of auth module",
    isolation="worktree"
)
```

**Parameters:**
- Required: `subagent_type`, `prompt`, `description`
- Optional: `isolation` (use "worktree" for modifier agents), `model` (defaults to agent's frontmatter)

**Agent naming:**
- Plugin agents: `plugin-name:agent-name` (e.g., `expert-review:expert-mapper`)
- External agents: bare name (e.g., `security-auditor`, `code-reviewer`)

## Process Flow

### Phase 1: Expert Discovery

1. Parse arguments for expertise areas (or auto-detect if empty)
2. Invoke `expert-mapper` agent to:
   - Scan installed plugins for available agents
   - Match expertise areas to agent patterns
   - Return ranked list of experts to spawn

### Phase 2: Parallel Review

For each selected expert:

1. **Modifier agents** (make changes):
   - Spawn with `isolation: "worktree"` via Task tool
   - Agent reviews, fixes confident issues, recommends uncertain ones
   - Returns JSON with changes and branch name

2. **Analyzer agents** (read-only):
   - Spawn without worktree
   - Agent analyzes and returns recommendations only

### Phase 3: Consolidation

1. Collect all expert JSON responses
2. Invoke `merge-coordinator` agent to:
   - Deduplicate findings
   - Merge worktree branches in precedence order
   - Resolve conflicts using domain authority
   - Escalate unresolvable conflicts to user

### Phase 4: Return Result

Return consolidated JSON to orchestrator:

```json
{
  "status": "success",
  "summary": "3 experts reviewed. 5 changes applied, 2 recommendations.",
  "confidence": "high",
  "changes": ["file1.ts", "file2.ts"],
  "recommendations": ["Consider adding rate limiting"]
}
```

## Modes

### Default Mode (Review + Iterate)

- Experts make confident changes directly
- Uncertain changes become recommendations
- Worktree merges applied to working branch

### Report-Only Mode

Invoke with `--report-only` flag:

- All experts run as analyzers (no worktrees)
- No changes made to codebase
- Returns recommendations only

## Expert Types

| Expertise | Agent Pattern | Type | Priority |
|-----------|--------------|------|----------|
| security | *security*, *appsec*, *threat* | modifier | 5 |
| accessibility | *accessibility*, *a11y* | analyzer | 4 |
| architecture | *architect*, *design* | modifier | 3 |
| infrastructure | *cloud*, *kubernetes*, *terraform*, *devops* | modifier | 3 |
| performance | *performance*, *optim* | modifier | 2 |
| database | *database*, *sql*, *data* | modifier | 2 |
| backend | *api*, *backend*, code-reviewer | modifier | 1 |
| frontend | *frontend*, *ui*, *react*, *vue* | modifier | 1 |
| python | *python* | modifier | 1 |
| typescript | *typescript*, *javascript* | modifier | 1 |
| testing | *test*, *qa*, *tdd* | modifier | 0 |

## Dynamic Discovery

Experts are discovered at runtime from:
- Installed plugins in `~/.claude/plugins/`
- Agent definitions in `agents/*.md`
- Marketplace agents

No hardcoded agent lists - always current with your setup.

## Conflict Resolution

When experts disagree:

1. **Domain precedence** - Security > Accessibility > Architecture > Performance > Backend > Testing
2. **Merge coordinator decides** - Uses confidence scores
3. **User escalation** - 30-min timeout, then "most conservative wins"

## Error Handling

- **Agent timeout**: Partial results returned with warning
- **Worktree conflict**: Rollback and escalate
- **Test regression**: Block merge, report failure
- **No experts found**: Fall back to code-reviewer

## Integration

This skill coordinates with:
- `verification-before-completion` - Run after expert review
- `managing-git-workflows` - Safe worktree operations

## Implementation

**When this skill is invoked, follow these orchestration steps:**

### Phase 1: Expert Discovery

1. **Parse user arguments**
   - Extract expertise areas from user input (e.g., "security backend")
   - Check for `--report-only` flag (set `report_only_mode = true`)
   - Get current working directory path

2. **Spawn expert-mapper agent**

   Expert-mapper handles ALL analysis (git detection, file changes, agent discovery).

   ```python
   Task(
       subagent_type="expert-review:expert-mapper",
       prompt="""
       Analyze the working directory and select appropriate reviewers.

       User-specified expertise: {expertise_areas or "auto-detect"}
       Working directory: {cwd}

       Follow your Input Analysis and Agent Discovery phases.
       Return JSON with git_analysis, detected_expertise, and selected_agents.
       """,
       description="Analyze codebase and select expert reviewers"
   )
   ```

3. **Parse expert-mapper response**
   - Extract `git_analysis` for review context (recent_files, recent_commits)
   - Extract `selected_agents` array
   - If empty or error: fall back to `code-reviewer` agent
   - If `--report-only` flag: override all agent types to "analyzer"

### Phase 2: Parallel Review

4. **Use analysis from expert-mapper**

   The `git_analysis` from step 3 provides:
   - `recent_files`: Files to review
   - `recent_commits`: Context for reviewers

   No additional git commands needed.

5. **Spawn expert agents in parallel**

   For each agent in `selected_agents`, spawn using Task tool:

   **Modifier agents** (make changes):
   ```python
   Task(
       subagent_type=agent.name,
       isolation="worktree",
       prompt=f"""
       Review the following files for {agent.domain} issues.

       Files: {git_analysis.recent_files}
       Recent commits: {git_analysis.recent_commits}
       Mode: modifier (fix confident issues, recommend uncertain ones)

       Return JSON with changes and recommendations.
       """,
       description=f"{agent.domain} review"
   )
   ```

   **Analyzer agents** (read-only, or when --report-only):
   ```python
   Task(
       subagent_type=agent.name,
       prompt=f"""
       Analyze the following files for {agent.domain} issues.

       Files: {git_analysis.recent_files}
       Recent commits: {git_analysis.recent_commits}
       Mode: analyzer (recommendations only, no changes)

       Return JSON with findings and recommendations.
       """,
       description=f"{agent.domain} analysis"
   )
   ```

6. **Collect agent responses**
   - Task tool blocks until agent completes
   - Collect JSON responses from all agents
   - Handle timeouts (30 min per agent): continue with partial results

7. **Handle agent errors**
    - If agent returns `status: "error"`: log and continue with other agents
    - If all agents fail: return error to user with recovery suggestions
    - If partial success: proceed with available results

### Phase 3: Consolidation

8. **Spawn merge-coordinator agent**

    ```python
    Task(
        subagent_type="expert-review:merge-coordinator",
        prompt=f"""
        Consolidate expert review results.

        Expert responses: {expert_responses_json}
        Mode: {"analyzer" if report_only_mode else "modifier"}

        Follow your merge and deduplication process.
        Return consolidated JSON with changes_applied and recommendations.
        """,
        description="Consolidate expert reviews"
    )
    ```

9. **Handle merge-coordinator response**
    - Parse consolidated JSON response
    - If `status: "needs-input"`: present escalations to user
    - If user doesn't respond in 30 min: apply most conservative option
    - If `status: "error"`: attempt rollback and report failure

### Phase 4: Cleanup

10. **Clean up worktrees**

    For each modifier agent that used `isolation: "worktree"`:

    ```bash
    # Get worktree path from agent response (e.g., worktree_path field)
    # Remove the worktree
    git worktree remove {worktree-path}
    ```

    **Error handling:**
    - If worktree is locked: `git worktree remove --force {worktree-path}`
    - If worktree has uncommitted changes:
      - Log warning about dirty worktree
      - Attempt `git worktree remove --force {worktree-path}`
      - If still fails, manually remove directory and use `git worktree prune`
    - Continue cleanup even if one worktree fails

    **Cleanup must run even on failure:**
    - Wrap entire Phase 2-3 in try/catch logic
    - Always execute Phase 4 cleanup in finally block
    - Track all created worktree paths from step 5
    - Clean up all tracked worktrees regardless of success/failure

### Phase 5: Report

11. **Present results to user**

    Format output based on consolidation result:

    **Success case:**
    ```
    Expert Review Complete

    Consulted: [list of expert names]

    Changes Applied:
    - [domain1]: [count] files modified
    - [domain2]: [count] files modified

    Recommendations:
    - [domain]: [suggestion] (confidence: [high/medium/low])

    Next steps:
    - Review recommendations above
    - Run verification-before-completion if available
    ```

    **Report-only mode:**
    ```
    Expert Review (Report Only)

    Consulted: [list of expert names]

    Findings:
    - [domain1]: [finding1], [finding2]
    - [domain2]: [finding1]

    Recommendations:
    - [domain]: [suggestion] (confidence: [high/medium/low])
    ```

    **Error case:**
    ```
    Expert Review Failed

    Error: [error message from merge-coordinator]

    Recovery: [recovery suggestion]

    Partial Results: [if available]
    ```

12. **List modified files**
    ```bash
    # If changes were applied
    git status --short
    ```

13. **Prompt for next action**
    - Suggest running tests if changes were made
    - Suggest `/verification-before-completion` if available
    - For escalations, ask user to choose option

### Error Handling Strategies

**Agent timeout (30+ minutes):**
- Continue with other agents
- Include partial results in final report
- Warn user about missing domain coverage

**Worktree conflict during merge:**
- Attempt automatic resolution using precedence rules
- If unresolvable: escalate to user with both versions
- Provide rollback option

**Test regression after merge:**
- Automatically rollback all changes
- Report which domain introduced the failure
- Return recommendations only (as if --report-only)

**No experts found:**
- Fallback to `code-reviewer` agent (generic review)
- Warn user about lack of specialized coverage
- Suggest installing domain-specific agent plugins

**Configuration files missing:**
- Use hardcoded defaults from agent files
- Warn user about missing config
- Continue with degraded functionality

### Example Invocations

```python
# Expert-mapper (analyzes codebase and selects reviewers)
Task(
    subagent_type="expert-review:expert-mapper",
    prompt="Analyze cwd and select experts. User requested: security. Return JSON.",
    description="Select expert reviewers"
)

# Domain reviewer (modifier - makes changes in worktree)
Task(
    subagent_type="security-auditor",
    isolation="worktree",
    prompt="Review auth.ts for security issues. Fix confident issues. Return JSON.",
    description="Security review"
)

# Merge coordinator (consolidates results)
Task(
    subagent_type="expert-review:merge-coordinator",
    prompt="Consolidate: [{security findings}, {perf findings}]. Mode: modifier.",
    description="Consolidate expert reviews"
)
```

### Verification Steps

After consolidation, verify:
1. All worktree branches merged cleanly
2. No duplicate findings in final report
3. Precedence rules applied correctly
4. Escalations properly formatted for user

## References

- Config: `config/expertise-patterns.yaml`
- Config: `config/precedence-matrix.yaml`
- Agent: `agents/expert-mapper.md`
- Agent: `agents/domain-reviewer.md`
- Agent: `agents/merge-coordinator.md`
- Script: `skills/expert-review/scripts/validate-worktree.sh`
