# Gate Configuration

Modular gates control how todo prompts execute. Four gates govern isolation, routing, concurrency, and quality checks. Each gate is independently configurable per project or per prompt.

## The Four Gates

### 1. Worktree Gate

Controls git isolation for code changes.

| Value | Behavior |
|-------|----------|
| `required` | Always create a git worktree before code changes. Use `EnterWorktree` native tool if available; fall back to `git worktree add`. |
| `optional` | Create worktree if the change touches 3+ files or crosses module boundaries. Otherwise work on current branch. |
| `skip` | No worktree. For non-git deliverables (drafts, notes) or single-file changes. |

### 2. Specialist Routing Gate

Controls whether sub-agents follow the specialist routing decision tree (`specialist-routing.md`).

| Value | Behavior |
|-------|----------|
| `true` | Sub-agents must use specialist routing. Apply the routing table below. |
| `false` | Direct dispatch acceptable. Use when the task is narrow and domain is obvious. |

**Routing table** (when `specialist-routing: true`):

| Domain Pattern | Recommended `subagent_type` | Skills to layer |
|---|---|---|
| TypeScript/JS | `javascript-typescript:typescript-pro` | Relevant JS/TS skills |
| Python | `python-development:python-pro` | Relevant Python skills |
| Bash/Shell | `shell-scripting:bash-pro` | defensive-patterns, bats-testing |
| SQL/Database | `database-design:sql-pro` | Relevant DB skills |
| Security | `comprehensive-review:security-auditor` | Security skills |
| Infrastructure/CI | Relevant CI agent | github-actions, deployment skills |
| Claude Code plugin | `general-purpose` | plugin-dev skills |

The language signal always wins over domain or action signals. When a task combines language + action (e.g. "review this TypeScript"), route by language and layer the action as a skill.

### 3. Parallelization Gate

Controls concurrency strategy. Follows the fan-out pattern: N agents x 1 item x fixed pipeline.

| Value | Behavior |
|-------|----------|
| `aggressive` | Fan out independent steps immediately. One agent per work item, cap at 5 agents. No shared files, deterministic pipeline per agent. |
| `conservative` | Sequential by default. Only parallelize when steps have zero shared state and clear file ownership boundaries. |
| `none` | Single-threaded. The session runs every step itself. |

### 4. Review Gate

Controls quality checkpoints before code lands.

| Value | Behavior |
|-------|----------|
| `pre-commit` | Dispatch a review agent before `git commit`. The review must return GO before proceeding. |
| `pre-merge` | Commit freely on branch. Dispatch review before merge or PR creation. |
| `none` | No formal review. Self-verify against the prompt's success criterion. |

## Per-Project Configuration

Location: `<scope>/.claude/prompts/todos/todos.config.md`

```yaml
---
version: 1
gates:
  worktree: optional
  specialist-routing: true
  parallelization: conservative
  review-gate: pre-commit
categories:
  - infrastructure
  - features
  - bugs
triggers:
  session-end: true
overflow:
  item-threshold: 50
  line-threshold: 200
  done-retention-days: 7
---

## Notes
Project-specific conventions here.
```

## Precedence Rules

Resolution order (highest wins):

| Priority | Source | Example |
|----------|--------|---------|
| 1 (highest) | Per-prompt `### Gates` block | Inline in the todo prompt file |
| 2 | Project `<project>/.claude/prompts/todos/todos.config.md` | Project-level defaults |
| 3 | Root `~/.claude/prompts/todos/todos.config.md` | User-wide defaults |
| 4 (lowest) | Hardcoded defaults | Most conservative settings |

**Hardcoded defaults** (applied when no config exists):

```yaml
gates:
  worktree: skip
  specialist-routing: false
  parallelization: none
  review-gate: none
triggers:
  session-end: false
```

A per-prompt `### Gates` block overrides only the gates it explicitly sets. Unspecified gates inherit from the next level down.

## How Gates Translate to Prompt Task Flow

Each active gate injects steps into the prompt's `### Task Flow` section. The table below shows what each gate value injects.

| Gate | Value | Injected step(s) |
|------|-------|-------------------|
| Worktree | `required` | **Step 1: Isolate** -- `EnterWorktree` or `git worktree add ../wt-<slug> -b todo/<slug>`. **Final step: Cleanup** -- exit worktree, merge/PR per review gate. |
| Worktree | `optional` | **Step 1: Assess scope** -- if 3+ files or cross-module, create worktree; otherwise current branch. |
| Worktree | `skip` | No step injected. |
| Specialist routing | `true` | **Route** -- identify language/domain signal, dispatch to matching specialist from routing table. Layer relevant skills. Never use `general-purpose` when a specialist exists. |
| Specialist routing | `false` | No step injected. Direct dispatch. |
| Parallelization | `aggressive` | **Decompose** -- break into independent items (scope, owned files, pipeline, done criteria). **Fan out** -- one agent per item, max 5, no shared files. **Collect** -- verify outputs, report failures. |
| Parallelization | `conservative` | **Check independence** -- before each step, confirm zero shared state. Parallelize only confirmed-independent steps. |
| Parallelization | `none` | No step injected. All steps sequential. |
| Review | `pre-commit` | **Review** -- dispatch review agent on diff before `git commit`. Commit only after GO. |
| Review | `pre-merge` | **Commit** freely on branch. **Review before merge** -- dispatch review agent on full branch diff. Merge/PR only after GO. |
| Review | `none` | No step injected. Self-verify against success criterion. |

### Combined Example

A prompt with `worktree: required`, `specialist-routing: true`, `parallelization: aggressive`, `review-gate: pre-commit` produces:

```markdown
### Task Flow
1. Create worktree: `git worktree add ../wt-auth-refactor -b todo/auth-refactor`
2. Route: Lang(TypeScript) -> `javascript-typescript:typescript-pro`.
   Layer: `javascript-testing-patterns`.
3. Decompose into 3 items: auth-middleware (owns src/auth/*),
   token-service (owns src/tokens/*), test-suite (owns tests/auth/*).
4. Fan out 3 agents, one per item, fixed pipeline: read -> implement -> test.
5. Collect outputs, verify all tests pass.
6. Review: dispatch review agent on combined diff. Commit after GO.
7. Exit worktree. Create PR.
```

### Per-Prompt Override Example

A todo prompt file can override specific gates inline:

```markdown
### Gates
worktree: skip
parallelization: none
```

This overrides those two gates while inheriting `specialist-routing` and `review-gate` from the project or root config.
