---
description: Produce the 4-page landing stack (opt-in / offer / thank-you / checkout) with 4 copy variants per page (Problem-First / Result-First / Mechanism-First / Curiosity-First hooks). Mobile-first. Offer page follows research-mechanism-brief-copy 7-section methodology.
argument-hint: [optional: "--funnel-archetype=1-7"; "--pages=opt-in,offer,thank-you,checkout" to subset]
allowed-tools: Read, Write, Edit, Grep, Glob, WebSearch, WebFetch
---

# /landing-page — slash-command runtime Runtime Binding

Load and execute `skills/landing-page/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/landing-page/SKILL.md` (full body)
   - `Read` upstream: `output/design-offer/` (value stack, bonuses, guarantee, price), `output/build-positioning/` (mechanism + sub-steps), `output/build-icp/` (avatars + awareness levels + Section 10 objections), `output/extract-voice/` (phrases_to_use), `output/build-funnel/` (funnel archetype), `output/build-vsl/` if exists, `output/tripwire-design/` if tripwire funnel, `output/objection-library/` for FAQ pre-framing
   - read `reference/frameworks/sales/value-stack-architecture.md`, `reference/frameworks/primitives/` (unique-mechanism, value-equation, specificity), operator files (copy-director for research-mechanism-brief-copy, campaign-director, vsl-director, awareness-spectrum-author, direct-response-copywriter, acquisition-economist)

2. **Pre-flight check:** Verify `audience_intelligence_system >= 60`, `offer_architecture >= 70`, `copy_messaging >= 40` in `company.yaml`. Confirm mechanism named, value stack + guarantee + bonuses articulated, 3-5 isomorphic case studies available, 15+ phrases_to_use. If any fails, HOLD with specific gap.

3. **Execute Phase 0 -> Phase 14** per SKILL.md Process: Context Load -> Context Validation -> Funnel Archetype -> Page Selection -> Variant Dimension Spec -> Write Page 1 Opt-In (4 variants) -> Write Page 2 Offer (research-mechanism-brief-copy 7-section, 4 variants) -> Write Page 3 Thank-You (4 variants) -> Write Page 4 Checkout (4 variants) -> FAQ Pre-Framing -> Voice-Match Pass -> Mechanism Thread Check -> Mobile-First Render Check -> Compliance Check -> Quality Gates -> Stack Metadata Summary (LAST).

4. **Write output:**
   - `Write` to `output/landing-page/{YYYY-MM-DD}-landing-stack-{funnel-archetype}.md`
   - Structure per SKILL.md Output Format — HEADER + 4 pages x 4 variants (16 deliverables) + mechanism trace + FAQ audit + compliance + 5 appendices
   - Mark `[GAP]` if any section lacks required content or any case study is non-isomorphic

5. **Update company.yaml:**
   - edit Compartment 4 (funnel_systems.active_funnels) to bind landing stack to funnel archetype
   - edit Compartment 5 (copy_messaging.proven_headlines + proven_hooks) with the 4 hook variants as A/B test candidates
   - Never overwrite existing values without confirmation

6. **Post-ship:**
   - write `skills/landing-page/evidence/runs/{YYYY-MM-DD}-run.md` with funnel archetype rationale + variant dimension rationale + mechanism thread trace + mobile render audit
   - Output next-skill recommendations (usually `/ad-creative` for cold traffic -> opt-in + `/email-sequence` for nurture + `/post-booking-nurture` for calendar thank-you triggers)

## Arguments

If `$ARGUMENTS` contains `--funnel-archetype=N`, adapt page selection to that archetype. If `--pages=...`, produce only the listed subset. Otherwise infer from funnel archetype and produce full stack.

`$ARGUMENTS`

## Tool usage patterns

- **Read** for SKILL.md, all upstream Docs (Offer/Positioning/ICP/Voice/Funnel/VSL/Tripwire/Objection Library), copy frameworks and operator files
- **Write / Edit** for producing the 4-page stack (typically 8,000-15,000 words across 4 pages x 4 variants + appendices) and updating company.yaml
- **WebSearch / WebFetch** for competitor landing-page pattern validation and industry-vertical conversion norm benchmarks — optional but supports Truth Gate
- **Grep** across `output/` for existing proven hooks + phrases_to_use instances + mechanism sub-steps + isomorphic case study pool

## Quality gates

Before writing the artifact to `output/`:
- Run `reference/canonical/spec/QUALITY.md` triple-layer verification
- Check `spec/BANNED-VOCABULARY.md` — full regex sweep (INV-7)
- Truth Gate on every claim (INV-5) — 30-second screenshot test per cited result / testimonial / guarantee term / price
- No Fabrication (INV-6) — case studies real, numbers real, guarantee language verbatim from Offer Doc
- Confirm every `evidence_gate` condition: 4 pages (or subset), 4 variants per page, research-mechanism-brief-copy 7-section on offer page, mobile-first verified, mechanism threaded, voice-match verified, single CTA per page, FAQ pre-frames top-5 objections
- Signal Score >= 0.8
- Blind Output Test 3/3 (sacred-format tier) REQUIRED before any paid traffic
- Brand safety: no income guarantees, no health claims without clinical backing, FTC disclosure for testimonials, GDPR/CCPA disclosure on opt-in page if applicable

## Failure handling

If quality gate fails:
- Attempt 1: auto-revise the specific failure mode (usually mechanism thread gap on one of the pages or voice-match drift in one variant)
- Attempt 2: surface the gap to creator (e.g., "Case study pool has only 2 isomorphic cases for this avatar — need 1-3 more before offer page can ship at 3/3 Blind Test tier")
- If both fail: escalate to sales-head, log to `skills/landing-page/evidence/failure-modes.md`

## Cross-skill routing

After the Landing Stack ships (and passes 3/3 Blind Output Test):
- Primary downstream: `/ad-creative` (creative families driving cold traffic to opt-in), `/email-sequence` (nurture for opt-ins who don't buy), `/post-booking-nurture` (triggered on calendar thank-you)
- Secondary: `/webinar-script` (if webinar funnel), `/build-funnel` (funnel architecture update with stack references)
- Upstream if gap: `/build-vsl` if offer page VSL-wrap lacks VSL, `/design-offer` if value stack thin, `/objection-library` if FAQ pre-framing lacks top-5 reframes
- Weekly A/B testing review with `/revenue-report` cohort analysis (owned by marketing-head + sales-head)

---
*the slash-command adapter v1.0 — binds to skills/landing-page/SKILL.md*
