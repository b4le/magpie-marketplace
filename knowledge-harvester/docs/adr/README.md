# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the knowledge-harvester plugin.

## What is an ADR?

An Architecture Decision Record captures an important architectural decision made along with its context and consequences. ADRs help future maintainers understand why certain decisions were made and what trade-offs were considered.

## ADR Format

Each ADR follows this template:
- **Title**: ADR-NNN: Brief description
- **Status**: Accepted | Proposed | Deprecated | Superseded
- **Context**: The issue or situation that motivates this decision
- **Decision**: The change that we're proposing or accepting
- **Consequences**: What becomes easier or more difficult because of this change

## Current ADRs

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-001](001-funnel-architecture.md) | Funnel Architecture | Accepted |
| [ADR-002](002-bash-only-harvest.md) | Bash-Only Harvest Stage | Accepted |
| [ADR-003](003-agent-model-selection.md) | Agent Model Selection | Accepted |
| [ADR-004](004-jsonl-intermediate-format.md) | JSONL Intermediate Format | Accepted |
| [ADR-005](005-schema-versioning.md) | Schema Versioning Strategy | Accepted |
| [ADR-006](006-checkpoint-design.md) | Checkpoint System Design | Accepted |
| [ADR-007](007-concurrency-strategy.md) | Concurrency and Batching Strategy | Accepted |

## Creating New ADRs

1. Create a new file following the naming pattern: `NNN-brief-description.md`
2. Use the next available number (e.g., 005)
3. Follow the standard ADR template
4. Update this README with the new ADR
5. Set initial status as "Proposed" until reviewed and accepted

## Superseding ADRs

When an ADR is superseded:
1. Update the old ADR's status to "Superseded by ADR-NNN"
2. Reference the old ADR in the new one's context
3. Keep the old ADR for historical reference
