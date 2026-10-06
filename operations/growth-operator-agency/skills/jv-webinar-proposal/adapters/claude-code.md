---
description: Produce JV partner outreach + webinar proposal. Identifies aligned partners, drafts personalized outreach, structures rev split + logistics + economics.
argument-hint: [optional: partner name or domain to target]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# /jv-webinar-proposal — slash-command runtime Runtime Binding

Load and execute `skills/jv-webinar-proposal/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/jv-webinar-proposal/SKILL.md` (full body)
   - read `skills/jv-webinar-proposal/reference/` if present
   - `Read` upstream: `output/design-offer/latest.md` (offer details + AOV + close rate), `output/build-icp/` (ICP for audience overlap analysis), `output/competitor-intel/` if present (adjacent-tier partner candidates)

2. **Pre-flight check:** Verify `required_compartments` — audience_intelligence_system ≥ 50, offer_architecture ≥ 60.

3. **Execute Phase 0 → Phase 4** per SKILL.md Process:
   - Phase 0 Load → Phase 1 Partner Research (WebSearch + WebFetch for partner's offers, price points, audience size, recent content; compute compatibility score) → Phase 2 Proposal Drafting (personalized opener, value-exchange clear, low-friction ask) → Phase 3 Economics Modeling (partner audience × attendance × close rate × AOV × rev split) → Phase 4 Follow-Up Plan (Day 3 / Day 7 / Day 14 cadence)

4. **Write output:**
   - `Write` to `output/jv-webinar-proposal/{YYYY-MM-DD}-{partner-slug}-proposal.md`
   - Structure per SKILL.md Output Format — partner brief, personalized opener, audience overlap, webinar proposal, rev split, logistics, expected economics, social proof, CTA, follow-up plan

5. **Post-ship:**
   - write `skills/jv-webinar-proposal/evidence/runs/{YYYY-MM-DD}-run.md`
   - Recommend next skill: `/webinar-script` (the JV webinar itself), `/email-sequence` (post-JV follow-up to attendees)

## Arguments

If `$ARGUMENTS` contains partner name/domain, target that specific partner. Otherwise surface top 3 candidates from adjacent-tier creator network.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, offer doc, ICP, competitor intel
- **WebSearch** for partner's recent content + audience size signals
- **WebFetch** for partner's landing pages, podcast episodes, LinkedIn posts (personalization ammo)
- **Write / Edit** for proposal artifact + follow-up plan

## Quality gates

Before writing to `output/`:
- Partner identified with fit verified (same/similar ICP, non-competing, audience 1x-5x, high trust) (evidence gate)
- Proposal personalized (specific reference to partner's recent work — NOT template-feel) (evidence gate)
- Rev split specified (typically 50/50 on JV-attributed sales) (evidence gate)
- Logistics detailed (promotion, platform, co-creation scope, attribution tracking) (evidence gate)
- Expected economics modeled with specific numbers (partner audience × attendance × close × AOV × rev split = $N) (evidence gate)
- Single CTA (booking call to discuss — not commitment ask)
- Signal Score ≥ 0.8
- Banned vocabulary clean
- Blind Output Test 2/3 queued before sending to actual partners

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise → surface gap → escalate to partnerships-head, log to `skills/jv-webinar-proposal/evidence/failure-modes.md`.

## Cross-skill routing

- Downstream: `/webinar-script` (produce the actual JV webinar script once partner agrees), `/email-sequence` (post-JV follow-up to attendees on creator's side)
- On external-tier completion: Blind Output Test 2/3 queued before sending to any real JV prospect

---
*the slash-command adapter v1.0 — binds to skills/jv-webinar-proposal/SKILL.md*
