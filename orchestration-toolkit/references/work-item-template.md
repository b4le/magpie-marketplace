# Work Item Prompt Template

Converts a plan JSON work item into the prompt sent to each agent. Used by all dispatch modes (sequential, fan-out, team).

## Model

The orchestrator reads a work item from plan.json and fills in this template before passing it to an agent. Every agent receives exactly this information — no more, no less. Sections with no data are omitted entirely.

**Core constraint:** The owned files list is a hard boundary. Agents must not create or modify any file not in that list. The pipeline is ordered — agents must follow steps in sequence, not in parallel and not out of order.

**Anti-patterns to avoid:**
- Passing raw plan JSON to the agent and asking it to interpret the schema. Fill in the template first.
- Including sections with empty values (empty `files`, empty `inputs`). Omit them — blank sections waste context and invite hallucination.
- Omitting `project_root` when it is set. Agents use it to resolve relative paths.

## Template

Fill in `{placeholders}` from plan JSON before sending. Omit any section whose placeholder value is empty or null.

```
You are working on: {title} ({id})

Scope: {scope}

{? Project root: {project_root} — resolve all relative paths from here.}

## Owned Files
You may ONLY create or modify these files. Do not touch any other file.

{files}

{? ## Context Files (read-only)
Read these for context. Do not modify them.

{inputs.context_files}}

{? ## Pre-Fetched Data
External data has been gathered for you. Read these files with the Read tool.

{inputs.prefetch_paths}}

## Pipeline
Follow these steps in order. Complete each before starting the next.

{pipeline}

{? ## Interface Contracts
Your work item has the following interface obligations.

{? Exports you must provide:
{interface_contracts.exports}}

{? Imports you depend on (already available):
{interface_contracts.imports}}}

## Done Criteria
Verify each of these before reporting complete:

{done_criteria}

## Constraints
- Owned files list is a hard boundary. Do not create or edit any file not listed above.
- Follow the pipeline steps in the order given.
- Do not modify context files.
- Report any blockers immediately rather than working around them.
```

## Field Mapping

| Template placeholder | plan JSON path | Notes |
|---|---|---|
| `{id}` | `work_item.id` | Required. Format: `WI-{N}`. |
| `{title}` | `work_item.title` | Required. |
| `{scope}` | `work_item.scope` | Required. |
| `{project_root}` | `plan.project_root` | Omit section if null or empty. |
| `{files}` | `work_item.files` | One file per line. Omit section if empty array. |
| `{inputs.context_files}` | `work_item.inputs.context_files` | One file per line. Omit section if empty array. |
| `{inputs.prefetch_paths}` | `work_item.inputs.prefetch_paths` | One path per line. Omit section if empty array. |
| `{pipeline}` | `work_item.pipeline` | Numbered list. Required — pipeline is always present. |
| `{interface_contracts.exports}` | `work_item.interface_contracts.exports` | One entry per line. Omit sub-block if empty. Omit whole section if both exports and imports are empty. |
| `{interface_contracts.imports}` | `work_item.interface_contracts.imports` | One entry per line. Omit sub-block if empty. |
| `{done_criteria}` | `work_item.done_criteria` | Checkbox list. Required. |

Sections marked `{? ... }` in the template are conditional — include them only when the corresponding field is non-empty.

## Guidance for Orchestrators

- **Fill before sending.** Never forward raw plan JSON to an agent. Render the template first. Agents should not need to understand the plan schema.
- **Omit empty sections.** An empty "Context Files" section wastes tokens and invites the agent to invent inputs. If `context_files` is an empty array, drop the section entirely.
- **Number the pipeline steps.** Convert `pipeline` array to a numbered list (`1. Read context files`, `2. Implement changes`, ...). Agents follow numbered lists more reliably than bullets.
- **Format files as one per line.** For owned files and context files, one path per line is easier to scan and quote than comma-separated.
- **Format done criteria as a checklist.** Use `- [ ] {criterion}` so the agent can self-check before returning.
- **Team mode difference.** In team mode, the template body becomes the `description` field of a `TaskCreate` entry. The `title` field maps to `subject`. `addBlockedBy` is set separately from `depends_on` — do not embed it in the description.
- **Missing specialist flag.** If `agent_config.missing_specialist` is true, prepend a note to the prompt: `Note: no specialist agent is available for this work item. A general-purpose agent will be used.` Do not change the template body.
- **Skills go in the prompt.** For each entry in `agent_config.skills`, prepend a line to the prompt: `"Invoke skill: {skill-name} before implementation"`. Skills are not Agent tool parameters — they are instructions the agent follows.
- **Do not add other agent_config fields to the prompt.** `subagent_type`, `model`, `isolation`, and `max_turns` are orchestrator-level routing parameters. They configure the Agent tool call, not the agent's instructions.
