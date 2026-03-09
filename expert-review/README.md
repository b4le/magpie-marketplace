# Expert Review

**Version:** 1.2.0

Spawn expert sub-agents to review, iterate, and improve work at orchestration checkpoints.

## Features

- Parallel expert review using isolated git worktrees per reviewer
- Auto-detection of relevant expertise domains from file types and keywords
- Conflict resolution via domain precedence matrix
- Modifier agents apply fixes directly; analyzer agents return recommendations only
- Checkpoint detector hook that suggests reviews at natural review points

## Installation

### Via Marketplace

```bash
claude plugin install expert-review@content-platform-marketplace
```

### Manual Installation

Clone or copy the `expert-review/` directory into `~/.claude/plugins/local/expert-review/`.

## Quick Start

```bash
/expert-review                      # Auto-detect experts from recent changes
/expert-review security             # Security-focused review
/expert-review security backend     # Multiple expertise areas
/expert-review --report-only        # Recommendations only, no changes
```

## Skills

| Skill | Description | Invoke |
|-------|-------------|--------|
| `expert-review` | Orchestrate parallel expert reviews of code changes | `/expert-review:expert-review` |

## Commands

| Command | Description | Invoke |
|---------|-------------|--------|
| `expert-review` | Spawn expert sub-agents for code review | `/expert-review` |

## How It Works

### Phase 1: Expert Discovery
- Parses arguments or auto-detects from git changes
- Scans installed plugins for matching agents
- Returns ranked list of experts to spawn

### Phase 2: Parallel Review
- Spawns experts in parallel with isolated git worktrees
- Modifier agents make confident fixes directly
- Analyzer agents return recommendations only

### Phase 3: Consolidation
- Merge coordinator combines all results
- Deduplicates findings across experts
- Resolves conflicts using domain precedence

### Phase 4: Cleanup
- Removes worktrees (even on failure)
- Returns structured summary

## Expertise Areas

| Domain | Priority | Type | Matches |
|--------|----------|------|---------|
| security | 5 | modifier | `*security*`, `*appsec*`, `*threat*` |
| accessibility | 4 | analyzer | `*accessibility*`, `*a11y*` |
| architecture | 3 | modifier | `*architect*`, `*design*` |
| infrastructure | 3 | modifier | `*cloud*`, `*kubernetes*`, `*terraform*` |
| performance | 2 | modifier | `*performance*`, `*optim*` |
| database | 2 | modifier | `*database*`, `*sql*` |
| backend | 1 | modifier | `*api*`, `*backend*` |
| frontend | 1 | modifier | `*frontend*`, `*ui*`, `*react*` |
| testing | 0 | modifier | `*test*`, `*qa*`, `*tdd*` |

## Conflict Resolution

When experts disagree, higher precedence wins:

```
Security > Accessibility > Architecture > Performance > Backend > Testing
```

If precedence and confidence are equal, the user is prompted.

## Auto-Detection

When no expertise specified, the plugin detects domains from:

- **File extensions**: `.py` → python, `.tsx` → typescript + frontend
- **Topic keywords**: `auth|jwt` → security, `k8s|helm` → infrastructure

## Configuration

- `config/expertise-patterns.yaml` - Domain to agent pattern mappings
- `config/precedence-matrix.yaml` - Conflict resolution rules

## Agents

| Agent | Purpose |
|-------|---------|
| `expert-mapper` | Discovers and selects appropriate reviewers |
| `domain-reviewer` | Template for domain-specific expert reviews |
| `merge-coordinator` | Consolidates results and resolves conflicts |

## Hooks

The plugin includes a checkpoint detector hook that suggests running `/expert-review` when it detects review checkpoints in conversation.

## Security

- Path traversal protection in worktree validation
- Command injection prevention
- Input size limits and timeouts
- Confirmation required for destructive rollback operations

## Troubleshooting

If `/expert-review` finds no experts, ensure domain-specific agent plugins are installed and that their agent filenames match the patterns in `config/expertise-patterns.yaml`. Run `/expert-review --report-only` to surface recommendations without modifying files while diagnosing issues.

## Contributing

Contributions are welcome. Please open an issue or pull request against the `content-platform-marketplace` repository.

## License

MIT

## Version History

| Version | Changes |
|---------|---------|
| 1.2.0 | Current release |
