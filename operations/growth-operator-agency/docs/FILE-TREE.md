# Growth Operator Agency — File Tree

> The map. Every line answers *"what is this FOR me?"*

---

## The 5 files at the root — this is the OS

```
growth-operating-agency/
│
├── README.md            → the pitch: what this system builds for you, week by week
├── SYSTEM.md            → the brain boot file — makes any AI into a growth operator on read
├── INVARIANTS.md        → 28 sacred rules every AI must follow (14 NEVERs + 14 ALWAYSes)
├── ENCODING.md          → the 11-part schema that captures your business in one file
├── company.yaml         → YOUR business (ICP · offer · voice · budgets · integrations)
│                          Fill this once. All 36 skills read from it.
└── LICENSE              → MIT. Free forever.
```

**Why these 5 matter:** `SYSTEM.md` makes a generic AI (Claude, ChatGPT, Cursor) become *your* growth operator on first read. `INVARIANTS.md` keeps it from drifting into generic AI slop. `company.yaml` is the one file you touch — it encodes your business so every skill output sounds like YOU.

---

## `agents/` — 41 AI specialists, org-charted like a real company

```
agents/
│
│  LEADERSHIP
├── growth-ceo               → top orchestrator. Every request routes through here.
│
│  DEPARTMENT HEADS (7)
├── foundations-head         → research · ICP · positioning · offer · brand voice
├── marketing-head           → content · paid ads · organic distribution · SEO
├── nurture-head             → email · webinar · lead magnet · community
├── sales-head               → VSL · funnel · scripts · landing pages · DM
├── launch-head              → launches + post-launch analysis
├── scale-head               → SOPs · hiring · retention · case studies · finance
├── partnerships-head        → JV · affiliate · influencer · referral
│
│  FOUNDATIONS SPECIALISTS (4)
├── researcher               → Tier-1/2/3 source pulls · VOC mining · viability scoring
├── icp-builder              → 13-section ICP with 100-point scoring rubric
├── niche-architect          → positioning · category design · mechanism naming
├── offer-architect          → value stack · guarantee · 3:1 LTV:CAC economics
├── brand-voice              → phrase mining · in-voice rewrite · tone calibration
│
│  MARKETING SPECIALISTS (7)
├── content-strategist       → 30-day calendar · 4-pillar ratio · platform allocation
├── youtube-producer         → long-form scripts (7 types incl. hidden-pitch VSSL)
├── short-form               → reels · TikToks · Shorts (10 frameworks)
├── stories-producer         → 7-day Instagram Story sequences (8 archetypes)
├── twitter-writer           → X threads · single tweets (7 thread types)
├── linkedin-writer          → offer-promoting posts (PIER · Hook-Loop-CTA)
├── paid-ads                 → 8 ad types × angles · hooks · compliance
│
│  NURTURE SPECIALISTS (4)
├── email-copywriter         → 8 sequence types · subject-line banks · deliverability
├── lead-magnet-designer     → 9 magnet types · opt-in copy · delivery stack
├── webinar-producer         → 6 formats · workshop · challenge · evergreen
├── show-rate-ops            → confirmation page · email · SMS · phone triage
│
│  SALES SPECIALISTS (6)
├── vsl-builder              → 5 VSL frameworks · 8 required beliefs · hook grid
├── vsl-writer               → script-level prose · mechanism reveal · close variants
├── funnel-architect         → 15 funnel archetypes · page-stack design
├── sales-scripter           → 8-stage discovery → pitch → close
├── sales-ops                → CRM hygiene · pipeline stages · SLA enforcement
│
│  LAUNCH SPECIALISTS (2)
├── launch-manager           → 5 launch types × 5-phase SOP
├── post-launch-analyst      → revenue · conversion · bottleneck diagnosis
│
│  SCALE SPECIALISTS (6)
├── sop-builder              → 14 SOP templates (8 role + 6 process)
├── talent-recruiter         → hiring briefs · scorecards (8 roles)
├── competitor-analyst       → ongoing competitor monitoring · battlecards
├── financial-modeler        → P&L · forecasting · unit economics
├── revenue-analyst          → revenue reporting · cohort LTV · retention
├── client-success           → health scoring · churn flags · renewal ops
├── case-study-producer      → testimonial → case study conversion
│
│  PARTNERSHIPS SPECIALISTS (3)
├── jv-outreach              → JV webinar pitches · partner qualification
├── affiliate-architect      → affiliate program design · payout structure
└── referral-designer        → referral loops · incentive math
```

**Why agents are thin:** every agent is ~150 lines. Identity + mission + rules + skill list. The *intelligence* lives in `skills/` and `reference/`. Swap a runtime (Claude → Cursor → ChatGPT) — the agents don't change. The runtime reads the same files.

---

## `skills/` — 36 capabilities. Each produces ONE specific business asset.

