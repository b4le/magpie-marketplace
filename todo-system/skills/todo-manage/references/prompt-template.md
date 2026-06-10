# Session-Launch Prompt Format

Session-launch prompts are point-in-time artifacts that give a fresh session everything it needs to execute a todo without re-derivation. Each prompt follows a fixed 7-section structure with an embedded gates extension.

## File Naming

```
<topic-slug>[-YYYY-MM-DD].md
```

- **Date-sensitive** (fires on or before a specific date): include the date.
  Example: `alice-reply-2026-05-11.md`, `offer-deadline-2026-05-15.md`
- **State-transition** (fires after some event, no calendar deadline): omit the date.
  Example: `vendor-contract-review.md`, `post-acceptance-followup.md`

Slugs are short, kebab-case, and reference the recipient, topic, or action.

## The 7 Sections

Every prompt contains these sections in this exact order.

### 1. Trigger (H1 title + 1-2 sentences)

Name the task and any deadline. A fresh session confirms it loaded the right prompt.

### 2. Context

Full background: who the people are, what state the matter is in, what just happened, what comes next. Capture everything at time of writing -- assume the reader has zero memory.

### 3. Read First

Absolute file paths the session must load before acting. Use a table format:

| Order | Path | Mode |
|-------|------|------|
| 1 | `/absolute/path/to/file.md` | Full read |
| 2 | `/absolute/path/to/large-file.md` | Lines 1-50 |

Include "do NOT read" exclusions for privilege-sensitive or out-of-scope files.

### 4. Task Flow

Numbered steps the session executes. Gates (see below) are woven into the steps as concrete instructions, not abstract metadata.

### 5. Guardrails

Hard constraints the session must verify before shipping. Project-specific rules go here.

Contains a `### Gates` sub-section with a YAML block (see below).

### 6. Output Path

Absolute path where the deliverable is written.

### 7. Success Criterion

One sentence defining "done."

## Gates Extension

The `### Gates` sub-section inside Guardrails contains a YAML block that controls session execution behavior:

```yaml
worktree: required        # required | optional | skip
specialist-routing: true  # true | false
parallelization: conservative  # aggressive | conservative | none
review-gate: pre-commit   # pre-commit | pre-merge | none
```

### Gate Values and Their Effect on Task Flow

| Gate | Value | Effect |
|------|-------|--------|
| `worktree` | `required` | Step 0 added: create git worktree via `EnterWorktree` before any file changes |
| `worktree` | `optional` | Use worktree if available, proceed without if not |
| `worktree` | `skip` | Work directly in the current tree |
| `specialist-routing` | `true` | Dispatch sub-agents using the specialist routing decision tree |
| `specialist-routing` | `false` | Execute all steps directly, no sub-agent dispatch |
| `parallelization` | `aggressive` | Fan-out independent steps to parallel agents |
| `parallelization` | `conservative` | Run steps sequentially unless explicitly marked parallel |
| `parallelization` | `none` | Strictly sequential execution |
| `review-gate` | `pre-commit` | Dispatch review agent before committing |
| `review-gate` | `pre-merge` | Dispatch review agent before merge/PR |
| `review-gate` | `none` | No automated review step |

### Gate Precedence

Per-prompt gates override project config. Project config overrides root/global config.

## Freshness Convention

Prompts are point-in-time artifacts. They freeze dates, names, state, and strategic context as of the day they were written. Never edit an existing prompt if the situation has drifted -- write a new prompt instead.

## How Prompts Are Created

Dispatch the plugin's `prompt-writer` agent, one agent per todo, fan-out style. The main session writes only the todo entry; the sub-agent writes the prompt file.

## Complete Example

```markdown
# Write post-incident review for checkout outage — ship by 2026-05-11

The payments team needs a post-incident review document for the May 9
checkout service outage. The on-call engineer has raw notes but no
structured write-up. This review must be published to the engineering
wiki by end of day May 11.

## Context

On May 9, the checkout service experienced a 47-minute outage caused by
a misconfigured database connection pool after the v2.8 deploy. Three
areas need to be covered in the review:
1. The root cause: connection pool max was set to 10 instead of 100
   in the new config format.
2. Detection gap: alerting fired at 12 minutes, but the runbook was
   outdated and pointed to a decommissioned dashboard.
3. Resolution: the deploy was rolled back at minute 38, and connections
   recovered by minute 47.

Current state: the on-call engineer posted raw timeline notes in the
incident Slack channel. A draft template exists in the project docs but
has not been filled in. The engineering manager asked for the write-up
on May 10 in the incident thread.

## Read First

| Order | Path | Mode |
|-------|------|------|
| 1 | `/home/user/checkout-service/docs/incidents/2026-05-09-timeline.md` | Full read |
| 2 | `/home/user/checkout-service/docs/incidents/templates/post-incident-template.md` | Full read |
| 3 | `/home/user/checkout-service/docs/runbooks/checkout-alerting.md` | Lines 1-40 |

Do NOT read: `/home/user/checkout-service/docs/incidents/internal-pager-logs.md` (contains PII).

## Task Flow

1. Read the incident timeline and extract the three key areas (root cause, detection, resolution).
2. Read the post-incident template to understand the required sections.
3. Draft the review document that:
   - States the root cause clearly with the specific misconfiguration.
   - Documents the detection gap and alerting timeline.
   - Lists the resolution steps and recovery confirmation.
4. Add an action items section with owners and due dates.
5. Run review-gate check before writing final output.
6. Write the final document to the output path.

## Guardrails

- Do not assign blame to individuals; focus on systemic causes.
- Do not include customer-identifying information or PII.
- Do not speculate about impact beyond what was measured during the incident.
- Tone: factual, blameless, constructive.

### Gates

```yaml
worktree: skip
specialist-routing: false
parallelization: none
review-gate: pre-commit
```

## Output Path

`/home/user/checkout-service/docs/incidents/reviews/2026-05-09-checkout-outage.md`

## Success Criterion

A blameless post-incident review covering root cause, detection gap, and
resolution with concrete action items, ready for wiki publication.
```
