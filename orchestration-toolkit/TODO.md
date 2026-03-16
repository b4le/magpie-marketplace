# Orchestration Toolkit — TODO

## P1
- [ ] **Dispatch-routing-guard hook**: Runtime enforcement that catches `general-purpose` assignment without justification. Prompt-level fixes (domain-routing.md, SKILL.md) can still be cognitively bypassed.

## P2
- [ ] **Source priority mismatch**: `capability-aware-dispatch.md` says user-agent > plugin-agent, but `build-capability-registry.sh` implements plugin-agent (rank 0) > user-agent (rank 1). Reconcile.
- [ ] **70% guard insufficiency**: The per-plan 70% language concentration guard should also gate per-task. A 60% Go project routes all Go to general-purpose and passes.
- [x] **Registry domain_tags for implementation-agent**: Moot — `implementation-agent` removed from the registry entirely; `general-purpose` was already present with correct tags.
