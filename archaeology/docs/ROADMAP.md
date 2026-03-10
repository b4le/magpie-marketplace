# Archaeology Plugin Roadmap

> Backlog items identified from v1.4.0 review (2026-03-10). Prioritised as P3 — consider later.

## P3 — Enhancements

### Conservation + Dig cross-mode data flow
**Source:** Architecture review

Dig tracks `prior_outputs.artifacts` but the rig operator doesn't receive artifact content as seed context. Conservation's C2 doesn't consume dig nuggets either. Currently one-way flow only (survey → dig). Adding bidirectional flow would make conservation benefit from deep investigations and vice versa.

**Suggested approach:** Have the rig operator's `init` mode receive a `conservation_artifacts_summary` parameter when `prior_outputs.artifacts` is true. Have conservation's C2 check for `spelunk/*/nuggets/` as additional narrative seeds alongside `findings.json`.

---

### Register planned domains in registry.yaml
**Source:** Architecture review

`python-practices.md` references two sibling domains — `testing-patterns` and `api-design` — as planned but neither appears in `registry.yaml` even with `status: planned`. Adding them with `status: planned` would make `check-registry-sync.sh` aware of their existence and surface them in `/archaeology list` output.

---

### Explicit trove.md regeneration step in D7
**Source:** Architecture review

The state model correctly states trove.md is "regenerated from nuggets + veins each cycle — never appended to directly", but no numbered step in D7 shows the actual write logic. Adding an explicit D7b sub-step with the regeneration algorithm would remove ambiguity.

---

### Router: unknown command handling
**Source:** Skill review

`/archaeology typo` falls through to domain extraction silently, producing "Domain 'typo' not found". Adding a fuzzy match or "did you mean?" suggestion before the domain fallback would improve UX. Alternatively, an explicit catch-all with a helpful error listing valid commands.

---

### Acknowledge `dig list` in router
**Source:** Skill review

`/archaeology dig list` works because `"list"` is passed as the subject to `execute_dig()`, which handles it internally. But the main router reads as if this case is unhandled. Adding a comment or an explicit `args.subject === 'list'` early return in the router would clarify intent.

---

### Guard `--global` flag at router level
**Source:** Skill review

`argument-hint` implies `--global` works everywhere but it's only valid for `workstyle`. Passing `--global` to survey, conserve, or dig silently does nothing. Adding a router-level guard that warns "—global is only supported for workstyle" would prevent confusion.

---

*Last updated: 2026-03-10*