```
skills/
│
│  FOUNDATIONS (5) — figure out who you're selling to and what
├── /research                → Market Research Brief (9 sections, Go/No-Go recommendation)
│                              65+ real web searches · Tier-1/2/3 sources · VOC verbatim
├── /build-icp               → 13-section Ideal Customer Profile
│                              psychographics · awareness level · belief stack · scoring
├── /build-positioning       → Positioning Document
│                              category · mechanism · big idea · narrative arc
├── /design-offer            → Offer Document
│                              value stack · bonuses · guarantee · 3:1 LTV:CAC economics
├── /extract-voice           → Brand Voice Architecture
│                              phrases to use + phrases to avoid · tone rubric · rewrite tests
│
│  MARKETING (7) — show up on every channel that matters
├── /content-calendar        → 30-day content plan (4-pillar ratio across platforms)
├── /ad-creative             → Paid-ad brief (8 ad types × multiple variants)
├── /write-linkedin-post     → offer-promoting LinkedIn post (PIER / Hook-Loop-CTA)
├── /write-reel              → short-form script (10 frameworks)
├── /write-youtube           → long-form video script (7 video types incl. hidden-pitch VSSL)
├── /write-x-thread          → X thread (7 thread types)
├── /story-sequence          → 7-day Instagram Story sequence
│
│  NURTURE (4) — turn cold viewers into warm buyers
├── /lead-magnet             → Lead magnet design + copy (9 types)
├── /email-sequence          → Email sequence (8 types incl. launch · re-engage · post-purchase)
├── /webinar-script          → Webinar or challenge script (6 formats incl. workshop)
├── /post-booking-nurture    → Show-rate stack (confirmation page + email + SMS + phone triage)
│
│  SALES (10) — close without chasing
├── /build-vsl               → Full VSL Script (5 framework variants, all 8 required beliefs)
├── /build-funnel            → Funnel Architecture (15 archetypes)
├── /sales-script            → 8-stage discovery → pitch → close script
├── /objection-library       → 20+ objections × 3-layer reframes × proof × escalation
├── /call-prep               → 15-min routine producing a 1-page pre-call brief
├── /proposal                → 1-page post-call proposal ($3K–$50K engagements)
├── /application-form        → qualifying application (3 archetypes) with DQ logic
├── /tripwire-design         → $7–$97 entry offer (7 archetypes + ascension math)
├── /landing-page            → 4-page stack (opt-in / offer / thank-you / checkout, 4 variants each)
├── /competitor-intel        → competitor teardown + positioning-gap analysis
│
│  LAUNCH (2) — time-boxed revenue bursts
├── /plan-launch             → Launch plan (5 types × 5-phase SOP)
├── /launch-report           → Post-launch analysis + recommendations for next cycle
│
│  SCALE (5) — build the team and retain the base
├── /build-sop               → Team SOP (14 role variants)
├── /hiring-brief            → Hiring brief + scorecard (8 roles)
├── /retention-check         → Client health score + churn flags before they fire
├── /case-study              → Testimonial → case-study conversion
├── /revenue-report          → P&L + forecasting + unit economics
│
│  PARTNERSHIPS (3) — grow via other people's audiences
├── /jv-webinar-proposal     → JV webinar partnership pitch
├── /affiliate-program       → Affiliate program design
└── /referral-program        → Referral program design
```

**What's inside one skill folder (same pattern for all 36):**

```
skills/sales/build-vsl/
├── SKILL.md                 → the decision logic (timeless)
├── reference/               → structured knowledge pack (durable)
│   ├── pull-push-persuade.md
│   ├── vsl-archetypes.md    (7 frameworks)
│   ├── hook-database.md     (12 hook types + examples)
│   ├── objection-map.md     (objection → VSL-timing pairs)
│   └── proof-stack.md       (authority → social → testimonial → case study ordering)
├── examples/                → 3-10 golden outputs (quality calibration)
├── evidence/                → blind-output-test · failure modes (Shannon · Ashby · Beer · Wiener)
└── adapters/                → 5-25 line runtime shims
    ├── claude-code.md       → for Claude Code
    ├── cursor.md            → for Cursor
    ├── canopy.yaml          → for Canopy runtime
    ├── paperclip.json       → for Paperclip runtime
    └── http.openapi.yaml    → for any HTTP orchestrator
```

The skill is portable. Swap runtimes — only the `adapters/` change. Decision logic stays.

---

## The supporting scaffolding

*The top half (root · agents · skills) is what ships the work. The folders below are what makes the work SMART — the knowledge base, the quality gates, the org operating cadences.*

<details>
<summary><strong><code>reference/</code> — the brain that makes all 36 skills smart</strong></summary>

<br/>

