# Work Item Prompt Template

Template used to construct the prompt passed to each sub-agent during plan execution. The decompose skill produces the data; execution tools (fan-out, team-spawn, orchestrate) fill in this template.

## Template

```
## Work Item: {work_item.id} — {work_item.title}

### Scope
{work_item.scope}

### Your Files (you own these exclusively)
{for file in work_item.files}
- `{file.path}` — {file.action}: {file.description}
{endfor}

### Pipeline
Follow these steps in order:
{for i, step in work_item.pipeline}
{i}. {step}
{endfor}

### Context
Read these files for context before starting:
{for path in work_item.inputs.context_files}
- `{path}`
{endfor}
{if work_item.inputs.prefetch_paths}

Pre-fetched data available at:
{for path in work_item.inputs.prefetch_paths}
- `{path}`
{endfor}
{endif}

### Interface Contracts
{if work_item.interface_contracts.imports}
**You depend on (will exist when you run):**
{for contract in work_item.interface_contracts.imports}
- {contract}
{endfor}
{endif}
{if work_item.interface_contracts.exports}
**You must provide (others depend on):**
{for contract in work_item.interface_contracts.exports}
- {contract}
{endfor}
{endif}

### Done Criteria
Your work is complete when ALL of these are true:
{for criterion in work_item.done_criteria}
- [ ] {criterion}
{endfor}

### Constraints
- Only create or modify files listed in "Your Files" above
- Do not modify any other files in the repository
- If you discover a file you need to edit that isn't in your list, note it in your completion message rather than editing it
- Follow existing code patterns and conventions in the codebase
```

## Usage Notes

- **Execution tools fill in `{placeholders}`** from the plan JSON. The template itself is static.
- **Pipeline steps are imperative.** Each step should be a clear action the agent can execute without interpretation.
- **Context files are read-only.** The agent should never modify files listed under context — only its owned files.
- **Interface contracts enable parallelism.** When agents run in parallel, imports describe what they can assume exists (from a prior execution phase), and exports describe what they must produce for the next phase.
- **Done criteria are verifiable.** Each criterion should be checkable (file exists, test passes, type compiles) — not subjective ("code is clean").
