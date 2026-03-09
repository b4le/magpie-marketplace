# Best Practices

## For Orchestrators

1. **Clear Workflow IDs**: Use descriptive, unique IDs (e.g., `feature-auth-20251124`, not `workflow1`)
2. **Token Budgets**: Allocate budgets per agent (via protocol) to prevent runaway context
3. **Phase README.md**: Always populate with clear objectives and constraints
4. **Monitor Early**: Check STATUS.yaml frequently to catch blockers early
5. **Archive Promptly**: Don't let completed phases linger in `active/` (creates clutter)
6. **Question Routing**: Use AskUserQuestion tool when sub-agent questions require user input

## For Sub-Agents

1. **Validate Context First**: Read and validate all context_files before executing
2. **Stay in Bounds**: Only write to assigned output_location
3. **Update Status**: Update STATUS.yaml whenever status changes (don't batch)
4. **Signal Clearly**: Use explicit status values (finished/needs-input/failed)
5. **Summarize Well**: Provide concise summary in return JSON (orchestrator may not read full output)
6. **Multi-File Index**: Always create READ-FIRST.md when outputting multiple files

## General

- **Consistent Naming**: Follow agent-{id}-{topic}.md pattern religiously
- **YAML Frontmatter**: Include in all markdown files for metadata tracking
- **Token Transparency**: Report tokens_used in return JSON
- **Progressive Disclosure**: Phase README.md should summarize, link to details
- **Archival Quality**: phase-summary.md should be standalone (future agents won't read archived raw files)
