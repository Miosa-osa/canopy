# FAQ

Common questions. Read [QUICKSTART](QUICKSTART.md) first if you have not yet run the workspace.

---

## What is Growth Operating Agency?

A workspace template that encodes the go-to-market operation of a high-ticket creator business as runtime-agnostic files — markdown, YAML, and a specific folder contract. Any LLM that reads markdown and YAML can execute it.

## What is it not?

Not a chatbot. Not a SaaS. Not a plugin. Not a platform. It is files on disk that you own.

## Who is it for?

Creators, coaches, consultants, and founders running high-ticket offers ($2K+) who want the encoded version of their own operation running under them — not a tool they rent.

## Why not just use ChatGPT or Claude directly?

You can. But chat without an encoded workspace is stateless and un-calibrated. Every conversation starts from zero. Growth Operating Agency gives the LLM a real substrate — your positioning, your ICP, your offer, your voice — before it writes a single word. That is what makes the output land.

---

## Runtime

### What runtimes does it support?

- **slash-command runtime** — primary v1 target. Full slash command bindings at `.claude/commands/`.
- **workspace manifests** — primary v1 target. Adapter per skill at `skills/{slug}/adapters/manifest.yaml`.
- **Codex, Cursor, OpenClaw** — v2 targets, adapter scaffolding.
- **HTTP / OpenAPI** — v1.1 target, contract at `reference/canonical/spec/HTTP-OPENAPI-ADAPTER.md`.
- **Any generic LLM** — always available. Paste `SYSTEM.md` as system prompt, paste relevant `company.yaml` compartments as context, invoke a skill by pasting its `SKILL.md`.

### What if a runtime I use is not supported?

Write a new adapter. The pattern is documented in [SKILL_AUTHORING.md](SKILL_AUTHORING.md). Runtime-specific concerns never touch `SKILL.md`.

### What if the slash-command runtime is deprecated tomorrow?

The workspace still runs. Swap the runtime. Layer 3 rebuilds; Layer 1 and Layer 2 are untouched. This is the runtime-agnostic guarantee in [INV-10](../INVARIANTS.md).

---

## Privacy and data

### Is my creator data safe?

The template enforces a hard split between structure (shippable) and encoded creator data (never shippable). `.gitignore` covers `company.yaml` (once filled), `_private/`, `output/`, and `.env*`. Per [INV-11](../INVARIANTS.md), creator data never pushes to public repos.

### Can I commit a filled `company.yaml`?

Only to a private repo that the creator owns. Never to a shared or public repo. The Heuresis template always ships with the empty form.

### Where do credentials live?

In `.env.local`, gitignored. The `.env.template` shows variable names only. Rotate any credential that enters the repo history, even if deleted in a later commit — git history retains removed values.

---

## Instantiation

### How do I fork this for a new creator?

Clone into a new workspace, reset `company.yaml` to the empty-template form, start `_private/` and `output/` empty, verify `.gitignore` is intact, and run `/research` to start the Foundations chain. See [QUICKSTART](QUICKSTART.md).

### Can I modify skills for a specific creator?

Yes. Fork the skill's `SKILL.md` body inside the creator's workspace. The Heuresis template stays canonical; per-creator customization lives in the creator's own fork. Upstream the change back to the Heuresis template only if it generalizes.

### How long does instantiation take?

The template ships in minutes. The creator context profile takes 30–90 minutes of creator attention for cycle 1, then deepens every cycle after. Full Foundations validation (Audience ≥ 70%, Offer ≥ 70%, Voice captured) typically lands in week 2 of active work.

---

## Skills and agents

### Why 29 skills and not 42?

29 are shipped, every one with a real `SKILL.md` body of 147–650 lines, real adapters, and real evidence scaffolding. Skills are added when operations ask for them — not to hit a target. The roadmap in [`skills/_INDEX.md`](../skills/_INDEX.md) lists future skills that will ship when real need surfaces.

### Why 41 agents and not 36?

Earlier drafts assumed 1 director + 7 leads + 28 specialists. Reality hired 33 specialists as the roster matured (adding `vsl-builder`, `vsl-writer` split, `competitor-analyst`, `case-study-producer`, `financial-modeler`, etc.). Agents are thin — the scaling cost is near-zero.

### Can an agent own multiple skills?

Yes. Several do — `email-copywriter` owns `email-sequence` and `post-booking-nurture`. `lead-magnet-designer` dual-reports to `marketing-head` and `nurture-head`. See [`agents/_INDEX.md`](../agents/_INDEX.md) for the routing.

---

## Quality

### What stops the workspace from producing slop?

Three gates:

1. Banned vocabulary list at [`spec/BANNED-VOCABULARY.md`](../spec/BANNED-VOCABULARY.md). Hard reject.
2. Triple-layer verification (formal 40% + semantic 35% + info-theoretic 25%) per [`reference/canonical/spec/QUALITY.md`](../reference/canonical/spec/QUALITY.md).
3. Blind Output Test for ship-worthy outputs per [`reference/canonical/spec/BLIND-OUTPUT-TEST.md`](../reference/canonical/spec/BLIND-OUTPUT-TEST.md).

### What is the Blind Output Test?

Three evaluators who know the creator's work see the output and answer: did the creator produce this, or the system? At least one saying "creator" or "can't tell" equals pass. Zero equals revise. Tiered by skill — sacred-format skills require 3/3, external skills require 2/3, internal skills require 1/3.

### How do I know encoding is working?

Watch the S/N score over time. Watch compartment completeness. Watch blind-test pass rate per skill. If you are in cycle 3+ and still flunking blind tests, the Audience or Offer compartment is wrong — not the copy.

---

## Heuresis

### What is Heuresis?

The studio that built Growth Operating Agency. Heuresis builds encoded workspaces as the deliverable product — not consulting engagements, not a SaaS platform. See [PROVENANCE.md](../PROVENANCE.md).

### Why is this private?

The v1.0 template is the first Heuresis workspace shipping under the Heuresis brand. Distribution, licensing, and public release sequencing are being decided based on how the first few instantiations perform. The private phase is the operational phase.

### Can I contribute?

See [CONTRIBUTING.md](../CONTRIBUTING.md). Heuresis accepts contributions from named collaborators. The quality bar is high — skills ship only with adapters, evidence scaffolding, and a banned-vocab-clean `SKILL.md`.

---

## Troubleshooting

### A skill refused to execute — what does that mean?

It means the required compartments are below threshold. The workspace will not produce from null. Run the upstream skill (typically `/research` or the specific Foundations skill for that compartment) and try again.

### The output has `[GAP: compartment X at 45%]` — is that a bug?

No. That is the skill honestly flagging what it inferred versus what is real. Fill compartment X further and re-run.

### The blind-output test is failing — where do I look?

Audience and Offer first. Copy third. Per [INV-1](../INVARIANTS.md), most failures upstream from copy are actually audience or offer misses. Check the creator's voice-of-customer entries in Compartment 2 — are they verbatim, or paraphrased? Paraphrased VOC is the most common blind-test failure mode.

### A banned word slipped through — what now?

It should not have. The triple-layer gate catches banned vocabulary. If one landed in a shipped artifact, file an issue against the `formal-verification` layer with the skill slug and the output path.

---

*Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
