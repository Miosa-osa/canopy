---
name: lead-magnet
description: Design a lead magnet in one of 9 types (PDF Guide / Checklist / Cheat Sheet / Swipe File / Mini Course / Quiz-Assessment / Calculator-Tool / Free Training / Custom). the acquisition economist a lead-generation canon methodology. Produces asset brief + opt-in copy + delivery flow. Opt-in rate target 30%+ on warm traffic.
signal:
  mode: linguistic
  genre: lead-magnet-brief
  type: inform
  format: markdown
  structure: w-lead-magnet-brief
  receiver: prospect + designer + copywriter
  receiver_capacity: medium
department: nurture
agent_affinity: [nurture-head, lead-magnet-designer]
required_compartments:
  audience_intelligence_system: 60
  offer_architecture: 50
  copy_messaging: 30
upstream_dependency: design-offer
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  email: convertkit-api               # delivery automation
  asset_storage: google-drive
  design: figma-api                   # or canva
credentials_required: [CONVERTKIT_API_KEY, FIGMA_API_KEY]
evidence_gate:
  - type_selected_with_reasoning
  - value_equation_score_gte_150
  - bridge_to_offer_explicit
  - specific_outcome_promised
  - delivery_automation_wired
  - signal_score_gte_0_8
keywords:
  - lead magnet
  - free guide
  - opt-in
  - lead capture
priority: 1
version: 1.0
---

# /lead-magnet — Lead Magnet Designer (9 Types — the acquisition economist)

## Role

Design lead magnets that attract the right audience into the funnel + bridge to the core offer. Lineage: **the acquisition economist** (a lead-generation canon — 4 Core Lead Types + Lead Getters), **the growth engineer** (Lead Magnet skill + bridge-to-offer architecture), **the offer architect** (lead magnet as ascension-ladder entry).

## The 9 Lead Magnet Types

| # | Type | Best For |
|---|---|---|
| 1 | **PDF Guide** | Authority build, SEO, evergreen |
| 2 | **Checklist** | Specific task automation, fast consumption |
| 3 | **Cheat Sheet** | Reference material, memorable |
| 4 | **Swipe File** | Tactical, high-perceived-value |
| 5 | **Mini Course** (email-delivered) | Nurture-heavy, relationship-building |
| 6 | **Quiz / Assessment** | Engagement + segmentation data |
| 7 | **Calculator / Tool** | Utility-first, keep-forever value |
| 8 | **Free Training** (video/webinar) | High-intent filter + sales bridge |
| 9 | **Custom** | Bespoke format (Notion template, Miro board, spreadsheet) |

## Decision Logic

### Type Selection by ICP + Offer
- **Coaching / consulting (high-ticket):** Training or Quiz — high-intent filter
- **Course / info-product:** Checklist or Cheat Sheet — fast-consumption nurture
- **Agency / DFY services:** Swipe File or Calculator — utility + authority
- **SaaS / tool:** Calculator or Free Training

### Value Equation Alignment
Lead magnet must hit Value Equation Score ≥ 150 (Grand Slam for free):
- Dream Outcome × Perceived Likelihood = high (specific, immediate)
- Time Delay × Effort = low (consume in 15 min max)

### Bridge-to-Offer Principle
Lead magnet must naturally set up the core offer:
- Shares the **same mechanism** (named mechanism from Positioning Doc)
- Addresses a **sub-problem** of the core offer (not the whole problem)
- Ends with a **soft CTA** to the next step (Welcome sequence / VSL / call)

If lead magnet doesn't bridge, it's a leak — attracts audience that won't buy.

### Specific Outcome Promised
- "How to close your first $10K client in 14 days" > "Guide to sales"
- "48 hooks that got me 800K impressions in 30 days" > "LinkedIn tips"
- Target audience specified in title

### Delivery Automation
- Opt-in form → ESP API → tagged + welcome sequence triggered
- Asset stored in Google Drive / S3 / direct PDF attached
- Delivery email within 2 min of opt-in (critical — delay = unsub)

## Tacit Principles

1. **Lead magnet title = ad hook.** Treat title like an ad — specific, hooky, high-CTR.

2. **Delivery speed matters.** Instant or under-2-min. Delay kills trust + open rate.

3. **Consumable in 15 min.** Bigger isn't better. Faster-to-win = higher conversion downstream.

4. **One mechanism, teased not taught.** Lead magnet gives enough to hook, not enough to solve alone. Full solve = core offer.

5. **Bridge-to-offer in last 10%.** Every lead magnet ends with natural next-step CTA.

6. **Design matters 30%.** Pretty > ugly but content > design. Don't over-invest in design.

7. **A/B test titles.** 30% → 50% opt-in rate swing from title alone.

8. **Segment on opt-in.** Capture intent indicator (role, stage, goal) — informs downstream content.

9. **Refresh quarterly.** Lead magnets decay — same topic reframed every 3-6 months.

10. **Keep it in the creator's mechanism.** Don't borrow competitor magnets — creator's unique mechanism is the differentiator.

## Process

