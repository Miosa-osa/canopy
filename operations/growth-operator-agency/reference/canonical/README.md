# reference/canonical/

Canonical specs + foundational theory. Referenced directly by SYSTEM.md boot sequence + INVARIANTS. to keep Growth Operating Agency focused on day-to-day use.

## What's here

- `AGENT-ARCHITECTURE.md` — the 82KB bible on agent structure (deep reference)
- `frameworks/signal-theory/` — Signal Theory 5-tuple, 4 principles, VSM mapping (the quality substrate)
- `frameworks/classical/` — persuasion research traditions (awareness spectrum, influence principles, cognitive biases, direct-response tradition)
- `frameworks/cult-methodology/` — authority-provocation archetype notes
- `spec/SIGNAL.md` — Signal Theory spec (runtime-level)
- `spec/QUALITY.md` — triple-layer verification gate spec
- `spec/BLIND-OUTPUT-TEST.md` — evaluator protocol spec
- `spec/INTEGRATIONS.md` — MCPs + API contracts (advanced integrations)
- `spec/HTTP-OPENAPI-ADAPTER.md` — REST adapter contract (future v1.1 target)

## Why it is separated

These files are:
1. **Academic** — foundational theory that the workspace rests on, but not needed for any creator who just wants to ship a VSL or design an offer.
2. **Future-facing** — the HTTP/OpenAPI adapter and integration specs target v1.1+; not used in v1.0.
3. **Deep reference** — dense methodology docs that inform the system's quality gates but do not change day-to-day operation.

If you are reading this because you want to go deep on why the workspace is structured the way it is — welcome. Start with `frameworks/signal-theory/README.md`.

If you are reading this because something broke — check the main workspace first (`spec/RUNTIMES.md`, `spec/CONTEXT-THRESHOLDS.md`, `spec/BANNED-VOCABULARY.md`). Those are still at the normal location.

---

*Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
