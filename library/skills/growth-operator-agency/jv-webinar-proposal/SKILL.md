---
name: jv-webinar-proposal
description: Produce a JV partner outreach package + webinar proposal. Identifies aligned partners from the creator's adjacent tier, drafts personalized outreach, structures revenue split + logistics + co-created content, and models expected economics per partner. Treats the outreach as a full-stack sales call on paper — same 8-stage discipline, same belief-install logic, same decision-lock at close. Output feeds directly into `/webinar-script` for the event itself and `/email-sequence` for post-event follow-up.
signal:
  mode: linguistic
  genre: jv-proposal
  type: direct
  format: markdown
  structure: w-jv-proposal
  receiver: potential JV partner
  receiver_capacity: medium
department: partnerships
agent_affinity: [partnerships-head]
required_compartments:
  audience_intelligence_system: 50
  offer_architecture: 60
upstream_dependency: design-offer
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write, web_search]
required_mcps: [filesystem, notion]
required_integrations:
  email: gmail                  # for outreach send + follow-up
  calendar: cal-com-api
  crm: gohighlevel-api
  contracts: pandadoc-api       # optional — triggered post-verbal-yes
credentials_required: [CAL_COM_API_KEY, GHL_API_KEY]
evidence_gate:
  - partner_identified_with_fit
  - fit_score_gte_7
  - proposal_personalized
  - rev_split_specified
  - logistics_detailed
  - expected_economics_modeled
  - follow_up_cadence_defined
  - signal_score_gte_0_8
keywords:
  - JV
  - joint venture
  - partnership
  - partner webinar
  - JV webinar
  - affiliate webinar
priority: 1
version: 1.0
---

# /jv-webinar-proposal — JV Partner Outreach + Webinar Proposal

## Usage

Run when the creator is sourcing a partner for a co-hosted webinar — typically during Phase 1 of `/plan-launch` (partner recruitment is a Phase-1 Pre-Launch Prep item) or as a standalone partnerships motion targeting the operations director's 10% email / partner revenue bucket. Input: target partner name + audience-size estimate + partner's public offer surface. Output: full proposal document + personalized outreach email + 3-touch follow-up cadence + economics model per partner. Interactive — skill refuses to ship a proposal below fit score 7/10 or without personalized opener.

## What It Does

Produces a sales-grade JV package: one personalized outreach email, one full proposal (4-8 pages), one economics model (audience × conversion × AOV × split), and one follow-up cadence (3 touches over 14 days). Grades partner fit on four dimensions and refuses to ship below 7/10. Treats the proposal itself as a sample of the creator's operation — sloppy proposal = sloppy execution signal — so every artifact is run through the same quality gate that applies to client-facing copy.

## Role (Lineage)

the growth engineer *Partner Webinar System* (trust-transfer mechanic as the defining partnership primitive). the operations director 60/30/10 revenue mix (JV-webinar revenue lives inside the 30% webinar bucket or the 10% experimentation bucket, depending on cadence). the offer architect full-stack 8-stage sales-call architecture (outreach is a sales call on paper — same stage discipline). Alex Core Four (partnerships are the "warm reach" quadrant of outreach). the backend economist benchmarking discipline (economic model is specific, not aspirational). the agency director Loom-audit outreach pattern (personalization at volume).

## Agent

`@partnerships-head` — owns partner identification, fit scoring, outreach drafting, economics modeling. Escalates to `@sales-ops` for contract templates and to `@webinar-lead` once the proposal converts to a booked webinar slot.

## Destination

`output/cycle-6-partnerships/jv-proposals/{partner-slug}/` containing: `proposal.md` (full), `outreach-email.md`, `economics-model.md`, `follow-up-cadence.md`, `fit-score.md`, `contract-draft.md` (post-verbal-yes only).

## Prerequisites

- ICP Doc — the audience-overlap analysis depends on the creator's ICP being specified
- Offer Doc — partner needs to see the exact offer they're referring traffic to, with mechanism + price + guarantee
- Positioning Doc — Core Belief and Big Enemy frame the webinar topic
- Creator's public surface ready for the partner to vet before responding (partner WILL audit: most common kill reason is "I looked at your stuff and it wasn't ready")
- At least one past case study (`/case-study` output) — partner needs proof their audience will actually buy
- Economics baseline — the creator's own webinar attendance rate, close rate, and AOV from prior events (no baseline = speculative model, lower fit score from partner)

## Partner Fit Scoring (4 dimensions, out of 10)

