---
name: case-study
description: Convert a client win into a publishable case study per the Growth Operating Agency 6-Level Social Proof Hierarchy + the offer architect Isomorphic Story principle. Produces one full written case study (800-1500 words), one VSL insert (60-90s), one ad variant (30s), one LinkedIn post, one X thread, one email broadcast, plus FTC disclosure and client-approval record. Target output: Level 5 or Level 6 proof only. Lower-level testimonials are routed to aggregate-proof channels, not hero case studies.
signal:
  mode: linguistic
  genre: case-study
  type: inform
  format: markdown
  structure: w-case-study
  receiver: prospects + marketing assets
  receiver_capacity: medium
department: scale
agent_affinity: [scale-head, case-study-producer]
required_compartments:
  audience_intelligence_system: 50
  copy_messaging: 40
  lifecycle_optimization: 30
upstream_dependency: retention-check
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  crm: gohighlevel-api
  video: [loom-api, vimeo-api]
credentials_required: [GHL_API_KEY]
evidence_gate:
  - isomorphic_fit_verified
  - raw_interview_captured
  - 6_level_hierarchy_classified
  - multiple_format_outputs
  - ftc_disclosure
  - client_approval
  - signal_score_gte_0_8
keywords:
  - case study
  - testimonial
  - client result
  - success story
  - proof asset
priority: 1
version: 1.0
---

# /case-study — Client Result → Case Study Converter

## Usage

Run after `/retention-check` identifies a Thriving client. Input: client name + outcome metric + ICP match. Output: full written case study, plus five derivative assets ready for distribution. Interactive — skill refuses to ship without raw interview capture, isomorphic fit check, and signed client approval.

## What It Does

Converts a client win into a proof stack: one long-form written asset and five derivative formats, all sourced from a single 30-60 min unscripted interview. Grades the asset on the Growth Operating Agency 6-Level Social Proof Hierarchy and isomorphic fit against the ICP. Refuses to publish anything below Level 5. Refuses to publish a non-isomorphic case study in a hero slot, even if the numbers are larger, because a non-isomorphic case study converts worse than no case study at all.

## Role (Lineage)

