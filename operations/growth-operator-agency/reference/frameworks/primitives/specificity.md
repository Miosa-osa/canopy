# Specificity — The Primitive

> **Source lineage:** the media buying director (*"Specificity > sophistication"* — explicit principle), the acquisition economist (specific Grand Slam promises), the copy director (Amazon review research extracts specific language), the offer architect (numeric specificity in VSLs), an early-20th-century copy essayist / the direct-response tradition (classical direct response).
> **Status:** First-class primitive. The anti-generic filter.

## The Principle

> **Specific > sophisticated. Every time.**

Vague copy fails. Specific copy converts. This primitive codifies the 5 dimensions of specificity every asset must hit.

## The 5 Dimensions

Every piece of copy hits 1-10 on each of 5 specificity axes:

### 1. Audience Specificity
**Vague:** "busy entrepreneurs"
**Specific:** "42-year-old agency owners at $30K-$80K MRR who check Stripe 4× daily and can't take 3 days off without business stalling"

Score: **10 = named demographic + firmographic + behavioral + psychographic markers**. Score: **1 = "business owners."**

### 2. Problem Specificity
**Vague:** "struggling with time management"
**Specific:** "losing 12 hours/week on proposal back-and-forth with clients who ghost after 3 emails"

Score: **10 = named behavior + measurable impact + emotional cost**. Score: **1 = "has problems."**

### 3. Mechanism Specificity
**Vague:** "my proven system"
**Specific:** "the 7-step Revenue OS that re-routes 80% of the Stripe back-and-forth through an async approval flow"

Score: **10 = named mechanism + 2-5 named sub-steps + clear differentiation**. Score: **1 = "a method."** See `primitives/unique-mechanism.md`.

### 4. Outcome Specificity
**Vague:** "grow your business"
**Specific:** "add $25,000 in monthly retainer revenue within 90 days without adding a single employee"

Score: **10 = specific number + specific timeframe + specific constraint**. Score: **1 = "improve results."**

### 5. Creative Specificity
**Vague:** stock photo of handshake / generic hook / templated visual
**Specific:** specific scene (e.g., "split screen: laptop with Stripe dashboard + coffee + 3 monitors showing Slack notifications"), named reference, unique framing

Score: **10 = unique visual concept or unique verbal framing**. Score: **1 = "stock-photo generic."**

## The Composite Score

```
Specificity Score = (Audience + Problem + Mechanism + Outcome + Creative) / 5
```

**Gate thresholds** (per `reference/canonical/spec/QUALITY.md`):
- ≥ 8 = ship-ready for external
- 6-7 = revise before ship
- < 6 = reject, rewrite

## Why Vagueness Happens

Vague copy is a **cognitive shortcut**. The writer hasn't decided the specifics, so they use generic placeholders. Specificity requires more work:
- Audience: pulled from ICP VOC (Compartment 2)
- Problem: pulled from Pain Library (Compartment 5)
- Mechanism: named in Positioning Doc (Compartment 1.unique_positioning)
- Outcome: pulled from Offer Doc transformation
- Creative: requires concept development

Every compartment missing = dimension vague. This is why compartment-completeness gates (`spec/CONTEXT-THRESHOLDS.md`) enforce specificity indirectly.

## The Measurement Protocol

Before ship, score each dimension 1-10:
1. Read the asset aloud
2. Per dimension, answer: "Could a competitor say the exact same thing?"
   - YES → score ≤ 5
   - NO → score ≥ 7
3. "Could the specific number/name/framing be substituted with 'X' and nothing change?"
   - YES → not specific enough
   - NO → passes

## Anti-Patterns (from Banned Vocabulary)

Words that signal lack of specificity:
- "many," "often," "most," "usually," "typically"
- "significant," "substantial," "meaningful"
- "various," "several," "a lot of"
- "effective," "efficient," "effective"
- "leverage," "synergy," "holistic"

Per `spec/BANNED-VOCABULARY.md`, these trigger REJECT.

## The the media buying director Protocol (Top 1% Ad Testing)

the media buying director's ads-at-scale discovery:
> *"After 7 years running ads across B2B and coaching — the main difference between ads that scale and ads that flop is specificity."*

His protocol:
1. Test creative **families** not ads (shared angle, 3-5 variant formats)
2. Hold audience constant to isolate creative impact
3. Scale winners via duplication (not bid spikes)
4. Specificity on 5 dimensions is the primary lever

## Skill Bindings

Every skill that produces customer-facing copy applies this primitive:
- `/research` (specificity in Market Research Brief claims)
- `/build-icp` (20+ verbatim VOC quotes = specificity baseline)
- `/design-offer` (specific value stack + guarantee)
- `/build-vsl` (specificity in hook, proof, outcome)
- `/ad-creative` (primary lever — each variant scored ≥ 8)
- `/content-calendar` (per-post briefs specify topic specifically)
- `/write-reel` + `/write-youtube` + `/write-linkedin-post` + `/write-x-thread` + `/story-sequence` (all hit hook specificity ≥ 8)
- `/email-sequence` (specific subject lines)
- `/lead-magnet` (specific title + outcome)
- `/webinar-script` (specific promises + case studies)
- `/case-study` (specific numbers + timeframe)
- `/jv-webinar-proposal` (specific partner reference + specific revenue model)

## Validation

Copy passes specificity gate when:
- [ ] Composite score ≥ 8
- [ ] No banned vagueness words
- [ ] "Could a competitor say this?" = NO
- [ ] "Could we substitute X for any word and nothing change?" = NO
- [ ] Pulls from compartments (not invented)

## Sources

- the media buying director — LinkedIn longform 2025: *"Specificity is the primary lever"*
- the acquisition economist — a high-value offer canon + a lead-generation canon (specificity-heavy copy throughout)
- the copy director — *research-mechanism-brief-copy process* (Research phase = specificity extraction from Amazon reviews)
- the offer architect — *Anatomy of Ads* (numeric specificity)
- Classical: an early-20th-century copy essayist the early-20th-century reason-why essay, the direct-response tradition direct response lineage
- `reference/operators/media-buying-director.md`
- `reference/operators/acquisition-economist.md`
- `reference/operators/copy-director.md`

---
*v1.0 — 2026-04-19. Primitive — the anti-generic filter applied at every ship gate.*