| Dimension | 10/10 | 5/10 | 0/10 |
|---|---|---|---|
| **Audience overlap** | Same ICP, same pain, same stage | Adjacent ICP (same broad niche) | Different audience entirely |
| **Offer complementarity** | Partner's offer serves a *before* or *after* step of creator's offer (ascension-compatible) | Partner's offer is parallel / neutral | Partner's offer directly competes |
| **Trust signals** | Partner has publicly endorsed creator-tier operators before; documented JV results | Partner runs clean brand, no JV track record | Partner has history of burned partnerships / predatory affiliate deals |
| **Operational readiness** | Partner has run a JV webinar in last 12 months with >5% close rate | Partner has a list and promotes periodically | Partner has a list but has never promoted |

**Ship gate:** aggregate >= 7/10. Below 7, refuse to draft proposal — route to higher-fit partner or drop.

## Revenue Split Rules (Growth Operating Agency canonical defaults)

| Scenario | Default Split (Partner / Creator) |
|---|---|
| Partner promotes to their list + creator delivers webinar | 50 / 50 |
| Partner promotes + creator delivers + partner co-presents | 50 / 50 (same — presence doesn't change split) |
| Partner's list is 3× creator's and partner does all promotion | 60 / 40 or 70 / 30 |
| Creator's list is 3× partner's and creator does most promotion | 30 / 70 or 40 / 60 |
| Affiliate-only (partner refers single prospect, no webinar) | Standard affiliate rate (20-40%) |
| Reciprocal (both creators run webinars for each other) | 50/50 each direction, tracked separately |

Revenue split is negotiable but starting at 50/50 signals a partnership posture. Starting at 70/30 in the creator's favor signals an extraction posture and is the most common reason partners decline without responding.

## Proposal Structure

```
W(jv-proposal) =
  1. Personalized opener (specific reference to partner's recent work)
  2. Audience overlap analysis (ICP-level, not just size)
  3. Webinar proposal (topic + format + proposed date + duration)
  4. Revenue split (specified, not open-ended)
  5. Logistics (promotion schedule + platform + co-creation scope + attribution)
  6. Expected economics (audience × attendance × close × AOV × split — with ranges)
  7. Proof of past JV success (case studies + prior partner references)
  8. Single CTA (20-min booking call — not a commitment, a conversation)
```

## Process

### Phase 0 — Load
- Creator's ICP Doc, Offer Doc, Positioning Doc, Brand Voice Doc
- Target partner list (from creator's network + `/competitor-intel` adjacent tier + LinkedIn second-degree)
- Creator's webinar economics baseline (attendance rate, close rate, AOV) — required, not optional
- `reference/frameworks/sales/full-stack-sales-call-8-stage.md` — apply the sales-call discipline to the written proposal
- `reference/frameworks/growth-operating-process/60-30-10-revenue-mix.md` — confirm which revenue bucket this JV feeds

### Phase 1 — Partner Research (per candidate)
- Partner's offers, price points, audience size, recent content (last 90 days)
- Recent JV history — has the partner run partnerships before, and with what outcomes?
- Partner's VOC — their audience's stated pain + desire (scraped from their comments section, community, email open rates if public)
- Compatibility score across all 4 dimensions
- If score < 7, drop. If score >= 7, proceed to Phase 2.

### Phase 2 — Proposal Drafting
- Personalized opener — specific reference to one piece of their work from the last 30 days (not "I love your content")
- Audience-overlap table, ICP-level
- Webinar topic — positioned to solve a named pain shared by both audiences
- Rev split specified up front (no "let's discuss" language — that reads as negotiation-avoidant)
- Logistics detailed: promotion schedule, platform, tech ownership, attribution mechanism

### Phase 3 — Economics Modeling (per partner)
Build three scenarios: conservative, expected, optimistic.

```
Partner list × attendance rate × close rate × AOV × rev split = partner revenue
Partner list × attendance rate × close rate × AOV × (1 - rev split) = creator revenue
```

Use creator's baseline numbers, not aspirational ones. If creator has never closed a webinar before, the model is speculative — flag that honestly in the proposal, partners respect operators who don't inflate.

### Phase 4 — Follow-Up Cadence (3 touches over 14 days)
- **Day 3** — gentle nudge + one additional value artifact (case study, data point, or relevant clip)
- **Day 7** — different angle (if Day 3 was "here's the proposal," Day 7 is "here's a specific scenario — what if we ran it with X tweak?")
- **Day 14** — clear out-or-yes email ("I'll stop here — is this a fit or not a fit?")

No follow-up beyond Day 14 unless partner responds. Chasing past Day 14 signals desperation and damages future reputation.

### Phase 5 — Sales-Call Discipline Check
Before sending, verify the written proposal passes the 8-stage sales-call filter:
- Stage 1 Frame: does the opener establish expert-to-expert posture, not fan-to-hero?
- Stage 2 Discovery: does the proposal reflect research into the partner's actual audience, not a generic pitch?
- Stage 3 Consequence: does the proposal name what the partner is missing by *not* partnering?
- Stage 4 Vision: is the proposed outcome specific (revenue + list growth + content asset) rather than vague?
- Stage 5 Solution: is the mechanism of the webinar itself specified, or is it a generic "we'll do a webinar together"?
- Stage 6 Objection: are the 3 likely objections pre-handled in the proposal body (quality, list fatigue, rev split)?
- Stage 7 Close: is there a clean decision ask, or does the proposal trail off?
- Stage 8 Lock: is the next step bookable immediately (Cal.com link embedded), not "I'll send you a calendar later"?

A proposal that fails more than 2 of these 8 stages is refused at ship. Rewrite.

### Phase 6 — Compliance + Brand Fit
- Banned vocabulary swept (JV outreach commonly leaks "leverage" and "synergy")
- Revenue claims comply with FTC / platform rules (no income guarantees for partner)
- Any testimonial used has client approval + FTC disclosure (per `/case-study` output)

## Decision Logic

### 1. WHY Fit Score >= 7 as the Refuse Threshold?
Below 7, the economics model breaks even at best, and the relational cost (burned bridge, neutral partner turning negative after a poor collaboration) exceeds the expected revenue. Partnerships compound through reputation — one bad JV with a mismatched partner costs three future good JVs. Below 7, the correct move is route to a higher-fit partner, not negotiate around the mismatch.

### 2. WHY 50/50 as the Default Split?
50/50 signals partnership posture. The partner's list is the asset the creator cannot build in 90 days; the creator's offer + delivery is the asset the partner cannot build in 90 days. Neither side's contribution is 2× the other's in a true co-host webinar. Starting at 70/30 in the creator's favor signals extraction and is the most common silent-decline reason. Starting at 50/50 and deviating only when list-contribution ratio is 3:1 or greater is the defensible rule.

### 3. WHY Personalized Opener Depth Matters?
A partner receives dozens of JV asks per quarter. The opener filters signal from noise inside 3 seconds. Generic opener = template response = 60%+ no-reply rate. Reference to a specific piece of their work from the last 30 days = signals effort = measurably higher response rate per the agency director Loom-audit discipline. Under-investing in the opener is the most common failure mode of junior operator outreach.

### 4. WHY Proposal Length Scales with Partner Tier?
Tier 1 partners (list 5×+ creator's, high-trust) get 2-3 page proposals — they are busy, the decision is short, over-explaining signals junior. Tier 2 partners (list 1-3× creator's, peer tier) get 4-6 page proposals — more context is expected, rev split and economics get more attention. Tier 3 partners (list < creator's, creator is doing a favor) may get 1-page proposals or a voice note — the ceremony is inverted. Calibrate length to the partner's time, not to the operator's pride of effort.

### 5. WHY Outreach Channel Selection Matters?
Cold email to a Tier 1 partner = lowest conversion channel. Warm intro from a mutual connection = highest. DM on their primary platform (wherever they actually spend time — often not LinkedIn) = mid. Podcast guest first, proposal second = highest-conversion multi-touch. Match channel to partner tier and pre-existing trust: Tier 1 needs warm intro or in-person event contact; Tier 2 can receive cold email if the opener is strong; Tier 3 accepts DM. Never send a cold email to a Tier 1 partner — it reads as asymmetric and burns the one shot.

### 6. WHY the 3-Touch Follow-Up Cadence?
Day 3 catches the partner who missed the first email in the inbox flood. Day 7 catches the partner who read but didn't respond because the ask wasn't clear enough — re-frame, don't repeat. Day 14 forces a decision and frees the creator to route the slot elsewhere. Beyond Day 14, the partner has effectively said no by silence — chasing further signals low-value time and damages the creator's standing if the partner ever does want to collaborate later. The cadence is a decision-forcing tool, not a nagging sequence.

### 7. WHY Push Past Silence vs Back Off?
Push past silence once, at Day 7, with a different angle — not a repeat. If Day 7's angle gets no response by Day 14, back off permanently for that partner for at least 6 months. Silence is a no. Respecting silence builds the creator's standing; chasing through silence destroys it. Come back in 6 months with a new offer, a new case study, or a new angle — treat it as a fresh opportunity, not a continuation.

### 8. WHY Gift/Value-First Before the Ask?
The highest-converting JV outreach pattern is: 30-90 days of public value directed at the partner's audience (commenting on their content, sharing their work, writing about their methodology) *before* the ask. The partner sees the creator's name repeatedly before receiving the proposal. By the time the ask lands, the partner already knows the creator isn't a stranger. Operators who skip this phase are trading long-term partner reputation for a shot at a cold-ask conversion — usually a bad trade below Tier 2 partner ceiling.

### 9. WHY Model Economics Conservatively?
A proposal with inflated numbers reads as junior the moment the partner runs their own math. Conservative + specific beats optimistic + round. "We estimate 3-5% close rate on live attendees based on our last three webinars averaging 4.1%" beats "we expect a 10% close rate." Partners with revenue history know the real benchmarks; any number outside the realistic range tells them the creator is either new or overselling. Under-promise, specify the assumption set, let the partner cross-check — that is what a serious operator looks like on paper.

### 10. WHY Treat the Proposal as a Sales Asset?
A proposal's polish is a proxy signal for the whole operation. The partner's implicit question: "if this is their best written output, what does their webinar look like?" Typos, vague revenue splits, missing attribution mechanism, no Cal.com link — each is a trust dent. Treat the proposal document the same way a VSL is treated: write it, rewrite it, read it aloud, send it only when it passes the same quality gate as any client-facing asset.

## Tacit Principles

1. **Never pitch a partner who hasn't first seen your work.** The highest-converting outreach is sent to a partner who already knows the creator's name from public commentary, guest appearances, or mutual network mentions. Cold pitches to unaware partners convert at 1/5 the rate of warm pitches. If the partner has never seen the creator's content, the correct move is 60 days of public visibility before the outreach, not a stronger email.

2. **The proposal is a mirror of the operation.** Sloppy proposal signals sloppy execution. Partners infer the quality of the webinar from the quality of the document. Formatting, specificity, absence of typos, presence of embedded Cal.com link — each is a proxy signal. A proposal that takes the creator 20 minutes to write produces a 20-minute response: "not right now." A proposal that takes 4 hours and reads like a finished product produces a conversation.

3. **If you wouldn't trade your audience for theirs, neither will they.** The honesty test before sending: would the creator feel equal value in receiving the partner's audience promotion as the partner would in receiving the creator's offer? If not, the rev split is wrong or the fit is wrong. Partners feel asymmetric value exchange within one paragraph of the proposal.

4. **Revenue split is the frame, not the ask.** Partners are not negotiating revenue split first — they are evaluating fit first. Once fit is established, 50/50 is almost always accepted without pushback. The proposals that fail on rev split almost always failed on fit earlier, and the rev-split rejection is the polite cover.

5. **Specificity in economics beats optimism in economics.** A conservative model with citations to the creator's own baseline beats an optimistic model with round numbers. Partners with experience recognize realistic ranges; any model outside those ranges is dismissed as amateur. The model is a credentialing artifact, not a persuasion tool.

6. **One ask, one decision, one next step.** Junior operators stack asks ("would you do a webinar, or share my lead magnet, or swap an email?"). Senior operators ask one thing and book one call. Multiple asks signal uncertainty about which is the right ask, which signals the operator hasn't thought it through. Pick the single highest-return ask for the specific partner, ask only that.

7. **Silence is a no. Treat it as intelligence, not insult.** A partner who doesn't respond to Day 7 follow-up has effectively declined. Respecting that decline is reputational capital. Chasing past Day 14 burns that capital for zero expected return. The creator who respects silence gets pitched *back* by partners who finally have capacity — the creator who chases does not.

8. **Partnerships compound through reputation, not individual deals.** One great JV produces three more introductions. One burned JV produces three silent declines six months later. The single deal is always a rounding error compared to the partner-network externality. This reframes why fit score matters — a poorly-executed JV with a mid-fit partner is a tax on every future partnership motion the creator runs.

9. **The creator's public surface is the first proposal.** Before the partner reads the written proposal, they audit the creator's most recent public output — last 3 videos, last 10 posts, landing page, offer page. If those are weak, the written proposal doesn't recover the first impression. The implicit prerequisite: the creator's public surface must be ready before the outreach motion starts.

10. **Partner selection is the skill, not partner pitching.** Operators who pitch 50 mismatched partners and close 1 are running a worse motion than operators who research 5 high-fit partners and close 2. The output is similar in the short run; the partner-network externality diverges sharply. Select, don't spray.

## Output Format

```markdown
# JV Webinar Proposal — [Partner Name] — [Creator Brand]

**Partner:** [name + brand]
**Partner Audience Size:** [N estimated]
**Partner Tier:** [1 | 2 | 3]
**Fit Score:** [N/10 aggregate + per-dimension breakdown]
**Rev Split:** [partner % / creator %]
**Expected Revenue (creator side, expected case):** $[N]
**Version:** 1.0

---

## Personalized Opener
[specific reference to partner's recent work from last 30 days — not generic]

## Audience Overlap (ICP-level)
| Dimension | Partner's ICP | Creator's ICP | Overlap |
|---|---|---|---|
| Role / stage | [...] | [...] | [%] |
| Pain pattern | [...] | [...] | [%] |
| Outcome desired | [...] | [...] | [%] |
| Accessible resources | [...] | [...] | [%] |

## Webinar Proposal
- Topic: [specific problem + mechanism tease]
- Format: [live / evergreen / challenge — with reasoning]
- Proposed Date: [...]
- Duration: [90 min standard]
- Co-creation scope: [who does what, down to the minute — not "we'll figure it out"]

## Revenue Split
[specified upfront: partner X% / creator Y%]
[if non-default, explicit reasoning for the deviation]

## Logistics
- Promotion schedule: [partner email cadence + social + DM sequence — per day]
- Platform: [Zoom / Livestorm / StreamYard]
- Tech ownership: [who provides registration page, who provides stream, who hosts]
- Attribution: [UTM + CRM tag + ledger process — specified, not "we'll track it"]
- Payment flow: [which side collects, settlement schedule]
- Contract: [single-page agreement or PandaDoc template referenced]

## Expected Economics (3-scenario model)
| Scenario | Partner List | Attendance | Close Rate | AOV | Gross | Creator Side |
|---|---|---|---|---|---|---|
| Conservative | [N] | [%] | [%] | $[N] | $[N] | $[N] |
| Expected | [N] | [%] | [%] | $[N] | $[N] | $[N] |
| Optimistic | [N] | [%] | [%] | $[N] | $[N] | $[N] |

**Assumptions cited from:** [creator's prior webinar data — attendance rate X% based on N prior events, close rate Y% based on N closes]

## Social Proof
- Prior JV results: [if any, specific numbers + partner names]
- Published case studies relevant to partner's audience: [2-3 from `/case-study` output]

## CTA
> "Open for a 20-min conversation to walk through fit + answer questions. Cal.com: [link]. Or reply here with preferred time."

---

## Follow-Up Cadence
- **Day 3 — gentle nudge:** [one paragraph + one additional artifact]
- **Day 7 — different angle:** [re-framed proposal, not a repeat]
- **Day 14 — out-or-yes:** [clear decision ask, respect either outcome]

## Outreach Channel Selection
- Primary: [email / DM / warm intro — with reasoning]
- Channel rationale: [tier match]
- Pre-warm activities (last 60 days): [visibility audit — what the partner has already seen from the creator]

## Sales-Call Discipline Audit
- [ ] Stage 1 Frame — expert-to-expert posture
- [ ] Stage 2 Discovery — partner-specific research evident
- [ ] Stage 3 Consequence — named cost of non-partnership
- [ ] Stage 4 Vision — specific outcome described
- [ ] Stage 5 Solution — webinar mechanism specified
- [ ] Stage 6 Objection — 3 likely objections pre-handled
- [ ] Stage 7 Close — clean decision ask
- [ ] Stage 8 Lock — bookable next step embedded

## Compliance
- [ ] Banned vocabulary swept
- [ ] No income guarantees to partner
- [ ] Case studies used have FTC disclosure + client approval
- [ ] Attribution mechanism legally defensible

---

## Appendix A — Personalized Opener Variants (A/B)
## Appendix B — Webinar Topic Outline (pre-`/webinar-script`)
## Appendix C — Contract Draft (triggered post-verbal-yes)
```

## Quality Gates

- [ ] Partner fit score >= 7/10 (all 4 dimensions)
- [ ] Personalized opener references last-30-day partner work
- [ ] Rev split specified (no "let's discuss" language)
- [ ] Logistics detailed down to attribution mechanism
- [ ] 3-scenario economics model with cited assumptions
- [ ] Cited case studies have FTC disclosure + client approval
- [ ] 3-touch follow-up cadence defined
- [ ] Outreach channel matched to partner tier
- [ ] Sales-call 8-stage discipline audit passes 6+/8
- [ ] Creator's public surface audited and ready
- [ ] Banned vocabulary swept
- [ ] Triple-layer S/N >= 0.8
- [ ] Signal score >= 0.8

## Banned Vocabulary

Per `spec/BANNED-VOCABULARY.md`. JV outreach commonly leaks:
- `leverage` / `synergy` / `synergistic` — banned outright
- `unlock` / `unleash` / `supercharge` — banned outright
- `game-changer` / `revolutionary` / `next-level` — banned outright
- "Let's dive in" / "at the end of the day" / "moving forward" — banned filler
- "Happy to hop on a call" — sycophantic, use direct "20-min conversation — Cal.com link"
- "I'd love to..." / "I'd be happy to..." — banned opening patterns (read as junior)
- Em-dashes in outreach body copy — per Syed global preference

A proposal with any of these signals the creator is either AI-assisted-without-editing or junior; Tier 1 partners drop the thread on sight.

## Cross-References

- `reference/operators/growth-engineer.md` (Partner Webinar System + hidden-pitch long-form video + trust-transfer mechanic)
- `reference/operators/operations-director.md` (60/30/10 revenue mix — JV bucket allocation)
- `reference/operators/agency-director.md` (Loom-audit outreach pattern — personalization discipline)
- `reference/operators/backend-economist.md` (benchmarking discipline — economics model must be specific)
- `reference/operators/offer-architect.md` (Ownership Selling — proposal as sales call on paper)
- `reference/frameworks/sales/full-stack-sales-call-8-stage.md` (primary discipline filter)
- `reference/frameworks/sales/8-required-beliefs.md` (beliefs 3, 5, 6, 7, 8 installed in proposal body)
- `reference/frameworks/growth-operating-process/60-30-10-revenue-mix.md` (JV bucket placement)
- `reference/knowledge/launch.md` (Phase 1 Pre-Launch partner recruitment)
- `reference/frameworks/acquisition-economics/core-four.md` (warm-reach quadrant — JV is warm by default)

## Important Rules

- **NEVER send template-feel outreach.**
- **NEVER leave rev split ambiguous.**
- **NEVER pitch a partner who has never seen the creator's work.**
- **NEVER chase past Day 14 without a reset gap.**
- **NEVER inflate economics — cite the baseline.**
- **NEVER stack asks — one ask, one decision.**
- **ALWAYS personalize opener with last-30-day reference.**
- **ALWAYS model economics with 3 scenarios + cited assumptions.**
- **ALWAYS pass the 8-stage sales-call audit before sending.**
- **ALWAYS audit the creator's public surface before the outreach motion.**
- **ALWAYS respect silence as a no.**

## Next Skills

- `/webinar-script` — produces the webinar itself (consumes topic + co-creation scope from this output)
- `/email-sequence` type 4 — partner-list promotion sequence (3-5 emails over 7 days)
- `/email-sequence` type 7 — post-webinar follow-up to attendees
- `/case-study` — if the JV converts, document as future-partnership proof asset
- `/launch-report` — attribution + revenue accounting post-event
- `/affiliate-program` — if JV converts to ongoing relationship, formalize as affiliate tier

## References

- the growth engineer Partner Webinar System (`reference/operators/growth-engineer.md`)
- the operations director 60/30/10 revenue mix (`reference/frameworks/growth-operating-process/60-30-10-revenue-mix.md`)
- Full-Stack Sales Call 8-Stage (`reference/frameworks/sales/full-stack-sales-call-8-stage.md`)
- 8 Required Beliefs — the VSL director (`reference/frameworks/sales/8-required-beliefs.md`)
- the agency director Loom-audit outreach pattern (`reference/operators/agency-director.md`)
- Partnerships department Department canonical (internal) `[UNVERIFIED — Growth Operating Agency canonical doc path not located during encoding]`
- the backend economist benchmarking discipline (`reference/operators/backend-economist.md`)

---
*v2.0 — 2026-04-19. Cycle 6 Partnerships. Upgraded from v1.0 with Decision Logic + Tacit Principles per gold-standard format.*
