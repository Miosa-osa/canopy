---
description: Design a $7-$97 entry offer (tripwire) with full economics (CPA / LTV / ascension). 7 archetypes (free+shipping / low-ticket info / checklist+call / trial / consultation / live workshop / physical sample). Feeds /ad-creative + /email-sequence + /build-funnel.
argument-hint: [optional: "--archetype=T1-T7" to force; else auto-select from business_model + offer_ladder]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch
---

# /tripwire-design — slash-command runtime Runtime Binding

Load and execute `skills/tripwire-design/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/tripwire-design/SKILL.md` (full body)
   - `Read` upstream: `output/design-offer/` (core offer + offer ladder), `output/build-funnel/` (especially Archetype 5 Tripwire Funnel), `output/build-icp/` (market sophistication + awareness), `output/extract-voice/`
   - read `reference/frameworks/esoteric-marketing/` (low-ticket ascension), `reference/frameworks/primitives/` (call-funnel, value-equation), operator files (acquisition-economist, growth-engineer, backend-economist, offer-architect)

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 60`, `funnel_systems >= 20`, `conversion_sales_systems >= 30`. Confirm core offer price + ascension-path target offers defined. Confirm ad economics benchmark available (CPL / CPA expected). If any fails, HOLD with specific gap.

3. **Execute Phase 0 -> Phase 10** per SKILL.md Process: Archetype Selection -> Context Validation -> Product Design -> Pricing + Economics Model -> Order Bump + OTO Design -> 5-Phase Ascension Sequence -> Ad Economics Handoff -> Voice-Match Pass -> Compliance Check -> Quality Gates -> Tripwire Summary (LAST).

4. **Write output:**
   - `Write` to `output/tripwire-design/{YYYY-MM-DD}-tripwire-archetype-{T1-T7}.md`
   - Structure per SKILL.md Output Format — HEADER + 8 sections (product / economics / bump+OTO / 5-phase ascension / ad economics / sales page copy / email sequence handoff / compliance) + 5 appendices
   - Mark `[ECONOMICS GAP]` if LTV:CAC < 3:1 or `[PROOF GAP]` for missing ascension case studies

5. **Update company.yaml:**
   - edit Compartment 3 (offer_architecture.offer_ladder.tripwire) with the archetype + economics
   - edit Compartment 4 (funnel_systems) to bind tripwire to Archetype 5 (Tripwire Funnel)
   - edit Compartment 10 (lifecycle_optimization) with ascension LTV targets

6. **Post-ship:**
   - write `skills/tripwire-design/evidence/runs/{YYYY-MM-DD}-run.md` with archetype rationale + economics model + ascension-rate assumptions + ad CPA target
   - Output next-skill recommendations (usually `/ad-creative` for creative families + `/email-sequence` for 5-phase ascension + `/landing-page` for tripwire sales/checkout/thank-you/OTO pages + `/build-funnel` to integrate Archetype 5)

## Arguments

If `$ARGUMENTS` contains `--archetype=T1-T7`, force that archetype. Otherwise apply the Archetype Decision Tree based on business_model, offer_ladder structure, and creator capabilities (time/team for calls, physical product presence, live-workshop fit).

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, Offer Doc, Funnel a longevity-protocol, ICP, Brand Voice Doc, economics frameworks
- **Write / Edit** for producing the Tripwire Design (typically 4,000-6,000 words including economics model + 5-phase ascension + 5 appendices) and updating company.yaml
- **WebSearch** for current-market benchmark validation (industry-vertical tripwire conversion norms, SLO math verification) — optional but supports Truth Gate
- **Grep** across `output/` for existing ascension-path references + ICP ascension-history signals

## Quality gates

Before writing the artifact:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` (INV-7)
- Truth Gate (INV-5) — every cited conversion / ascension / LTV number survives 30-sec fact-check
- No Fabrication (INV-6) — every case study / number real
- Confirm every `evidence_gate` condition: archetype with reasoning, economics model complete, payback-per-lead + breakeven CAC calculated, LTV:CAC >= 3:1, ladder progression mapped, ascension sequence specified, voice-match verified
- Signal Score >= 0.8
- Blind Output Test 3/3 (sacred-format economics tier) REQUIRED before paid launch
- Brand safety: no income guarantees, no health claims without clinical backing

## Failure handling

If economics model fails (LTV:CAC < 3:1):
- Attempt 1: auto-revise (raise entry price / lower COGS / improve ascension assumption) — but honor INV-5 (no fabricated ascension rates)
- Attempt 2: surface to creator ("ascension assumption requires X% conversion; actual benchmark is Y% — need to revise offer ladder or tripwire pricing")
- If both fail: escalate to sales-head / foundations-head, log to `skills/tripwire-design/evidence/failure-modes.md`

## Cross-skill routing

After the Tripwire Design ships (and passes 3/3 economics review):
- Primary downstream: `/ad-creative` (creative families for tripwire cold-traffic), `/email-sequence` (5-phase ascension copy), `/landing-page` (tripwire sales + checkout + thank-you + OTO pages)
- Secondary: `/build-funnel` Archetype 5 integration, `/build-funnel` traffic mix update
- Upstream if gap: `/design-offer` if ascension-path offers missing, `/build-icp` if market sophistication signals insufficient for archetype selection
- Quarterly LTV:CAC audit triggered by cohort data (owned by scale-head via `/revenue-report`)

---
*the slash-command adapter v1.0 — binds to skills/tripwire-design/SKILL.md*