```
reference/
│
├── frameworks/          → 99+ methodology docs, 12 sub-folders
│   ├── primitives/           → awareness spectrum · impact distribution · limiting-belief triad ·
│   │                           market hierarchy · market maturity · the influence canon · value equation
│   ├── offer-architecture/   → offer system · value stack · mechanism design · risk reversal
│   ├── esoteric-marketing/   → esoteric speech-act methodology · engineered dissonance · market psychology
│   ├── esoteric-offer-architecture/
│   │                        → esoteric-school of offer building (ritual · initiation · revelation)
│   ├── vsl/                  → pull-push-persuade · 15-step · 11-belief · hidden-pitch VSSL
│   ├── vsl-director/         → directing choices: hook-stacking · mechanism reveal · close variants
│   ├── sales/                → 8-stage discovery · objection handling · follow-up sequences
│   ├── growth-operating-process/
│   │                        → 60/40 rule · 40/40/20 impact · sequential dependency
│   ├── instagram-profile-funnel/
│   │                        → the IG-DM-funnel methodology · bio stack · DM conversation → call
│   ├── content-os/           → 1→20 repurposing · pillar ratios · platform algorithms
│   ├── youtube/              → 7 video types · algorithm signals · thumbnail-title testing
│   ├── backend-economics/    → LTV · CAC · payback · client-financed acquisition
│   └── acquisition-economics/
│                            → paid-org blend · 60/30/10 revenue mix · unit econ thresholds
│
├── operators/           → 18 archetyped operator playbooks (methodology-named, no individuals)
│                          esoteric-marketing · narrative-VSL · funnel-platform · awareness-spectrum ·
│                          direct-mail · acquisition-economics · IG-DM-funnel · agency-direction ·
│                          pull-push-persuade · 3X-conversion · mechanism-VSL · direct-response ·
│                          influence-canon · cognitive-bias
│
├── platforms/           → 6 platform playbooks
│                          LinkedIn · Instagram · TikTok · X · Meta Ads · YouTube
│
├── swipe-file/          → proven assets registry
│                          170+ hooks · 20+ LinkedIn posts · 15+ X threads · 10+ VSL openers ·
│                          email drip banks · DM swipes · case-study copy patterns
│
├── templates/           → 20 instantiable document structures
│                          ICP · offer · positioning · VSL (5 types) · sales page · email
│                          sequence · hiring brief · SOP · proposal · launch plan · case study
│
├── verticals/           → 11 vertical packs (swap-in business contexts)
│                          fitness · B2B SaaS · ecom · health · mindset/coaching · career ·
│                          real estate · finance · parenting · education · creator economy
│
├── legal-templates/     → 11 starter legal docs
│                          privacy policy · terms of service · client services agreement · NDA ·
│                          contractor agreement · affiliate agreement · refund policy · DMCA ·
│                          GDPR addendum · launch disclaimer · testimonial release
│
├── playbooks/           → worked case-studies at scale
│                          mentorship-funnel-$97k/mo · outreach-OS-$200k/mo · Paolo 5000-call archetype
│
├── examples/            → golden outputs (quality calibration targets per skill)
│                          pre-filled ICPs · offers · VSLs · launch reports — used as quality anchors
│
├── knowledge/           → per-department shared knowledge (what the department "just knows")
│                          foundations.md · marketing.md · nurture.md · sales.md · launch.md ·
│                          scale.md · partnerships.md
│
├── canonical/           → canonical specs + theory
│                          signal-theory · quality-triple-layer (40/35/25) · blind-output-test ·
│                          agent-architecture-bible (82KB) · banned-vocabulary provenance
│
├── competitors/         → Cook.ai / competitor teardown archive
│
├── data-sources/        → the 15 research sources with access methods
│                          Reddit · Google Trends · YouTube · Meta Ad Library · Amazon · G2 ·
│                          Exploding Topics · SparkToro · SEMrush · Perplexity · job boards ·
│                          SerpApi · Apify · Firecrawl · Skool/Circle
│
├── operator-research/   → unsorted operator intel (notes · transcripts · breakdowns)
│
└── integrations/        → per-tool how-to-use notes (GHL · ClickFunnels · ConvertKit · etc.)
```

</details>

<br/>

<details>
<summary><strong><code>workflows/</code> — how work moves across the org</strong></summary>

<br/>

