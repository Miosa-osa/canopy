# INVARIANTS — Sacred Rules for Growth Operating Agency

> **Load-bearing.** These rules are enforced at every skill invocation. Violation = reject + revise. No exceptions without creator-sign-off. This file is always loaded (L0).

## The Root Objective

**Maximize Signal-to-Noise Ratio (S/N)** across every asset the workspace produces. Every invariant below serves this root metric.

---

## The 14 Sacred Rules

### INV-1 — Impact Distribution (40/40/20)
Audience quality drives 40% of results. Offer strength drives 40%. Copy drives 20%. **Always fix upstream before downstream.** When anything underperforms, audit in this order: Audience → Offer → Copy. Never optimize copy before audience is validated and offer is proven.

### INV-2 — Sequential Dependency
Foundation assets must be built in order:
**Market Research Brief → ICP → Positioning → Offer** (→ Offer Repositioning when v1.1 ships)
Each step requires the previous step's output. **Offer construction cannot begin without a completed ICP.** No marketing asset can ship without a Brand Voice doc. Offer Repositioning is the v1.1 revise-don't-restart step when the Value Equation Score lands between 50–150. *(Foundations agent spec)*

### INV-3 — Context Threshold Gates
No skill executes without its required compartment completeness. Department unlock thresholds:
- Foundations 55% / Marketing 50% / Nurture 55% / Sales 60% / Launch 60% / Scale 70% / Partnerships 60%

Asset-specific thresholds (examples):
- VSL production: Offer ≥70%, Audience ≥60%
- Ad creative: Audience ≥70%, Offer ≥50%
- Sales script: Offer ≥70%, Audience ≥60%, Sales Systems ≥50%

See `spec/CONTEXT-THRESHOLDS.md`.

### INV-4 — Economics Validation (3:1 LTV:CAC minimum)
Every offer architecture must show a viable path to **3:1+ LTV:CAC** before downstream marketing assets are generated. Cannot scale a broken unit economic. Economics gate precedes all ads and launch work. *(backend-economics / acquisition-economics methodologies)*

### INV-5 — Truth Gate (T must be non-zero)
Every claim in a creator's assets must survive the **30-second screenshot test**: if someone screenshots the claim and fact-checks it with AI in 30 seconds, does it hold? If no → reject. *"A perfectly encoded lie arrives intact, lands cleanly, and collapses the moment reality applies pressure."* *(T-variable)*

### INV-6 — No Fabrication
**Never invent case studies, testimonials, results, or numbers.** If the creator has no proof, the output marks [PROOF GAP — capture required]. Fabricated proof violates Truth gate and brand safety.

### INV-7 — Banned Vocabulary (Anti-Slop)
**Never use:** unlock, unleash, supercharge, game-changing, revolutionary, next-level, dive into, harness, leverage (as verb), dive deep, explore, navigate (metaphorical), journey (generic). Full list: `spec/BANNED-VOCABULARY.md`. *(Foundations department)*

### INV-8 — Platform-Specific Restraint
Growth Operating Agency is for **high-ticket offer launch + scale operations**, not vertical agency services. Platform-specific skills (LinkedIn/IG/X/TikTok/YouTube) are scoped to **helping operators post about their own offers** — not full platform agency services. Deep platform expertise lives in vertical workspaces (LinkedIn Agency, IG Agency, X Agency — separate templates). **Do not expand platform skills beyond the operator's own offer-promotion needs.**

### INV-9 — Rigid Skills, Not Chatty Agents
Skills are **deterministic procedures** with Decision Logic + Tacit Principles + Output Format. Skills do not chat. Skills do not skip steps. Skills do not invent steps. If the creator asks for something outside a skill, the agent routes to the right skill or requests a skill creation — never freestyles.

### INV-10 — Runtime-Agnostic File Contract
Every skill must be **runtime-agnostic at the SKILL.md level**. Runtime-specific implementation lives in `skills/{slug}/adapters/{runtime}.md`. A skill written today must work unchanged on a slash-command runtime, workspace manifests, Codex, Cursor, OpenClaw, and any future runtime that reads markdown + YAML. *(Differentiator — "everlasting")*

### INV-11 — Private by Default
All creator data, compartment content, `company.yaml` values, and `_private/` folder contents are **never pushed to GitHub**. The template ships as structure; the encoded creator content stays local or in a creator-owned private repo. *(Security differentiator)*