Growth Operating Agency 6-Level Social Proof Hierarchy (canonical source for proof grading). the offer architect Isomorphic Story Principle (starting-situation + outcome + process must all map to prospect). the growth engineer Offer Proof Flywheel (case studies feed offer strength, not the other way around). the content OS director 1-2 Hour Consumption Rule (case study is consumption content, not pitch content). the backend economist EP83 One-Funnel Compounding Model (case studies reinforce the single funnel's proof base — no kitchen-sink cases).

## Agent

`@scale-head` + `@case-study` sub-agent. Interviewer discipline is sub-agent's job. Isomorphic fit check is `@scale-head`'s ship gate.

## Destination

`output/cycle-5-scale/case-studies/{client-slug}/` containing: `case-study.md` (full), `vsl-insert.md`, `ad-30s.md`, `linkedin-post.md`, `x-thread.md`, `email-broadcast.md`, `raw-interview.md`, `ftc-disclosure.md`, `client-approval.md`.

## Prerequisites

- `/retention-check` output confirming Thriving status (not Struggling, not At-Risk)
- ICP Doc — the isomorphic-fit check depends on its 4-layer pain + 4-layer desire + demographic profile
- Offer Doc — mechanism names and sub-steps must be referenced in the Implementation section
- Raw recording capacity (Zoom / Riverside / Loom — Level 6 proof requires the unscripted video asset, not just a transcript)
- FTC disclosure template approved by legal
- Client verbal pre-consent before the interview is booked

## The 6-Level Social Proof Hierarchy (Growth Operating Agency canonical)

| Level | Type | Trust | Asset Use |
|---|---|---|---|
| 6 | Raw mentee video interview (unscripted, on camera) | HIGHEST | Hero case study — VSL insert, ad, landing page |
| 5 | Written testimonial + photo + verifiable result (link / screenshot / public proof) | HIGH | Hero case study text, email broadcast |
| 4 | Written testimonial + photo | MEDIUM-HIGH | Aggregate proof wall, supporting case study |
| 3 | Written testimonial (no photo) | MEDIUM | Aggregate proof wall |
| 2 | Screenshot of DM / Slack / review | LOW-MEDIUM | Aggregate proof grid, ad creative |
| 1 | "Great product" generic comment | LOWEST | Never use standalone |

**Hero case studies = Level 5 or 6 only.** Level 1-4 can appear in aggregate proof walls, ad creative collages, or supporting quotes — never as the headline proof for a VSL or offer page.

## The Isomorphic Story Check (7-phase offer methodology)

A case study converts only when the prospect sees themselves in it. Three dimensions must match, not one:

- **Starting situation** — client's role, stage, resource level, and constraints must match the prospect's
- **Outcome** — the specific result must match what the prospect's ICP desire names, not what is most impressive in the portfolio
- **Process** — the implementation path must use resources the prospect could plausibly access (time, team, budget, tool stack)

Non-isomorphic case study = impressive-but-trust-leaky. A "closed $1M in 90 days" case from an ex-enterprise-VP reads as irrelevant to a solo coach at $8K/mo, and the mismatch actively erodes belief 5 (this-offer) and belief 8 (trust-expertise). Use non-isomorphic wins as testimonials in aggregate walls, never as heroes.

## Process

### Phase 0 — Load
- Thriving client record from `/retention-check`
- ICP Doc (for isomorphic fit check — specifically the 4-layer pain, demographic profile, and buying-triggers sections)
- Offer Doc (mechanism name + sub-steps)
- Growth Operating Agency 8 Required Beliefs (the case study will install beliefs 3, 6, 7, 8 — verify alignment before interview)

### Phase 1 — Client Qualification Gate
- Thriving status confirmed in last 30 days
- Specific outcome with verifiable metric (revenue, transformation milestone, measurable before/after)
- Willing to share publicly under real name (pseudonymization degrades trust one notch)
- FTC-disclosure-ready (client understands the "results not typical" framing)

If any gate fails, route client to the next phase — do not pressure a fragile win into a case study slot.

### Phase 2 — Raw Interview Capture (30-60 min recorded)
Seven-beat interview script:
1. Starting situation — exact month, exact revenue or state
2. Before state — 4-layer pain (surface / real / private / secret), in their words
3. Moment of decision — what specific trigger made them buy (the "I saw X and thought Y" moment)
4. Implementation — which named mechanism sub-steps they applied, in which order
5. Journey — obstacles + breakthroughs (not a highlight reel — the dip is what makes the recovery credible)
6. Outcome — specific numbers + timeframe + what changed in life/business outside the metric
7. Advice-to-past-self — their framing, not yours

Record on video even if the plan is written-only. Level 6 assets compound — the clip can feed ads, VSL inserts, and social for 18+ months after publish.

### Phase 3 — Isomorphic Fit Verification (ship gate)
Cross-check client against ICP Doc on all three dimensions:

| Dimension | Client | ICP | Match? |
|---|---|---|---|
| Starting stage/role | [client] | [ICP] | Y / N |
| Pain pattern | [client 4-layer] | [ICP 4-layer] | Y / N |
| Outcome desired | [client result] | [ICP aspiration] | Y / N |
| Process accessibility | [client resources] | [ICP resources] | Y / N |

All four must match for hero-case-study publication. If 2 of 4 match, use as supporting case or testimonial — do not publish as hero.

### Phase 4 — Write Case Study (full, 800-1500 words)
Per W(case-study) 8-section structure below.

### Phase 5 — Derivative Outputs
- VSL insert (60-90s, inserted at 15-step Step 8 Testimonials position)
- Ad variant (30s, pure client voice with B-roll — no creator voiceover)
- LinkedIn post (the backend economist EP83 benchmarking — one-specific-number hook)
- X thread (7-12 tweets, outcome first, process second)
- Email broadcast (story arc with direct CTA to offer)

### Phase 6 — Client Approval + FTC
- Client reviews full written case study + all derivatives before publication
- Client signs off in writing (email sufficient; recorded verbal for Level 6 video assets)
- FTC disclosure placed on every published asset ("Results not typical. [Client] is a paying customer whose experience does not guarantee similar outcomes.")
- Results disclaimer calibrated to regulatory vertical (FTC for US, ASA for UK, stricter rules for health/financial niches per the growth engineer *Meta Ad Restrictions Prep*)

### Phase 7 — Publication Channel Fit
Pick the primary distribution channel before writing the derivatives, not after — the channel shapes the beat emphasis:

- **VSL insert** — emotion-heavy, mechanism-reinforcing (the VSL director Step 8)
- **Organic YouTube** — story arc, 5-7 min (the content OS director Value content, no external CTA)
- **LinkedIn** — data-first hook (the backend economist benchmarking discipline — "specific number" opening)
- **Paid ad** — 30s, high-retention edit, client voice only
- **Email broadcast** — story + offer link (the operations director 10% email revenue bucket)
- **Landing page** — static proof block, one per page max (cognitive load)

## Decision Logic

### 1. WHY Story Arc vs Data-Driven?
Story arc = Levels 5-6 with emotional journey (obstacle → breakthrough → outcome). Data-driven = numbers-first hook when the metric is category-breaking ("$0 to $47K/mo in 90 days"). Default to story arc — data-driven dominates only when the ICP is analytical (engineers, quants, operators who trust numbers over narrative). Story arc always carries the 4-layer pain; data-driven still needs pain mentioned inside the proof, not omitted.

### 2. WHY Feature the Client, Not the Agency/Creator?
The prospect must see themselves in the case study. A case study that centers the creator's heroics centers the wrong person — the prospect thinks "the creator is great" instead of "I could be this client." the content OS director's rule applies: Value content never links out; case-study content never self-promotes. The creator's role is implementation partner, not hero. The client closes the sale in their own voice.

### 3. WHY the Isomorphic-Fit Rule (the non-negotiable)?
Pattern: mid-stage operators publish their most impressive case first. That case is almost always non-isomorphic — ex-enterprise VPs, outliers, lottery winners. Prospects at the ICP's real stage read it and disqualify themselves. The correct hero case is the one closest to the ICP's exact starting point, even if the absolute numbers are smaller. A $47K/mo case beats a $470K/mo case when the prospect is at $5K/mo.

### 4. WHY Proof-Stack Ordering?
Order proof by identification distance from the prospect, not by size of result. Open with the closest-match client (lowest identification distance), escalate to larger results as the prospect's belief scaffolds. A landing page that opens with the largest result and scales down burns the only shot at identification. 15-step Step 8 Testimonials mirrors this — Expert Endorsement first, Dream Result second, Initial Win third.

### 5. WHY Narrative Type Selection?
Five narrative types; pick one per case, never mix:
- **Underdog** — client started from a weaker position than the ICP; proves "even I can"
- **Transformation** — large delta on one specific axis; proves the mechanism works
- **Validation** — expert or peer endorsing the mechanism; proves category-legitimacy (the VSL director Expert Endorsement)
- **Mechanism-reveal** — walks through *how* the mechanism worked in this specific case; proves reproducibility
- **Fast-win** — first-30-day outcome; proves time-delay is low (Value Equation score input)

Match the narrative type to the ICP's dominant objection. Underdog for "not me" objection. Validation for "category skepticism" objection. Fast-win for "how long until results" objection.

### 6. WHY Interview Depth Over Output Length?
A 60-minute interview produces a better 800-word case study than a 20-minute interview produces a 1,500-word case study. Depth surfaces the specific verbatim lines that make the copy feel earned — the "I remember sitting in my car that Thursday" moments. Thin interviews produce fillable-template output. If the interview didn't produce 3+ memorable specific-moment quotes, go back — don't pad to length.

### 7. WHY Quote Verbatim vs Paraphrase?
Quote verbatim when the client's phrasing is more specific, more emotional, or more voice-of-customer than a rewrite would be. Paraphrase only when the verbatim is rambling, structurally broken, or contains information the client would want edited. the copy director-lineage rule — verbatim VOC is the only language that bypasses ad blindness. Paraphrased client speech reads like creator speech, which defeats the point.

### 8. WHY One Transformation Per Case?
No kitchen-sink case studies. One client, one transformation, one outcome-metric-that-matters. Case studies that list "increased revenue 4×, cut hours 50%, hired 3 people, launched course, won award" read as promotional collage and install no belief cleanly. The single transformation is the spine; everything else is texture, mentioned only if it reinforces the single transformation. the backend economist benchmarking rule transferred: one video, one concept, no "kitchen sink."

### 9. WHY Publication Channel Determines Beat Emphasis?
Beat weighting shifts by channel. VSL insert leads with the emotional obstacle (the dip). Landing page leads with the outcome number (fast reassurance). Email broadcast leads with the story hook (curiosity). LinkedIn leads with the specific benchmark number. Same case, same truth, five different opening beats. Writing the derivatives without channel assignment produces generic-average outputs that underperform on every channel.

### 10. WHY FTC + Client Approval Are Absolute Ship Gates?
One case study with a false or unverifiable claim can subject the operator to FTC action, platform demonetization, and creator-brand collapse. FTC disclosure is cheap insurance; client approval is credibility insurance. The 10 minutes to get a written approval email from the client is the highest-return 10 minutes in the whole pipeline. No exceptions — not for "they said yes on the call," not for "they're a friend," not for launch-week pressure.

## Tacit Principles

1. **Specificity over plausibility.** A case study that says "I made $47,312 in my second month" beats one that says "I made over $40K." Specificity is the signal that the story is real. Round numbers read as written, precise numbers read as lived.

2. **The client's voice closes, not yours.** The creator's role in the written case study is structural — set the scene, frame the context, step out. The closing paragraph is almost always a verbatim client quote. When the creator tries to close with their own framing, the prospect feels the sales pitch and the proof leaks trust.

3. **The data is the hook, not the proof.** An opening line with a specific number earns the click. The proof is the story that follows — the obstacles, the decision, the implementation. Hook with the data, prove with the narrative. A case study that opens with data and stays in data reads as a LinkedIn metrics flex, not a transformation story.

4. **One transformation per case, no combinatorial wins.** If a client transformed on three axes, publish three separate case studies or pick the one most isomorphic to the prospect. Combining wins in one asset dilutes each; prospects cannot identify with three transformations at once, and the case reads as boasting.

5. **The obstacle is the asset.** The highest-converting moment in a case study is almost always the dip — the week the client almost quit, the month their metrics tanked, the call where they doubted. The dip is what makes the outcome credible. Case studies that are highlight reels without a dip read as fabricated, even when they are true.

6. **Verbatim beats polished.** The exact line "I was literally crying in my car" is stronger copy than "I was emotionally overwhelmed." The raw interview is the source — the editing job is to cut, not to smooth. Over-polished client language reads as ghostwritten and collapses the trust the whole asset is built to install.

7. **The interview is the asset; the transcript is the deliverable.** Record on video even for written-only plans. The recording compounds — future ad creative, future VSL inserts, future landing-page video headers can all pull from the same interview. The operator who records once and harvests 18 months beats the operator who re-interviews every quarter.

8. **Isomorphic beats impressive.** This is the rule most frequently violated. The larger result is always the tempting hero. The smaller, closer-match result is always the correct hero. Run the isomorphic check on every new case before the writing phase, not after.

9. **Publication channel chosen before writing.** Assign the primary channel before drafting — not after. The channel's attention pattern determines which beat opens, which quotes surface, which length caps. Same case, five channels, five different lead beats.

10. **Client approval in writing, always.** Verbal approval disappears. Written email approval — or a signed release form for Level 6 video — is the only record that survives a legal challenge or a later client reversal. The approval record is part of the case-study file, stored with the final asset.

## Output Format

```markdown
# Case Study — [Client Name] — [Outcome Headline]

**Client:** [real name or anonymized with role + stage]
**Outcome:** [specific numbers + timeframe]
**Social Proof Level:** [5 | 6]
**Isomorphic Fit:** [VERIFIED — all 4 dimensions match ICP]
**Narrative Type:** [Underdog | Transformation | Validation | Mechanism-reveal | Fast-win]
**Primary Channel:** [VSL | Landing page | Email | LinkedIn | Paid ad | YouTube]
**FTC Disclosure:** [present + jurisdiction]
**Version:** 1.0

---

## 1. Client Portrait
[role, stage, starting situation — specific demographic + firmographic detail]

## 2. Before State (4-layer pain, client's words)
- Surface: [...]
- Real: [...]
- Private: [...]
- Secret: [...]

## 3. Moment of Decision
[the specific trigger event — "I saw X, I thought Y, I did Z"]

## 4. Implementation
[named mechanism sub-steps applied, in the order they were applied]

## 5. Journey (obstacle + breakthrough)
- The dip: [week or month it got hardest]
- The pivot: [what changed]
- The breakthrough: [specific moment]

## 6. Outcome
[specific numbers + timeframe + life/business change outside the metric]

## 7. Advice-to-Past-Self
[verbatim client framing]

## 8. Bridge to Prospect
[explicit map: "If you are at [ICP stage] with [ICP pain], this is the path"]

---

## Derivative Outputs

### VSL Insert (60-90s, the VSL director Step 8 position)
[script — client voice primary, creator voice secondary]

### Ad Variant (30s, client voice only)
[script + B-roll notes]

### LinkedIn Post (one-number hook)
[copy]

### X Thread (7-12 tweets, outcome-first)
[copy]

### Email Broadcast (story + offer)
[copy]

---

## Client Approval + FTC
- Approved by: [client name / date / method — email / signed form / recorded verbal]
- FTC disclosure: "Results not typical. [Client] is a paying customer whose experience does not guarantee similar outcomes."
- Jurisdiction: [US FTC / UK ASA / EU / etc.]
- Vertical-specific disclaimers: [if health / financial / earnings]

## Raw Interview (appendix)
[full transcript + video file reference]

## Belief Installation Map
| # | Belief | Installed at | Reinforced at |
|---|---|---|---|
| 3 | Can-fulfill | Section 4 Implementation | Section 6 Outcome |
| 6 | Better/faster | Section 5 Journey | Section 6 Outcome |
| 7 | Trust-person | Section 3 Decision | Section 7 Advice |
| 8 | Trust-expertise | Section 4 Implementation | Section 6 Outcome |
```

## Quality Gates

- [ ] Client Thriving status verified (last 30 days)
- [ ] Raw interview captured on video (30-60 min)
- [ ] Isomorphic fit verified across all 4 dimensions
- [ ] Social Proof Level 5 or 6 assigned
- [ ] Narrative type selected (single type, no mixing)
- [ ] Primary publication channel selected before drafting
- [ ] Full written case study (800-1500 words, 8 sections)
- [ ] Five derivatives produced (VSL / ad / LinkedIn / X / email)
- [ ] Client approval in writing
- [ ] FTC disclosure present + jurisdiction-calibrated
- [ ] Verbatim quote count >= 3
- [ ] Belief Installation Map populated (beliefs 3, 6, 7, 8)
- [ ] Banned vocabulary swept
- [ ] Triple-layer S/N >= 0.8
- [ ] Signal score >= 0.8

## Banned Vocabulary

Per `spec/BANNED-VOCABULARY.md`. Case study copy commonly leaks:
- `unlock` / `unleash` / `transform` / `empower` — cut every instance, use specific verbs
- `game-changer` / `game-changing` — banned outright
- `revolutionary` / `next-level` — banned outright
- `dive into` / `leverage` / `harness` — banned outright
- "At the end of the day" / "The bottom line is" — banned filler
- Em-dashes in client-voice sections — per Syed global preference

Case studies that leak these read as agency-written, not client-lived. One instance is enough to drop Social Proof Level from 6 to 4 subjectively.

## Cross-References

- `reference/operators/backend-economist.md` (EP83 one-funnel case study framing, E56 skill-compounding case pattern)
- `reference/operators/content-os-director.md` (three signature breakdown case studies — $178K / $57K / $246K)
- `reference/operators/growth-engineer.md` (Offer Proof Flywheel — case studies feed offer strength)
- `reference/operators/offer-architect.md` (Isomorphic Story Principle — primary lineage)
- `reference/frameworks/sales/8-required-beliefs.md` (beliefs 3, 6, 7, 8 installed by case studies)
- `reference/frameworks/esoteric-marketing/README.md` (the offer architect isomorphic framework) `[UNVERIFIED — path depends on repo structure]`
- `reference/frameworks/vsl-director/8-required-beliefs-deep.md` (the VSL director canonical belief installation)
- `reference/knowledge/launch.md` (case study as Phase 2 Runway asset)

## Important Rules

- **NEVER publish without written client approval.**
- **NEVER fabricate or round numbers.**
- **NEVER skip FTC disclosure.**
- **NEVER publish a non-isomorphic case as hero.**
- **NEVER mix narrative types in a single case.**
- **NEVER let the creator's voice close — the client closes.**
- **ALWAYS capture raw interview on video** (Level 6 assets compound 18+ months).
- **ALWAYS assign publication channel before drafting derivatives.**
- **ALWAYS run the 4-dimension isomorphic check before the writing phase.**
- **ALWAYS include the dip** — highlight-reel cases erode trust.

## Next Skills

- `/build-vsl` — insert case at the VSL director Step 8 position
- `/ad-creative` — derivative ad variant feeds paid creative family
- `/write-linkedin-post` + `/write-x-thread` — organic distribution of derivatives
- `/email-sequence` — broadcast reference + nurture embedding
- `/retention-check` — sources next case-study candidates

## References

- Growth Operating Agency 6-Level Social Proof Hierarchy (canonical grading source)
- the offer architect Isomorphic Story Principle (`reference/operators/offer-architect.md`)
- the growth engineer Offer Proof Flywheel (`reference/operators/growth-engineer.md`)
- the backend economist benchmarking + specificity discipline (`reference/operators/backend-economist.md`)
- the content OS director three signature breakdowns as case-study archetypes (`reference/operators/content-os-director.md`)
- 8 Required Beliefs — beliefs 3, 6, 7, 8 (`reference/frameworks/sales/8-required-beliefs.md`)

---
*v2.0 — 2026-04-19. Cycle 5 Scale. Upgraded from v1.0 with Decision Logic + Tacit Principles per gold-standard format.*
