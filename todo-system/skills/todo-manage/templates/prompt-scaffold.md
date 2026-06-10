# <Task title> — <deadline or trigger condition>

<!-- TRIGGER: 1-2 sentences naming the task and any deadline. -->
<!-- A fresh session reads this to confirm it loaded the right prompt. -->

## Context

<!-- CONTEXT: Full background the session needs. -->
<!-- Who are the people involved? What state is the matter in? -->
<!-- What just happened? What comes next? -->
<!-- Capture everything — assume the reader has zero memory. -->

## Read First

<!-- READ FIRST: Absolute paths to files the session must load. -->
<!-- Include "do NOT read" exclusions for privileged/out-of-scope files. -->

| Order | Path | Mode |
|-------|------|------|
| 1 | `/absolute/path/to/primary-file.md` | Full read |
| 2 | `/absolute/path/to/secondary-file.md` | Lines N-M |

Do NOT read: <!-- list privileged or out-of-scope files here -->

## Task Flow

<!-- TASK FLOW: Numbered steps the session executes. -->
<!-- Weave gate instructions into the steps as concrete actions. -->

1. <!-- First step -->
2. <!-- Second step -->
3. <!-- Continue as needed -->

## Guardrails

<!-- GUARDRAILS: Hard constraints verified before shipping. -->
<!-- Project-specific rules, tone requirements, content exclusions. -->

- <!-- Constraint 1 -->
- <!-- Constraint 2 -->

### Gates

```yaml
worktree: skip            # required | optional | skip
specialist-routing: false  # true | false
parallelization: none      # aggressive | conservative | none
review-gate: none          # pre-commit | pre-merge | none
```

## Output Path

<!-- OUTPUT PATH: Absolute path where the deliverable is written. -->

`/absolute/path/to/output/deliverable.md`

## Success Criterion

<!-- SUCCESS CRITERION: One sentence defining "done." -->
