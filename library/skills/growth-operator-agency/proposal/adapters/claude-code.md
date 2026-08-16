---
description: Produce a 1-page post-call proposal for a $3K-$50K program — 7 sections, prospect-specific references, preserved risk reversal, single CTA. Delivered within 2 hours of call close.
argument-hint: [prospect name or call brief ID; optional: "--call-notes=<inline notes>"]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /proposal — slash-command runtime Runtime Binding

Load and execute `skills/proposal/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/proposal/SKILL.md` (full body)
   - `Read` upstream: `output/design-offer/` (Offer Doc — price, guarantee, deliverables required), `output/build-positioning/` (mechanism name), `output/extract-voice/` (phrases_to_use), `output/call-prep/{prospect-slug}.md` (Call Brief), and call notes (supplied in `$ARGUMENTS` or referenced externally)
   - read `reference/frameworks/sales/value-stack-architecture.md`, `reference/frameworks/primitives/value-equation.md`, `reference/operators/offer-architect.md`

2. **Pre-flight check:** Verify `offer_architecture >= 70`, `conversion_sales_systems >= 50`, `copy_messaging >= 40` in `company.yaml`. Confirm call notes available (what was agreed — price, payment option, kickoff date, any customization). If no call notes, HOLD with specific gap ("call notes missing — cannot ratify without knowing what was agreed").

3. **Execute Phase 0 -> Phase 8** per SKILL.md Process: Context Load -> Context Validation -> Prospect Personalization Pull -> Write 7 Sections -> Voice-Match Pass -> Compliance Check -> One-Page Constraint Check -> Quality Gates -> Delivery Package.

4. **Write output:**
   - `Write` to `output/proposal/{YYYY-MM-DD}-proposal-{prospect-slug}.md` (markdown source for log)
   - Produce formatted send version (PDF or email-body) as secondary output
   - Structure per SKILL.md Output Format — 7 sections, 400-700 words, single page
   - Mark `[PROOF GAP]` if any cited deliverable lacks corresponding Offer Doc entry

5. **Delivery discipline:**
   - Proposal must be produced within 2 hours of call close (log timestamp)
   - If > 2 hours have passed and prospect hasn't received proposal, flag as stale

6. **Post-ship:**
   - write `skills/proposal/evidence/runs/{YYYY-MM-DD}-run.md` with close-status logged + compliance-check results + delivery-time logged
   - Update CRM with prospect + proposal + close-status
   - Trigger `/post-booking-nurture` for pre-kickoff sequence

## Arguments

`$ARGUMENTS` expects prospect identifier + optional call notes. Example: `{prospect-slug} --call-notes="$5K pay-in-full, kickoff Monday, wanted confirmation on group coaching vs 1:1 — confirmed 1:1"`

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, Offer Doc, Call Brief, Brand Voice Doc, call notes
- **Write / Edit** for producing the 1-page proposal (400-700 words) and updating CRM log
- **Grep** across `output/design-offer/` for verbatim guarantee language + across `output/call-prep/` for pain anchors + across `output/extract-voice/` for phrases_to_use

## Quality gates

Before writing the artifact:
- Check `spec/BANNED-VOCABULARY.md` (INV-7)
- Truth Gate (INV-5) — no fabricated deliverables, no invented guarantee terms
- No Fabrication (INV-6) — every deliverable in proposal matches Offer Doc
- Confirm every `evidence_gate` condition: scope explicit, timeline explicit, deliverables listed, payment terms explicit, risk reversal specified, next step specified, 1-page scannable, voice-match verified, no income guarantees
- Signal Score >= 0.7 (external-tier)
- Blind Output Test 2/3 scheduled (external tier — 2 evaluators sufficient)

## Failure handling

If quality gate fails:
- Attempt 1: auto-revise the failure mode (usually voice-match drift or risk-reversal omission)
- Attempt 2: surface to creator (e.g., "Offer Doc guarantee language references $X, but call notes say you offered $Y — clarify")
- If both fail: escalate to sales-head, log to `skills/proposal/evidence/failure-modes.md`

## Cross-skill routing

After the Proposal ships:
- **Immediate:** CRM log + case study pool update if close
- **Pre-kickoff:** `/post-booking-nurture` handles pre-kickoff sequence + reduces buyer's remorse window
- **If prospect stalls:** `/email-sequence` cooling-off-recovery + closer follow-up script from `/sales-script`
- **If formal contract needed:** `/legal-templates` (v1.1) produces binding agreement — proposal is commitment capture, legal is the binding
- **Post-close:** update ICP Section 10 + objection library with any new observations from the call

---
*the slash-command adapter v1.0 — binds to skills/proposal/SKILL.md*
