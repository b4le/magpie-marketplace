# Domain Routing Table

Fallback lookup used by Phase 4 (Agent Matching) when the capability registry has no exact match for a file or work category. The decompose skill checks this table in order: file extension first, then work category.

## File Extension Routing

| Extension(s) | Preferred Agent | Fallback Agent | Model | Skills |
|---|---|---|---|---|
| `.py` | python-pro | implementation-agent | sonnet | — |
| `.ts`, `.tsx` | typescript-pro | implementation-agent | sonnet | — |
| `.js`, `.jsx` | javascript-pro | implementation-agent | sonnet | — |
| `.css`, `.scss`, `.html` | frontend-developer | implementation-agent | sonnet | frontend-design |
| `.sh`, `.bash` | bash-pro | implementation-agent | sonnet | bash-defensive-patterns |
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
| Specs / requirements | `.md` in `docs/`, `specs/`, or contains requirement keywords | general-purpose | general-purpose | opus | product-management |
| Code review | validation/review tasks, no file creation | Explore | Explore | opus | comprehensive-review |
| Infrastructure | CI/CD configs, deploy scripts, k8s manifests | deployment-engineer | implementation-agent | sonnet | — |
| Security audit | auth, crypto, secrets, permissions files | security-auditor | implementation-agent | opus | — |
| Performance | profiling, benchmarks, load testing | performance-engineer | implementation-agent | sonnet | — |
| Data pipeline | ETL, streaming, data transformation | data-engineer | implementation-agent | sonnet | — |
| API design | OpenAPI, GraphQL schema, API routes | backend-architect | implementation-agent | sonnet | — |

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
