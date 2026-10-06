# `spec/` — Workspace specifications

Cross-cutting contracts that every skill, agent, and runtime must honor.

| File | What it specifies |
|---|---|
| [`BANNED-VOCABULARY.md`](BANNED-VOCABULARY.md) | Words and phrases that must never appear in generated output (corporate-speak, AI-tells, stale clichés) |
| [`CONTEXT-THRESHOLDS.md`](CONTEXT-THRESHOLDS.md) | Per-skill `company.yaml` completeness gates — skills refuse to execute below threshold |
| [`RUNTIMES.md`](RUNTIMES.md) | Runtime contracts — how each adapter (`claude-code`, `manifest`, `http`) must behave |
