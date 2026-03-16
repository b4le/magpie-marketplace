# Iterative Usability

**Version:** 1.1.0

Agents that improve how Claude Code explores codebases and researches topics — writing persistent findings to disk instead of bloating the main context window. Both agents follow a dual-return pattern: detailed output to disk, concise summary to caller.

## Features

- Codebase exploration with persistent findings to `local-state/exploration/{session}/`
- Web research with structured synthesis to `local-state/research/{session}/`
- Dual-return pattern: detailed disk output + concise inline summary (under 300 words)
- Hardened constraints: write-scope validation via `realpath`, Bash allowlists, prompt injection defense
- Graceful degradation for tool failures, empty results, and write errors
- Self-validation checklists enforce output contract compliance

## Installation

### Via Marketplace

```bash
claude plugin install iterative-usability@magpie-marketplace
```

### Manual Installation

Clone or copy the `iterative-usability/` directory into `~/.claude/plugins/local/iterative-usability/`.

## Quick Start

These agents are dispatched by an orchestrator, not invoked directly:

- **Codebase question:** dispatch `explore` with a question and optional thoroughness level (`quick`, `medium`, `very thorough`)
- **Web research:** dispatch `web-researcher` with a research question

Both write detailed findings to `local-state/` and return a concise summary under 300 words.

## Agents

| Agent | Purpose | Output Location | Model |
|-------|---------|-----------------|-------|
| `explore` | Codebase exploration — find files, trace patterns, answer architecture questions | `local-state/exploration/{session}/` | Sonnet |
| `web-researcher` | Web research — gather, distill, and synthesize information from multiple sources | `local-state/research/{session}/` | Opus |

### explore

Dispatched for codebase questions. Supports three thoroughness levels: `quick`, `medium` (default), `very thorough`. Writes findings as structured markdown with Summary, Key Findings, File Map, and Open Questions sections.

### web-researcher

Dispatched for questions requiring current web information. Uses a three-phase pipeline (Expand → Gather + Distill → Synthesize + Evaluate). Writes findings with confidence ratings and source citations.

## Dual-Return Pattern

Both agents follow the same contract:

1. **Write** detailed findings to their output directory (structured markdown)
2. **Return** a concise summary (under 300 words) with the output file path

This keeps the orchestrator's context window clean while preserving full fidelity on disk for downstream agents.

## Security

- **Write scope:** Both agents validate output paths with `realpath` before writing — only their designated output directories are writable
- **Bash allowlists:** Explicit lists of permitted commands; all other Bash usage is prohibited
- **Prompt injection defense:** File content (explore) and web content (web-researcher) are treated as untrusted data that cannot override agent constraints
- **No source modification:** Neither agent can edit, overwrite, or delete project files

## Troubleshooting

**Agent can't write findings to disk**
Ensure the working directory is writable and `local-state/` can be created. Both agents degrade gracefully — returning findings inline if disk writes fail.

**Explore agent seems slow**
Check the thoroughness level. `very thorough` uses 15-25 tool calls; `quick` uses 3-5. Default is `medium` (8-15 calls).

**Web-researcher returns partial results**
Check the `status` field in the summary. `partial` means the question was answered with caveats; `blocked` means sources couldn't be found. Both are honest assessments, not errors.

## Contributing

Contributions welcome. Please open an issue or pull request against the `magpie-marketplace` repository.

## License

MIT

## Version History

| Version | Changes |
|---------|---------|
| 1.1.0 | Hardened web-researcher: added Hard Constraints, prompt injection defense, dual-return disk persistence, write-scope validation, Bash allowlist. Expanded README and plugin metadata. |
| 1.0.0 | Initial release with explore and web-researcher agents |