### Phase 0 — Load
- ICP Doc (pain + desire + buying triggers)
- Offer Doc (mechanism + value stack)
- Positioning Doc (Core Belief + Vehicle Switch)

### Phase 1 — Type Selection
Apply decision table.

### Phase 2 — Hook + Title
- Specificity ≥ 8
- Named outcome + timeframe
- 3-5 title variants for A/B

### Phase 3 — Asset Outline
Per type, draft the outline:
- PDF Guide: 8-15 pages, 5-7 sections
- Checklist: 1-2 pages, 10-25 items
- Cheat Sheet: 1 page, framework or reference
- Swipe File: 20-50 examples with annotations
- Mini Course: 5-7 emails or 3-5 short videos
- Quiz: 10-15 Qs with 4-5 result types
- Calculator: 3-7 inputs → 1-3 outputs
- Free Training: 30-60 min video with slides

### Phase 4 — Bridge-to-Offer
Explicit section at end:
- Reference the mechanism
- Tease the core offer
- Single CTA (next step)

### Phase 5 — Opt-in Copy
- Landing page hook (specificity ≥ 8)
- 3-5 bullet points of what's inside
- Social proof (if available)
- Single CTA button

### Phase 6 — Delivery Automation Spec
- Opt-in form (ESP integration)
- Tag on submission
- Delivery email (within 2 min)
- Triggered Welcome sequence (routes to `/email-sequence` output)

### Phase 7 — Design Brief (for designer handoff)
- Brand colors + fonts
- Layout references
- Cover image
- Final PDF dimensions

### Phase 8 — Compliance + Metadata
- Banned vocabulary swept
- Specificity ≥ 8
- Truth Gate on claims
- Delivery tested end-to-end

## Output Format

```markdown
# Lead Magnet Brief — [Creator Brand] — [Title]

**Type:** [1-9]
**Title:** "[title — specificity ≥ 8]"
**Length / Format:** [pages / duration / inputs]
**Opt-in Target:** 30-50% warm / 15-25% cold
**Bridge-to-Offer:** [explicit]
**Version:** 1.0

---

## Title Variants (A/B)
1. [primary]
2. [alt]
3. [alt]

## Opt-in Page Copy
### Hook
"[headline]"

### What's Inside (3-5 bullets)
- [...]
- [...]

### Social Proof (if applicable)
[...]

### CTA
[button copy + color]

---

## Asset Content Outline
[type-specific]

---

## Bridge-to-Offer Section
[how lead magnet concludes and routes to next step]

## Delivery Automation Spec
- Form submit → [ESP tag]
- Delivery email:
  - Subject: "[subject]"
  - From: [creator name]
  - Body: [brief]
  - Asset link / attachment
- Welcome sequence trigger: [route to /email-sequence type 1]

## Design Brief
[designer handoff specs]

## Compliance
- [ ] Specificity ≥ 8
- [ ] Banned vocab clean
- [ ] Truth Gate
- [ ] Delivery tested

---

## Appendix A — Landing page copy variants
## Appendix B — Asset content draft
## Appendix C — Delivery email draft
```

## Important Rules

- **NEVER deliver lead magnet with no bridge-to-offer.**
- **NEVER use generic titles** ("Ultimate Guide to [Topic]").
- **NEVER delay delivery** > 2 minutes.
- **ALWAYS thread mechanism into content.**
- **ALWAYS specify delivery automation end-to-end.**

## Verification Checklist

- [ ] Type selected
- [ ] Title specificity ≥ 8
- [ ] Asset outline complete
- [ ] Bridge-to-offer explicit
- [ ] Opt-in copy written
- [ ] Delivery automation wired
- [ ] Design brief ready
- [ ] Compliance
- [ ] Triple-layer S/N ≥ 0.8

## Next Skills

- `/email-sequence` (Type 1 Welcome) — triggered post-opt-in
- `/landing-page` — builds the opt-in page
- `/ad-creative` — traffic to opt-in

## Variants

Per-variant playbooks live in `variants/`. Each file expands one lead magnet type with scope, structural anatomy, title patterns, delivery automation, design specs, benchmarks, failure modes, and next-step routing.

| # | Variant | File |
|---|---|---|
| 1 | PDF Guide | `variants/pdf-guide.md` |
| 2 | Checklist | `variants/checklist.md` |
| 3 | Cheat Sheet | `variants/cheatsheet.md` |
| 4 | Swipe File | `variants/swipe-file.md` |
| 5 | Mini Course | `variants/minicourse.md` |
| 6 | Quiz | `variants/quiz.md` |
| 7 | Calculator | `variants/calculator.md` |
| 8 | Live Training | `variants/live-training.md` |
| 9 | Custom Artifact | `variants/custom-artifact.md` |

Index: `variants/_INDEX.md`.

## References

- `reference/operators/acquisition-economist.md` (a lead-generation canon)
- `reference/operators/growth-engineer.md` (Lead Magnet framework)
- `reference/frameworks/primitives/value-equation.md`

---
*v1.0 — 2026-04-19. Cycle 4 Educate.*