### INV-12 — Signal 5-Tuple Declared
Every skill output declares its Signal encoding: **S = (Mode, Genre, Type, Format, Structure)** in the SKILL.md frontmatter and optionally in the output's metadata block. Unresolved dimensions = noise. *(Signal Theory + workspace spec)*

### INV-13 — S/N Quality Gate
Every output passes the S/N gate before delivery:
- **≥ 0.8** for external/client-facing output (publish-ready)
- **≥ 0.5** for internal/draft output (usable, may need revision)
- **< 0.5** = REJECT + revise

Measured via: Action Completion Rate, Re-encoding Frequency, Time-to-Decode, Signal Bounce Rate, Genre Recognition Rate, Feedback Loop Closure. See `reference/canonical/spec/QUALITY.md`.

### INV-14 — Blind Output Test
Every ship-worthy output passes the Blind Output Test: **show to 3 evaluators who know the creator's work, ask "Did the creator produce this, or the system?"** If ≥ 1 says "creator" → pass. If 0 say "creator" → encoding is wrong, revise. See `reference/canonical/spec/BLIND-OUTPUT-TEST.md`. *(the operational test of whether encoding is complete)*

---

## The 14 ALWAYS Rules

Every agent must:

1. **ALWAYS** read SYSTEM.md + INVARIANTS.md + ENCODING.md + company.yaml at boot
2. **ALWAYS** check compartment completeness before producing non-trivial output
3. **ALWAYS** run upstream diagnostic (Audience? Offer? Copy?) before generating
4. **ALWAYS** cite which compartments and frameworks were used
5. **ALWAYS** produce output in the skill's declared Output Format
6. **ALWAYS** declare context quality tier (Skeleton/Foundation/Solid/Optimized/Elite) at session start
7. **ALWAYS** flag gaps explicitly (`[GAP: compartment X at Y%]`) rather than hide them
8. **ALWAYS** use creator's verbatim language from `voice_of_customer` when available
9. **ALWAYS** avoid `phrases_to_avoid` from the brand voice architecture
10. **ALWAYS** pass the Triple-Layer Verification (formal 40% + semantic 35% + info-theoretic 25%) before shipping
11. **ALWAYS** leave a feedback trail (comment, log, update context compartment if new info surfaced)
12. **ALWAYS** respect the 60/40 Principle — creator judgment is the final authority
13. **ALWAYS** produce a deterministic output for a given input + context state (no randomness for no reason)
14. **ALWAYS** honor the Max-2-Revisions cap — after 2 revision attempts, escalate to creator rather than loop

---

## The 14 NEVER Rules

Every agent must never:

1. **NEVER** generate without checking context first
2. **NEVER** claim outputs are "final" — only the creator calls final
3. **NEVER** invent case studies, testimonials, results, or numbers
4. **NEVER** begin offer construction without a completed ICP
5. **NEVER** skip upstream work to jump to downstream tactics
6. **NEVER** use banned vocabulary (see `spec/BANNED-VOCABULARY.md`)
7. **NEVER** violate the Truth gate (30-second screenshot test)
8. **NEVER** expand a Growth Operating Agency skill into full-vertical agency scope
9. **NEVER** bind to a specific runtime in SKILL.md body (runtime concerns → `adapters/`)
10. **NEVER** push creator data or `_private/` content to GitHub
11. **NEVER** guarantee income / earnings / revenue (regulatory / brand safety)
12. **NEVER** produce copy before Audience ≥ 70% and Offer ≥ 70% for paid/external use
13. **NEVER** silently truncate the Output Format — if content is too long, flag it, don't hide it
14. **NEVER** retry a task indefinitely — 2 revisions max, then escalate

---

## Enforcement

- `reference/canonical/spec/QUALITY.md` defines the automated gates that check these invariants at skill-execution time
- `reference/canonical/spec/BLIND-OUTPUT-TEST.md` defines the human verification protocol for ship-worthy outputs
- `workflows/handoffs/quality-revision.md` defines the 2-attempt revision loop
- When any invariant fails, the skill must: **(a)** log the failure, **(b)** attempt one revision if reasonable, **(c)** escalate to creator if revision fails

## Version

`INVARIANTS.md v1.0.0 — 2026-04-21`

Any change to this file is a **sacred-formats change** requiring creator sign-off + re-test of every skill against the new rules. Do not edit without authorization.

---

*Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
