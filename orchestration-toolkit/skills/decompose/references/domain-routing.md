# Routing Heuristics & Fallback Table

This table is a **fallback** for when Phase 4's intent-driven registry search is inconclusive. The primary routing mechanism is semantic: classify the work intent → search the capability registry → select the best agent + skills. These heuristics provide fast-path shortcuts for common cases and a safety net for edge cases where the registry search returns ambiguous or no results.

## File Extension Routing

Extension matching is a starting point, not the final answer — context matters. A `.md` file in `skills/` is skill authoring work; a `.md` in `docs/` is likely a spec or prose document. Always let work intent override extension-derived routing.

| Extension(s) | Preferred Agent | Fallback Agent | Model | Skills |
|---|---|---|---|---|
| `.py` | python-pro | general-purpose | sonnet | — |
| `.ts`, `.tsx` | typescript-pro | general-purpose | sonnet | — |
| `.js`, `.jsx` | javascript-pro | general-purpose | sonnet | — |
| `.css`, `.scss`, `.html` | frontend-developer | general-purpose | sonnet | frontend-design:frontend-design |
| `.sh`, `.bash` | bash-pro | general-purpose | sonnet | shell-scripting:bash-defensive-patterns |
| `.sql` | database-architect | general-purpose | sonnet | — |
| `.swift` | ios-developer | general-purpose | sonnet | — |
| `.dart` | flutter-expert | general-purpose | sonnet | — |
| `.go` | *No specialist* [^1] | general-purpose | sonnet | — |
| `.rs` | *No specialist* [^1] | general-purpose | sonnet | — |
| `.java`, `.kt` | *No specialist* [^1] | general-purpose | sonnet | — |
| `.md` | general-purpose | general-purpose | sonnet | — |
| `.json`, `.yaml`, `.toml` | *No specialist* [^1] | general-purpose | sonnet | — |
| `.dockerfile`, `Dockerfile` | deployment-engineer | general-purpose | sonnet | — |

[^1]: No installed specialist. Route via specialist-routing.md Steps 2A→2D. Set `missing_specialist: true` with one-line justification.

> **Note:** Fallback agent (`general-purpose`) requires a registry check per specialist-routing.md before assignment.

## Work Category Routing

| Category | Signal (how to detect) | Preferred Agent | Fallback Agent | Model | Skills |
|---|---|---|---|---|---|
| Test files | path contains `test`, `spec`, `__tests__`, or `_test` | test-runner | general-purpose | sonnet | — |
| Specs / requirements | `.md` in `docs/`, `specs/`, or contains requirement keywords | general-purpose | general-purpose | opus | product-management:feature-spec |
| Code review | validation/review tasks, no file creation | Explore | Explore | opus | comprehensive-review:code-reviewer |
| Infrastructure | CI/CD configs, deploy scripts, k8s manifests | deployment-engineer | general-purpose | sonnet | — |
| Security audit | auth, crypto, secrets, permissions files | security-auditor | general-purpose | opus | — |
| Performance | profiling, benchmarks, load testing | performance-engineer | general-purpose | sonnet | — |
| Data pipeline | ETL, streaming, data transformation | data-engineer | general-purpose | sonnet | — |
| API design | OpenAPI, GraphQL schema, API routes | backend-architect | general-purpose | sonnet | — |
| Plugin/skill development | `plugin.json`, `SKILL.md`, `.claude-plugin/`, `agents/` | `plugin-dev:agent-creator` | `general-purpose` [^1] | sonnet | — |
| Legacy migration | Modernizing, upgrading, framework swap | `framework-migration:legacy-modernizer` | `general-purpose` [^1] | opus | — |
| Architecture review | System design, multi-service, trade-offs | `comprehensive-review:architect-review` | `general-purpose` | opus | — |
| Debugging | Bug investigation, root cause analysis | `debugging-toolkit:debugger` | `general-purpose` [^1] | sonnet | — |

## Claude Code Domain Heuristics

These examples teach the LLM how to route Claude Code artifact work. They are not an exhaustive lookup — when the registry contains a specialist that matches the work intent, prefer it over these heuristics.

| Work Pattern | Signals | Recommended Agent | Skills to Layer |
|---|---|---|---|
| Skill authoring | `SKILL.md`, files in `skills/`, skill references | `plugin-dev:skill-reviewer` | claude-code-development-kit:authoring-skills, superpowers:writing-skills |
| Hook development | `.sh` in hooks context, `settings.json` hook config | bash-pro | claude-code-development-kit:understanding-hooks, shell-scripting:bash-defensive-patterns |
| Command creation | `.md` in `commands/` | *No specialist* [^1] | claude-code-development-kit:creating-commands |
| Plugin development | `plugin.json`, `.claude-plugin/` structure | `plugin-dev:plugin-validator` | claude-code-development-kit:creating-plugins |
| Agent authoring | `.md` in `agents/` directory | `plugin-dev:agent-creator` | claude-code-development-kit:authoring-agents, claude-code-development-kit:authoring-agent-prompts |
| Claude Code config | `settings.json`, `CLAUDE.md`, memory files | *No specialist* [^1] | claude-code-development-kit:best-practices-reference |
| MCP integration | MCP server configs, tool definitions | *No specialist* [^1] | claude-code-development-kit:integrating-mcps |

## Anti-patterns

Avoid these routing mistakes:

- Routing all `.md` files to `general-purpose` regardless of context — the directory and work intent matter more than the extension
- Defaulting to `general-purpose` without checking the registry for a domain specialist
- Assigning agents by extension alone when the work category clearly indicates a specialist (e.g., a `.sh` file in a CI deploy context belongs to `deployment-engineer`, not `bash-pro`)
- Using the same agent type for >70% of work items — this signals routing underperformed and the decomposition likely missed meaningful domain variation
- Listing `general-purpose` as preferred in routing tables without running through specialist-routing.md Steps 2A→2D

## Fallback Chain

When the preferred agent is unavailable (plugin not installed or disabled):

1. Check `enabled: true` in capability registry
2. If unavailable → use fallback agent from table above
3. If fallback also unavailable → `general-purpose` (always available)
4. Set `missing_specialist: true` on the work item so downstream can warn

## Model Selection Heuristic

- **sonnet** (default): Implementation, editing, test writing — tasks where speed matters
- **opus**: Review, design decisions, complex reasoning — tasks where quality matters more than speed
- **haiku**: Simple lookups, formatting, data extraction — tasks where neither speed nor quality is critical
