---
description: Produce the the paid media director Show-Rate Stack — confirmation page + email cadence + SMS cadence + optional phone triage. Targets 70%+ show-rate from booking to call.
argument-hint: [optional: offer price tier hint for stack depth]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /post-booking-nurture — slash-command runtime Runtime Binding

Load and execute `skills/post-booking-nurture/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/post-booking-nurture/SKILL.md` (full body)
   - read `skills/post-booking-nurture/reference/` if present
   - `Read` upstream: `output/build-funnel/latest.md` (archetype — must be 3 Application or 4 Book-a-Call), `output/design-offer/` (price tier, call structure), `output/build-icp/` (objections), `output/extract-voice/`

2. **Pre-flight check:** Verify `required_compartments` — audience_intelligence_system ≥ 60, offer_architecture ≥ 50, copy_messaging ≥ 40, conversion_sales ≥ 30. Verify funnel archetype is 3 (Application) or 4 (Book-a-Call) — Archetype 2 (Webinar) routes to `/email-sequence` type 4 instead.

3. **Execute Phase 0 → Phase 7** per SKILL.md Process:
   - Phase 0 Load → Phase 1 Component Selection (per offer price + archetype) → Phase 2 Confirmation Page Spec (5-function the growth engineer framework + creator video script 30-90s + homework list) → Phase 3 Email Cadence (T+0 / T-24h / T-6h / optional T-1h) → Phase 4 SMS Cadence (the paid media director — within 5m / 30m post / T-24h / T-30m / T-5m) → Phase 5 Phone Triage Spec if high-ticket → Phase 6 Voice-Match + Compliance (TCPA/GDPR/CAN-SPAM) → Phase 7 Automation Spec

4. **Write output:**
   - `Write` to `output/post-booking-nurture/{YYYY-MM-DD}-{offer-slug}-show-rate-stack.md`
   - Structure per SKILL.md Output Format — confirmation page spec, 4-email cadence, 5-SMS cadence, phone triage script (if applicable), automation triggers

5. **Post-ship:**
   - write `skills/post-booking-nurture/evidence/runs/{YYYY-MM-DD}-run.md`
   - Recommend next skill: `/sales-script` (closer script), `/call-prep` (closer briefing), `/email-sequence` type 7 Post-Purchase

## Arguments

If `$ARGUMENTS` contains offer-price hint, bypass Phase 1 component selection and honor. Otherwise derive from `output/design-offer/`.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, funnel archetype output, offer price, ICP objections, voice doc
- **Write / Edit** for confirmation page copy + email+SMS stack + automation spec
- **Grep** `company.yaml` for offer price tier + setter team availability

## Quality gates

Before writing to `output/`:
- Confirmation page spec complete with 5-function structure (growth-engineering methodology) (evidence gate)
- Creator video script 30-90s
- Homework list 3-5 items (commitment-building)
- Email cadence 24h / 6h / 1h (evidence gate)
- SMS cadence within 5m / 30m / T-24h / T-30m / T-5m (the paid media director timing — evidence gate)
- Phone triage spec if offer ≥ $10K (evidence gate)
- Voice-matched (3+ phrases_to_use across touchpoints)
- TCPA/GDPR consent tracked at booking
- CAN-SPAM compliance (physical address + unsubscribe + STOP for SMS)
- Calendar .ics attachment specified
- Reschedule link included
- Signal Score ≥ 0.8
- Blind Output Test 2/3 queued before activation

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise → surface gap → escalate to nurture-head, log to `skills/post-booking-nurture/evidence/failure-modes.md`.

## Cross-skill routing

- Downstream: `/sales-script` (closer script for the call), `/call-prep` (closer briefing), `/email-sequence` type 7 Post-Purchase (after close)
- On external-tier completion: Blind Output Test 2/3 queued before stack activation

---
*the slash-command adapter v1.0 — binds to skills/post-booking-nurture/SKILL.md*
