# Skills Index — Growth Operating Agency

> **36 shipped skills**, organized by department. Each skill is a **folder**:
> `skills/{slug}/SKILL.md + reference/ + examples/ + evidence/ + adapters/`
>
> **Discovery pattern:** runtime scans `skills/*/SKILL.md` at boot (one level deep, flat).
> **Execution pattern:** runtime reads the SKILL.md body and follows the Process section.
> **Runtime binding:** `skills/{slug}/adapters/{runtime}.{ext}` — slash-command runtime and the workspace manifest ship as primary.

## Status legend

- ✅ Shipped — full SKILL.md + adapters + evidence scaffolding
- 🟡 v1.1 target — skill reserved for next minor release
- ⏳ v2.0 roadmap — future department expansion

---

## Foundations — Foundations Block (5)

| # | Skill | Purpose | Status |
|---|---|---|---|
| 1 | `research` | Market Research Brief (9-section bootstrap) | ✅ |
| 2 | `build-icp` | ICP Document (13 sections, Completeness Score ≥ 80) | ✅ |
| 3 | `build-positioning` | Positioning Document (Vehicle Switch, Mechanism, Core Belief, Narrative) | ✅ |
| 4 | `design-offer` | Offer Document (12 sections, Value Stack, Bonuses, Guarantee, 3:1 economics gate) | ✅ |
| 5 | `extract-voice` | Brand Voice Architecture (Compartment 1) from creator content | ✅ |

## Marketing — Marketing Block (8)

| # | Skill | Purpose | Status |
|---|---|---|---|
| 6 | `content-calendar` | 30-day content calendar (mix ratios per framework) | ✅ |
| 7 | `ad-creative` | Paid ad creative brief + copy across ad types | ✅ |
| 8 | `write-linkedin-post` | LinkedIn post promoting the offer (INV-8 scoped) | ✅ |
| 9 | `write-reel` | Short-form script (Reels / TikTok / Shorts) | ✅ |
| 10 | `write-youtube` | YouTube video script across video types | ✅ |
| 11 | `write-x-thread` | Twitter / X thread across thread types | ✅ |
| 12 | `story-sequence` | 7-day Instagram Story sequence (4-layer anatomy) | ✅ |
| 13 | `tripwire-design` | $7-$97 entry offer across 7 archetypes + full economics + ascension ladder | ✅ |

## Nurture — Nurture Block (4)

| # | Skill | Purpose | Status |
|---|---|---|---|
| 14 | `lead-magnet` | Lead magnet design + copy across 9 types | ✅ |
| 15 | `email-sequence` | Email sequence across 8 types | ✅ |
| 16 | `webinar-script` | Webinar or challenge script (Live / Evergreen / 3-5-7-Day / Workshop) | ✅ |
| 17 | `post-booking-nurture` | Confirmation page + 24h / 6h / 1h email + personal SMS | ✅ |

## Sales — Sales Block (9)

| # | Skill | Purpose | Status |
|---|---|---|---|
| 18 | `build-vsl` | Full VSL script across framework variants | ✅ |
| 19 | `build-funnel` | Funnel architecture across 7 archetypes | ✅ |
| 20 | `competitor-intel` | Competitor teardown + positioning gap analysis | ✅ |
| 21 | `sales-script` | High-ticket 8-stage discovery-pitch-close script + 12 objection reframes + 3 closing archetypes | ✅ |
| 22 | `objection-library` | Encoded library of 20+ objections x 3-layer reframes x proof stack x escalation scripts | ✅ |
| 23 | `call-prep` | 1-page pre-call brief via 15-minute routine — archetype match, pain anchors, objection pre-empts | ✅ |
| 24 | `proposal` | 1-page post-call proposal ($3K-$50K programs) — scope / timeline / payment / risk reversal | ✅ |
| 25 | `application-form` | High-ticket qualifying application (3 archetypes) with DQ logic and Call Brief signal handoff | ✅ |
| 26 | `landing-page` | 4-page stack (opt-in / offer / thank-you / checkout) with 4 variants per page, research-mechanism-brief-copy 7-section | ✅ |

## Launch (2)

| # | Skill | Purpose | Status |
|---|---|---|---|
| 27 | `plan-launch` | Launch plan across 5 types with 5-phase SOP | ✅ |
| 28 | `launch-report` | Post-launch performance analysis + recommendations | ✅ |

## Scale (5)

