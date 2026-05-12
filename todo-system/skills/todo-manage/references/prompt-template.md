# Session-Launch Prompt Format

Session-launch prompts are point-in-time artifacts that give a fresh session everything it needs to execute a todo without re-derivation. Each prompt follows a fixed 7-section structure with an embedded gates extension.

## File Naming

```
<topic-slug>[-YYYY-MM-DD].md
```

- **Date-sensitive** (fires on or before a specific date): include the date.
  Example: `stina-reply-2026-05-11.md`, `offer-deadline-2026-05-15.md`
- **State-transition** (fires after some event, no calendar deadline): omit the date.
  Example: `formal-accommodation-request.md`, `post-acceptance-followup.md`

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
# Reply to Stina with meeting debrief — ship by 2026-05-11

Stina messaged on Signal asking for a summary of what happened in the May 9
HR meeting. She was present but wants written confirmation of the key points
for her own records. This reply must land today (May 11).

## Context

Stina Lindqvist is a colleague and ally. She attended the May 9 meeting with
Johan (HR) and Adrian (manager) where three topics were discussed:
1. The redeployment timeline was extended to June 15.
2. Adrian acknowledged the accommodation request verbally but no written
   confirmation was given.
3. Johan stated that the role elimination is "business-driven, not personal."

Current state: Ben has a draft summary in the vault but it has not been
reviewed for tone or accuracy. The Signal thread with Stina has 4 prior
messages, last from her on May 10 asking "can you write up what happened?"

## Read First

| Order | Path | Mode |
|-------|------|------|
| 1 | `/home/ben/atticus-finch/vault/meetings/2026-05-09-hr-meeting.md` | Full read |
| 2 | `/home/ben/atticus-finch/vault/comms/signal/stina-lindqvist.md` | Last 30 lines |
| 3 | `/home/ben/atticus-finch/vault/strategy/tone-guide.md` | Full read |

Do NOT read: `/home/ben/atticus-finch/vault/legal/counsel-notes.md` (privileged).

## Task Flow

1. Read the meeting summary and extract the three key decisions.
2. Read Stina's last Signal messages for tone and context.
3. Draft a reply (3-4 short paragraphs) that:
   - Confirms the three decisions without editorialising.
   - Thanks her for attending.
   - Notes that written confirmation from HR is still pending.
4. Apply tone guide constraints (warm but factual, no legal language).
5. Run review-gate check before writing final output.
6. Write the final reply to the output path.

## Guardrails

- Do not reference legal counsel or any privileged conversations.
- Do not include financial figures or equity details.
- Do not speculate about employer intent beyond what was stated in the meeting.
- Tone: warm, collegial, factual. No passive aggression.

### Gates

```yaml
worktree: skip
specialist-routing: false
parallelization: none
review-gate: pre-commit
```

## Output Path

`/home/ben/atticus-finch/vault/comms/drafts/stina-reply-2026-05-11.md`

## Success Criterion

A reply ready to paste into Signal that summarises the three meeting decisions
in Stina's expected tone, with no privileged content.
```
