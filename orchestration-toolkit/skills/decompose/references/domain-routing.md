# Routing Heuristics & Fallback Table

This table is a **fallback** for when Phase 4's intent-driven registry search is inconclusive. The primary routing mechanism is semantic: classify the work intent → search the capability registry → select the best agent + skills. These heuristics provide fast-path shortcuts for common cases and a safety net for edge cases where the registry search returns ambiguous or no results.

## File Extension Routing

Extension matching is a starting point, not the final answer — context matters. A `.md` file in `skills/` is skill authoring work; a `.md` in `docs/` is likely a spec or prose document. Always let work intent override extension-derived routing.

| Extension(s) | Preferred Agent | Fallback Agent | Model | Skills |
|---|---|---|---|---|
| `.py` | python-pro | implementation-agent | sonnet | — |
| `.ts`, `.tsx` | typescript-pro | implementation-agent | sonnet | — |
| `.js`, `.jsx` | javascript-pro | implementation-agent | sonnet | — |
| `.css`, `.scss`, `.html` | frontend-developer | implementation-agent | sonnet | frontend-design:frontend-design |
| `.sh`, `.bash` | bash-pro | implementation-agent | sonnet | shell-scripting:bash-defensive-patterns |
| `.sql` | database-architect | implementation-agent | sonnet | — |
| `.swift` | ios-developer | implementation-agent | sonnet | — |
| `.dart` | flutter-expert | implementation-agent | sonnet | — |
| `.go` | implementation-agent | general-purpose | sonnet | — |
| `.rs` | implementation-agent | general-purpose | sonnet | — |
| `.java`, `.kt` | implementation-agent | general-purpose | sonnet | — |
| `.md` | general-purpose | implementation-agent | sonnet | — |
| `.json`, `.yaml`, `.toml` | implementation-agent | general-purpose | sonnet | — |
| `.dockerfile`, `Dockerfile` | deployment-engineer | implementation-agent | sonnet | — |

## Work Category Routing

| Category | Signal (how to detect) | Preferred Agent | Fallback Agent | Model | Skills |
|---|---|---|---|---|---|
| Test files | path contains `test`, `spec`, `__tests__`, or `_test` | test-runner | implementation-agent | sonnet | — |
| Specs / requirements | `.md` in `docs/`, `specs/`, or contains requirement keywords | general-purpose | general-purpose | opus | product-management:feature-spec |
| Code review | validation/review tasks, no file creation | Explore | Explore | opus | comprehensive-review:code-reviewer |
| Infrastructure | CI/CD configs, deploy scripts, k8s manifests | deployment-engineer | implementation-agent | sonnet | — |
| Security audit | auth, crypto, secrets, permissions files | security-auditor | implementation-agent | opus | — |
| Performance | profiling, benchmarks, load testing | performance-engineer | implementation-agent | sonnet | — |
| Data pipeline | ETL, streaming, data transformation | data-engineer | implementation-agent | sonnet | — |
| API design | OpenAPI, GraphQL schema, API routes | backend-architect | implementation-agent | sonnet | — |

## Claude Code Domain Heuristics

These examples teach the LLM how to route Claude Code artifact work. They are not an exhaustive lookup — when the registry contains a specialist that matches the work intent, prefer it over these heuristics.

| Work Pattern | Signals | Recommended Agent | Skills to Layer |
|---|---|---|---|
| Skill authoring | `SKILL.md`, files in `skills/`, skill references | implementation-agent | claude-code-development-kit:authoring-skills, superpowers:writing-skills |
| Hook development | `.sh` in hooks context, `settings.json` hook config | bash-pro | claude-code-development-kit:understanding-hooks, shell-scripting:bash-defensive-patterns |
| Command creation | `.md` in `commands/` | implementation-agent | claude-code-development-kit:creating-commands |
| Plugin development | `plugin.json`, `.claude-plugin/` structure | implementation-agent | claude-code-development-kit:creating-plugins |
| Agent authoring | `.md` in `agents/` directory | implementation-agent | claude-code-development-kit:authoring-agents, claude-code-development-kit:authoring-agent-prompts |
| Claude Code config | `settings.json`, `CLAUDE.md`, memory files | implementation-agent | claude-code-development-kit:best-practices-reference |
| MCP integration | MCP server configs, tool definitions | implementation-agent | claude-code-development-kit:integrating-mcps |

## Anti-patterns

Avoid these routing mistakes:

- Routing all `.md` files to `general-purpose` regardless of context — the directory and work intent matter more than the extension
- Defaulting to `implementation-agent` without checking the registry for a domain specialist
- Assigning agents by extension alone when the work category clearly indicates a specialist (e.g., a `.sh` file in a CI deploy context belongs to `deployment-engineer`, not `bash-pro`)
- Using the same agent type for >70% of work items — this signals routing underperformed and the decomposition likely missed meaningful domain variation

## Fallback Chain

When the preferred agent is unavailable (plugin not installed or disabled):

1. Check `enabled: true` in capability registry
2. If unavailable → use fallback agent from table above
3. If fallback also unavailable → `implementation-agent` (always available)
4. Set `missing_specialist: true` on the work item so downstream can warn

## Model Selection Heuristic

- **sonnet** (default): Implementation, editing, test writing — tasks where speed matters
- **opus**: Review, design decisions, complex reasoning — tasks where quality matters more than speed
- **haiku**: Simple lookups, formatting, data extraction — tasks where neither speed nor quality is critical
