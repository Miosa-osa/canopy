---
description: Produce email sequences in 8 types (Welcome / Nurture / Launch / Webinar / Re-engagement / Application / Post-Purchase / Broadcast). Voice-matched, conversion-staged.
argument-hint: [optional: --type=1-8]
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /email-sequence — slash-command runtime Runtime Binding

Load and execute `skills/email-sequence/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/email-sequence/SKILL.md` (full body)
   - read `skills/email-sequence/reference/` if present
   - `Read` upstream: `output/design-offer/latest.md`, `output/build-icp/` (objection library), `output/build-positioning/`, `output/extract-voice/`
   - read `output/content-calendar/` if Type 8 Broadcast

2. **Pre-flight check:** Verify `required_compartments` — audience_intelligence_system ≥ 60, offer_architecture ≥ 50, copy_messaging ≥ 40, education_nurture ≥ 20.

3. **Execute Phase 0 → Phase 6** per SKILL.md Process:
   - Phase 0 Load → Phase 1 Sequence Type Selection (1-8) → Phase 2 Cadence Planning → Phase 3 Per-Email Brief (subject + preview + hook + body + CTA) → Phase 4 Write Each Email (voice-matched, specificity ≥ 8, P.S. optimization) → Phase 5 Segmentation + Tagging → Phase 6 Platform Export (ConvertKit / ActiveCampaign / Beehiiv / GHL schemas)

4. **Write output:**
   - `Write` to `output/email-sequence/{YYYY-MM-DD}-type{N}-{sequence-name}.md`
   - Structure per SKILL.md Output Format — sequence overview table + per-email spec + segmentation plan + platform export JSON

5. **Post-ship:**
   - write `skills/email-sequence/evidence/runs/{YYYY-MM-DD}-run.md`
   - Recommend next skill: `/post-booking-nurture` (call funnels), `/lead-magnet` (Welcome upstream), or `/webinar-script` (Webinar seq target)

## Arguments

If `$ARGUMENTS` contains `--type=1-8`, honor sequence type; otherwise infer from context (upstream funnel archetype or explicit creator request).

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, offer doc, ICP objections, voice doc, positioning
- **Write / Edit** for sequence artifact + per-email spec + platform JSON export
- **Grep** `company.yaml` for 8 Required Beliefs map + mechanism name

## Quality gates

Before writing to `output/`:
- Sequence type selected (evidence gate)
- Cadence per SKILL.md table
- Per-email subject hook specificity ≥ 8 (evidence gate)
- Single CTA per email (no stacking)
- Voice-matched (3+ phrases_to_use)
- CAN-SPAM compliance (physical address + unsubscribe + truthful header)
- GDPR compliance if EU audience
- Banned vocabulary clean (no "Re:" fake-reply subject, no "Quick question" patterns)
- Signal Score ≥ 0.8
- Blind Output Test 2/3 queued before production send

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise → surface gap → escalate to nurture-head, log to `skills/email-sequence/evidence/failure-modes.md`.

## Cross-skill routing

- Sequence dependencies: Welcome (Type 1) triggered by `/lead-magnet`; Webinar (Type 4) promotes `/webinar-script`; Post-Purchase (Type 7) precedes `/sales-script` outcomes
- On external-tier completion: Blind Output Test 2/3 queued before send-to-list

---
*the slash-command adapter v1.0 — binds to skills/email-sequence/SKILL.md*