```
workflows/
│
├── divisions/               → 7 pipeline FSMs
│                              foundations → marketing → nurture → sales → launch → scale → partnerships
│                              (mermaid state diagrams per division)
│
├── operations/              → team operating cadences + tool SOPs
│   ├── cadences/                 → daily standup · weekly review · monthly QBR · quarterly planning
│   ├── tool-sops/                → Slack · Notion · Loom · GoHighLevel · a productivity-software brand
│   ├── team-leadership/          → hiring · 1:1s · performance · role design
│   ├── finance-tracker/          → cash-flow schema · forecasting rhythm
│   ├── competitive-intel-ops/    → ongoing competitor monitoring
│   ├── crisis-management/        → stall · churn · legal · PR protocols
│   └── mode-of-operations/       → plan mode · execute mode · educate mode
│
├── automations/             → 5 CRM trigger playbooks
│                              lead-to-CRM · booking-to-show · purchase-to-onboarding ·
│                              churn-detection · referral-trigger
│
├── client-onboarding/       → Week-1 + 90-day onboarding SOPs
│
├── delivery/                → 4-week fulfillment SOP
│
├── handoffs/                → skill-to-skill + quality-revision handoff protocols
│                              7-block format: work · decisions · artifacts · quality · context ·
│                              dependencies · open items
│
└── execution-templates/     → 7 meeting/doc templates
                                daily standup · weekly review · QBR · post-mortem · RFC · runbook ·
                                launch debrief
```

</details>

<br/>

<details>
<summary><strong><code>prompts/</code> — 10 AI prompt libraries for fast iteration</strong></summary>

<br/>

```
prompts/
│
├── research-prompts.md         → ICP · VOC · competitor · market-sizing · objection mining
├── offer-prompts.md            → offer variants · pricing · guarantee · bonus brainstorm
├── vsl-prompts.md              → hooks · mechanism naming · stack slide · close variants
├── ad-creative-prompts.md      → hook grid · angles · headlines · UGC briefs · compliance check
├── email-prompts.md            → subject lines · cold email · launches · deliverability audit
├── content-prompts.md          → LinkedIn · X · reel · YouTube · carousel · newsletter
├── sales-prompts.md            → objection reframe · call prep · proposal · close-rate diagnostic
├── analytics-prompts.md        → metric read · funnel bottleneck · cohort LTV · churn diagnostic
├── content-repurposing-prompts.md
│                               → long-form → short-form · podcast → threads · blog → emails
└── brand-voice-prompts.md      → tone calibration · phrase mining · in-voice rewrite
```

**When to use:** prompts are the "fast lane" — copy-paste a prompt into any chat UI for a quick iteration. Skills are the "full lane" — structured walkthroughs with quality gates, saved outputs, and agent coordination.

</details>

<br/>

<details>
<summary><strong><code>spec/</code> — the quality gates (why outputs don't turn into slop)</strong></summary>

<br/>

```
spec/
│
├── BANNED-VOCABULARY.md     → 100+ corporate-speak words blocked at ship time
│                              (unlock · unleash · supercharge · game-changing · dive into ·
│                               leverage · synergy · utilize · harness · revolutionary ...)
│
├── CONTEXT-THRESHOLDS.md    → minimum company.yaml completeness per skill type
│                              can't run /build-vsl if Audience compartment < 60% ·
│                              can't run /design-offer if ICP < 70% + Offer < 30% · etc.
│
└── RUNTIMES.md              → adapter contracts per runtime
                                Claude Code · Cursor · Canopy · Paperclip · HTTP/OpenAPI
                                each skill MUST ship adapters that conform to these contracts
```

**The thesis:** quality is enforced structurally, not politely requested. A skill that fails the banned-vocab filter doesn't ship. A skill run against an underfilled `company.yaml` refuses to execute.

</details>

<br/>

<details>
<summary><strong><code>docs/</code> — guides for humans</strong></summary>

<br/>

```
docs/
│
├── QUICKSTART.md            → 30-min setup: clone · fill company.yaml · run /research
├── ARCHITECTURE.md          → how the system fits together (identity · skills · agents · invariants)
├── SKILL_AUTHORING.md       → how to add a new skill (the 3-layer pattern)
├── GLOSSARY.md              → every term in one place
├── FAQ.md                   → runtime · privacy · instantiation · quality gates
├── PROVENANCE.md            → what it rests on + methodology lineage (see PROVENANCE.md)
└── FILE-TREE.md             → this file
```

</details>

<br/>

---

## What a normie notices in 30 seconds

1. **`skills/` is 36 buttons.** Each one makes a real business document. No fluff.
2. **`agents/` is an org chart.** A CEO, 7 department heads, 33 specialists — like hiring a company for the cost of a subscription.
3. **`company.yaml`** — you fill it in once, the whole system gets smarter about YOUR business.
4. **`prompts/`** — 10 copy-pasteable AI prompt packs if you want to move faster without the full skills.
5. **`reference/`** — 170+ hooks, 20+ templates, 11 legal docs, 11 vertical packs, 18 operator playbooks. The stuff most businesses pay $10K+ for — encoded, and yours.
6. **`workflows/`** — how the business actually RUNS (daily standups, QBRs, onboarding, automations).

The mental shift: this isn't a document folder. It's **a high-ticket coaching business compressed into a repo**. Plug a runtime in, fill `company.yaml`, and the 36 buttons produce work.

---

*Growth Operator Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
