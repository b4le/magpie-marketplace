# Two-Tier Verification Pattern

Reusable checkpoints for multi-phase pipelines. Add at each phase boundary where bad output would corrupt downstream work.

## Model

**Tier 1 — Deterministic gate (hard stop):** Check that the phase produced its expected artifact. File exists, non-empty, correct format, passes any available validator. Failure = stop and report. Do not proceed with bad input.

**Tier 2 — LLM judge (soft gate):** Evaluate the output against what the phase was supposed to accomplish. Compare produced vs requested. Failure = warn and self-correct rather than hard-block. The judge asks: "Does this output actually answer the question it was supposed to answer?"

The asymmetry is intentional: deterministic failures (missing file, parse error) are unrecoverable and must stop immediately. Quality failures (incomplete, off-topic) benefit from one correction attempt before escalating.

## Template

Use this block at each phase boundary. Adapt `[output]`, `[validator]`, and `[goal]` to the skill's context.

```
#### Phase N Verification
Before proceeding:
- **Tier 1:** Confirm `{expected output}` exists and is non-empty. If a schema or validator exists, run it now. Hard stop if this fails — report what's missing.
- **Tier 2:** Review output against Phase N goal: "{stated goal}". Flag and self-correct if output is off-topic, missing key sections, or contradicts the input. Proceed after one correction attempt.
```

## Guidance for Skill Authors

- Keep checks minimal — 2-4 lines per phase boundary
- Match the skill's existing terminology ("Stage", "Step", "Phase", "Scan")
- Tier 1 checks should be unambiguous: a file path, a key field name, a validator script
- Tier 2 checks should reference the phase's stated goal verbatim where possible
- Don't add verification to single-phase skills or parallel data-gathering steps that already have "if fails, skip" logic
- If a phase already has error handling, enhance it rather than duplicating

## Rationale

Research from multi-agent systems (Spotify Honk, PwC audit agents) shows that adding judge verification between pipeline stages can improve end-to-end accuracy by 7x. The key mechanism: agents self-correct ~50% of quality failures when given explicit feedback, and judge vetoes prevent ~25% of bad outputs from propagating to downstream stages.