| # | Skill | Purpose | Status |
|---|---|---|---|
| 29 | `build-sop` | SOP for a team role or process | ✅ |
| 30 | `hiring-brief` | Hiring brief with scorecard + ideal profile | ✅ |
| 31 | `retention-check` | Client health scoring + churn prevention | ✅ |
| 32 | `revenue-report` | Revenue analysis, forecasting, P&L | ✅ |
| 33 | `case-study` | Case study from a client result | ✅ |

## Partnerships (3)

| # | Skill | Purpose | Status |
|---|---|---|---|
| 34 | `jv-webinar-proposal` | Partner outreach for joint venture webinar | ✅ |
| 35 | `affiliate-program` | Affiliate program structure + payout schema | ✅ |
| 36 | `referral-program` | Referral program mechanics | ✅ |

---

## Skill count summary

- **Foundations:** 5
- **Marketing:** 8
- **Nurture:** 4
- **Sales:** 9
- **Launch:** 2
- **Scale:** 5
- **Partnerships:** 3
- **Total shipped:** **36**

## Command binding

Every skill maps 1:1 to a slash-command in `.claude/commands/{slug}.md`. manifest bindings live in `skills/{slug}/adapters/manifest.yaml`. Any runtime that reads markdown + YAML can invoke a skill by copying the `SKILL.md` body.

## Skill-to-framework binding

Cross-cutting frameworks every skill can pull from:

- **Signal Theory** (`reference/canonical/frameworks/signal-theory/`) — applies to every skill's output verification
- **Primitives** (`reference/frameworks/primitives/`) — Unique Mechanism, Value Equation, Core Four, Call Funnel, Educate-before-pitch, Specificity
- **Cult Methodology** (`reference/canonical/frameworks/cult-methodology/`) — authority and community-building patterns
- **Esoteric Marketing** (`reference/frameworks/esoteric-marketing/`) — emotional marketing, low-ticket ascension, 40/40/20
- **Growth Operating Process** (`reference/frameworks/growth-operating-process/`) — the straight operating process for ops
- **Instagram Profile Funnel** (`reference/frameworks/instagram-profile-funnel/`) — the IG ecosystem stack
- **YouTube** (`reference/frameworks/youtube/`) — hook library, VSSL structures, title/thumbnail patterns, algorithm logic

## Execution order

**Cycle 1 — Foundations:** `/research` → `/build-icp` → `/build-positioning` → `/design-offer` → `/extract-voice`

**Cycle 2 — First external assets:** `/build-vsl` → `/build-funnel` → `/landing-page` → `/ad-creative` → `/content-calendar` → `/write-linkedin-post`

**Cycle 3 — Nurture and sales:** `/lead-magnet` → `/email-sequence` → `/webinar-script` → `/post-booking-nurture` → `/story-sequence` → `/application-form` → `/objection-library` → `/sales-script` → `/call-prep` → `/proposal`

**Cycle 4 — Ascension + launch + scale:** `/tripwire-design` → `/plan-launch` → `/launch-report` → `/build-sop` → `/hiring-brief` → `/retention-check` → `/case-study`

**Cycle 5 — Partnerships + competitive:** `/jv-webinar-proposal` → `/affiliate-program` → `/referral-program` → `/competitor-intel` → `/revenue-report`

## Roadmap

Future skills that may ship in v1.1 or v2.0 when real operations demand them. None are scaffolded yet.

- `offer-repositioning` — reshape an existing offer for a new ICP or maturity stage
- `name-mechanism` — name the unique mechanism using proven patterns
- `financial-model` — LTV:CAC model + revenue reverse-engineering
- `content-pillars` — strategic content pillars that bridge to the offer
- `vssl-construction` — YouTube-native VSSL body (5-chapter)
- `ig-profile-funnel` — IG profile-as-landing-page
- `hook-generator` — 10-20 hook variants from the formula library
- `repurpose` — one asset into 10 derivative assets
- `challenge-script` — 3 / 5 / 7-day challenge (split from webinar-script)
- `sms-sequence` — SMS nurture sequence
- `community-content` — community engagement calendar + ritual frameworks
- `dm-sequence` — DM outreach sequence
- `guarantee-copy` — risk-reversal guarantee language
- `legal-templates` — signed agreement + contract templates (complements `/proposal`)

Skills are added when operations ask for them, not to hit a target count.

---

*v1.1.0 — 2026-04-21. Shipped skill catalog expanded to 36 (added 7 P0 sales-path skills: sales-script, objection-library, call-prep, proposal, application-form, tripwire-design, landing-page). Skill enrichment is ongoing via per-skill examples and evidence runs.*
