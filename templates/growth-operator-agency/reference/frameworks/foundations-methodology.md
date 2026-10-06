# FOUNDATIONS Build Plan — Canonical Methodology

> Imported from Growth Operating Agency predecessor project 2026-04-19. Growth Operating Agency Audience + Offer departments reference this as the FOUNDATIONS methodology source-of-truth.

---

# Foundations department — Focused Build Plan

> Build one really good set of Foundation agents. Not 200 files. The right files,
> properly mapped, with real methodology and real examples.

---

## What We're Building

3 agents that produce 5 document types:

```
Foundations (parent orchestrator)
├── Market Research & ICP (sub-agent)
│   ├── Produces: Market Research Brief
│   └── Produces: ICP Document
└── Offer Architecture (sub-agent)
    ├── Produces: Positioning Document
    ├── Produces: Offer Document
    └── Produces: Offer Repositioning Document
```

**That's it.** These 3 agents + 5 outputs are the foundation everything else depends on.

---

## What Already Exists (Don't Rebuild)

You already have most of this in Notion. The job is to **convert and sharpen**, not start from scratch.

### Agent Definitions (from your "1. FOUNDATIONS (PLAN)" Notion page):
| File | Words | Status |
|------|-------|--------|
| `foundations/AGENT.md` | 1,131 | Complete — parent orchestrator with delegation logic |
| `foundations/KNOWLEDGE.md` | 2,652 | Complete — 8 domain frameworks (Impact Distribution, Awareness Spectrum, Market Maturity, Limiting Belief Triad, Belief Depth, Market Hierarchy, Transformation Principle, Sequential Dependency) |
| `market-research-icp/AGENT.md` | 1,198 | Complete |
| `market-research-icp/FRAMEWORKS.md` | 1,865 | Complete |
| `market-research-icp/KNOWLEDGE.md` | 1,527 | Complete |
| `offer-architecture/AGENT.md` | 1,200 | Complete |
| `offer-architecture/FRAMEWORKS.md` | 2,714 | Complete |
| `offer-architecture/KNOWLEDGE.md` | 2,091 | Complete |

### Golden Examples (from your Notion — these are YOUR real deliverables):
| Document Type | Example | Location |
|---|---|---|
| ICP Document | Agency ICP — full Worthless/Helpless/Hopeless framework | Notion: `41539dd8...` |
| ICP Document | the HNW-investing coach "Customer Bubble" — 5-component closer study guide | Notion: `5e039dd8...` |
| ICP Document | the  client Multi-Segment — 8 segments, JSON structure, LTV estimates | Notion: `30539dd8...` |
| Market Research | Agency 30-section deep dive — competitive positioning, 5 moats, 10-year timeline | Notion: `de639dd8...` |
| Offer Document | Agency 3-tier ($5.8K/$10.8K/$24.8K) — full value stack + timelines | Notion: `54139dd8...` |
| Positioning Doc |  client Framework — 8-section BCG-style positioning | Notion: `30539dd8...` |
| Competitor Analysis | a concierge growth shop — 5 competitors with SWOT | Notion: `30539dd8...` |
| Competitor Analysis | an AI-video creator tool — 5 competitors with action plan | Notion: `30539dd8...` |

### Offer Architecture Prompts (from your Claude VSL Prompt Vault):
- **AI Offer Architecture Builder** — 2-part prompt sequence (Research Brief → Offer Design) with The Value Equation, "Stupid To Say No" Test, Four-Stage Architecture, 6-section output | Notion: `8a839dd8...`

---

## What Needs to Be Built

### Step 1: Convert Agent Definitions to the workspace manifest Format

Take your existing 8 Notion files and convert them to the workspace manifest's workspace structure:

```
growth-os-foundations/
├── SYSTEM.md                              ← NEW: Entry point
├── company.yaml                           ← NEW: User business context
│
├── agents/
│   └── foundations/
│       ├── foundations.md                  ← CONVERT from Notion AGENT.md
│       ├── market-research-icp.md         ← CONVERT from Notion AGENT.md
│       └── offer-architecture.md          ← CONVERT from Notion AGENT.md
│
├── skills/
│   ├── research/SKILL.md                  ← NEW: /research skill
│   ├── build-icp/SKILL.md                 ← NEW: /build-icp skill
│   ├── design-offer/SKILL.md              ← NEW: /design-offer skill
│   └── analyze-competitor/SKILL.md        ← NEW: /analyze-competitor skill
│
├── reference/
│   ├── frameworks/
│   │   ├── impact-distribution.md         ← EXTRACT from Notion KNOWLEDGE.md
│   │   ├── awareness-spectrum.md          ← EXTRACT from Notion KNOWLEDGE.md
│   │   ├── market-maturity.md             ← EXTRACT from Notion KNOWLEDGE.md
│   │   ├── limiting-belief-triad.md       ← EXTRACT from Notion KNOWLEDGE.md
│   │   ├── belief-depth-model.md          ← EXTRACT from Notion KNOWLEDGE.md
│   │   ├── market-hierarchy.md            ← EXTRACT from Notion KNOWLEDGE.md
│   │   ├── transformation-principle.md    ← EXTRACT from Notion KNOWLEDGE.md
│   │   ├── sequential-dependency.md       ← EXTRACT from Notion KNOWLEDGE.md
│   │   ├── offer-value-equation.md        ← EXTRACT from Notion Offer Builder
│   │   └── market-research-method.md      ← NEW: Research methodology
│   │
│   ├── templates/
│   │   ├── market-research-brief.md       ← NEW: Output template
│   │   ├── icp-document.md                ← NEW: Output template
│   │   ├── positioning-document.md        ← NEW: Output template
│   │   ├── offer-document.md              ← NEW: Output template
│   │   └── competitor-battlecard.md       ← NEW: Output template
│   │
│   ├── examples/
│   │   ├── icp-agency.md      ← COPY from Notion (your real work)
│   │   ├── icp-drysdale-bubble.md         ← COPY from Notion (your real work)
│   │   ├── market-research-aa.md          ← COPY from Notion (your real work)
│   │   ├── offer-agency.md    ← COPY from Notion (your real work)
│   │   └── positioning-hnwi-client.md      ← COPY from Notion (your real work)
│   │
│   ├── data-sources/
│   │   └── research-sources.md            ← NEW: Data source registry
│   │
│   ├── swipe-file/
│   │   └── sources-registry.md            ← NEW: Where to find proven examples
│   │
│   ├── icp.md                             ← GENERATED: Built by ICP agent for user
│   ├── offers.md                          ← GENERATED: Built by Offer agent for user
│   └── brand-voice.md                     ← GENERATED: Built by Voice agent for user
│
└── spec/
    └── WORKFLOW.md                        ← NEW: Onboarding FSM

Total: ~30 files. 8 converted, 5 copied, ~17 new.
```

---

### Step 2: Build the Market Research Brief Template

This is the most important template in the entire system. Based on all research:

**The Market Research Brief must produce:**

```
MARKET RESEARCH BRIEF
├── 1. Executive Summary (1 page)
│   └── Go/No-Go recommendation with viability score (0-100)
│
├── 2. Market Definition & Sizing
│   ├── TAM / SAM / SOM with methodology
│   ├── Market growth rate (CAGR)
│   └── Market maturity stage (Naive → Aware → Skeptical → Exhausted)
│
├── 3. Demand Signals (What's WORKING)
│   ├── Search demand (Google Trends velocity — growing/stable/declining)
│   ├── Content demand (YouTube views, podcast downloads in this niche)
│   ├── Purchase signals (Amazon BSR, Udemy enrollment, paid communities)
│   ├── Ad investment signals (competitors running ads 30+ days = proven market)
│   └── Community signals (Reddit activity, Facebook group engagement)
│
├── 4. Pain Signals (What's NOT WORKING)
│   ├── Competitor 1-star reviews (what buyers hate about existing solutions)
│   ├── Reddit complaints (unfiltered pain language)
│   ├── YouTube comments (what viewers wish existed)
│   ├── Feature gaps (what no one is doing well)
│   └── Broken promises (what competitors overpromise and underdeliver)
│
├── 5. Competitive Landscape
│   ├── Direct competitors (3-5) with: positioning, pricing, strengths, weaknesses
│   ├── Indirect competitors (2-3)
│   ├── Positioning map (2x2 diagram)
│   ├── Feature comparison matrix
│   └── What competitors' customers wish existed (from reviews)
│
├── 6. Voice of Customer (Exact Language)
│   ├── How they describe their problem (verbatim phrases from Reddit/reviews)
│   ├── How they describe their desired outcome
│   ├── What they've tried before and why it failed
│   ├── What words trigger them (emotional language)
│   └── What objections they raise (from review/forum analysis)
│
├── 7. Audience Intelligence
│   ├── Where they spend time online (subreddits, YouTube channels, podcasts)
│   ├── Who they follow and trust
│   ├── What content formats they consume
│   └── What they're willing to pay (evidence-based, not assumed)
│
├── 8. Opportunity Assessment
│   ├── Viability score (0-100) with scoring methodology shown
│   ├── Top 3 opportunity gaps (what the market wants that nobody delivers well)
│   ├── Recommended positioning angle
│   ├── Risk flags (overcrowded, declining demand, regulatory, etc.)
│   └── Go/No-Go recommendation with reasoning
│
└── 9. Methodology & Sources
    ├── Data sources used (with dates)
    ├── Tools used
    └── Known limitations
```

**Data sources the agent should pull from (prioritized):**

| Priority | Source | Signal Type | Access Method |
|---|---|---|---|
| 1 | Google Trends | Demand velocity | Google Trends MCP / API |
| 2 | Reddit | Pain language, unfiltered truth | Reddit Research MCP |
| 3 | YouTube | Content demand, comment sentiment | YouTube Data API |
| 4 | Meta Ad Library | Competitor investment, proven angles | Meta Ad Library (free) |
| 5 | Amazon/G2 reviews | Purchase-linked pain, competitor gaps | Apify scrapers |
| 6 | Google Autocomplete/PAA | Exact buyer vocabulary | SerpApi / manual |
| 7 | SEMrush/Ahrefs | Keyword demand, competitive gaps | API (paid) |
| 8 | SparkToro | Where audience spends time | SparkToro API |
| 9 | Perplexity | Rapid synthesis from live web | Perplexity API |
| 10 | Job boards | Where companies invest | LinkedIn/Indeed |
| 11 | Udemy/Skillshare | Education market validation | Apify scrapers |
| 12 | Skool/Circle | Community-format market validation | Manual/discovery pages |

**The Cross-Validation Rule:**
A finding is only a "signal" if it appears in **3+ independent sources**.
A finding in only 1 source is noise until corroborated.

**The Evidence Hierarchy (for weighting findings):**
1. Someone PAID money (purchase, enrollment, paid subscription) — strongest
2. Company SPENT money (running ads 30+ days, hiring for role) — strong
3. Someone SAID IT unprompted (Reddit post, 1-star review) — good
4. Someone SEARCHED for it (Google Trends, autocomplete) — good
5. Someone ENGAGED with it (upvote, share, save) — moderate
6. Someone SAID IT in a survey (lowest — they say what you want to hear)

---

### Step 3: Build the ICP Document Template

Based on your best existing examples (Agency + the HNW-investing coach Customer Bubble):

```
ICP DOCUMENT
├── 1. Summary (2-3 sentences — loaded as L0 in company.yaml)
│
├── 2. Demographics
│   ├── Age range
│   ├── Gender distribution
│   ├── Income / revenue range
│   ├── Location / geography
│   ├── Occupation / business type
│   └── Business stage (startup, scaling, established)
│
├── 3. Psychographics
│   ├── Values and beliefs
│   ├── Identity aspirations (who they want to BECOME)
│   ├── Decision-making style
│   └── Risk tolerance
│
├── 4. Limiting Belief Diagnosis (from your Triad framework)
│   ├── Dominant pattern: Worthless / Helpless / Hopeless
│   ├── Secondary pattern (if mixed)
│   ├── Evidence for diagnosis (language patterns observed)
│   └── Implication for offer architecture
│
├── 5. Awareness Level (from your Spectrum framework)
│   ├── Current level: Unaware / Problem Aware / Solution Aware / Product Aware / Most Aware
│   ├── Evidence for assessment
│   └── Implication for messaging approach
│
├── 6. Pain Points (minimum 5, in THEIR language)
│   ├── Surface pains (what they say out loud)
│   ├── Deep pains (what they feel at 3am)
│   ├── Compounding costs (what inaction costs over 6-12 months)
│   └── Exact language (verbatim phrases from research)
│
├── 7. Desires & Dream Outcome
│   ├── Stated desires (what they say they want)
│   ├── Unstated desires (what they actually want — status, freedom, safety)
│   ├── Dream outcome in one sentence
│   └── Transformation type: Status / Capability / Safety
│
├── 8. What They've Tried & Why It Failed
│   ├── Previous solutions attempted
│   ├── Why each failed (from their perspective)
│   ├── Money already spent trying to solve this
│   └── Trust damage from past failures
│
├── 9. Objections (top 5 with what's underneath)
│   ├── Surface objection → Real objection → Response framework
│   Example: "It's too expensive" → "I'm not sure this will work for me" → Show case study matching their situation
│
├── 10. Buying Intelligence
│   ├── Where they research solutions
│   ├── Who they trust for recommendations
│   ├── What triggers purchase consideration (life events, pain thresholds)
│   ├── Decision timeline (impulse vs. considered)
│   └── Who else is involved in the decision
│
├── 11. Information Diet
│   ├── Podcasts they listen to
│   ├── YouTube channels they watch
│   ├── Books/newsletters they read
│   ├── Communities they participate in (Reddit, Facebook, Skool)
│   └── Influencers they follow
│
├── 12. Exact Language Patterns (minimum 20 phrases)
│   ├── How they describe their problem
│   ├── How they describe their desired outcome
│   ├── Emotional trigger words
│   └── Phrases that indicate readiness to buy
│
└── 13. Completeness Score
    ├── Demographics: /10
    ├── Psychographics: /20
    ├── Pain Points: /20
    ├── Objections: /15
    ├── Buying Triggers: /15
    ├── Awareness Level: /10
    ├── Language Patterns: /10
    └── TOTAL: /100 (must be >= 80 before downstream agents use this)
```

---

### Step 4: Build the Offer Document Template

Based on your existing Offer Architecture Builder + Agency 3-tier offer:

```
OFFER DOCUMENT
├── 1. Transformation Statement
│   └── "Go from [current state] to [desired state] in [timeframe]"
│
├── 2. Unique Mechanism
│   ├── Name (branded)
│   ├── What it is (1 paragraph)
│   ├── Why it's different from everything else
│   └── Why it works (the logic)
│
├── 3. The Value Equation
│   ├── Dream Outcome: [specific, measurable]
│   ├── Perceived Likelihood: [what proof exists]
│   ├── Time Delay: [how fast to results]
│   ├── Effort Required: [what they have to do]
│   └── Score: (Outcome × Likelihood) ÷ (Time × Effort)
│
├── 4. Offer Tiers (1-3 tiers)
│   For each tier:
│   ├── Tier name
│   ├── Delivery model (DIY / DWY / DFY)
│   ├── Duration
│   ├── Core deliverables (outcome-framed, not feature-listed)
│   ├── Price + price anchor
│   └── Timeline to results
│
├── 5. Bonus Stack (3-5 bonuses)
│   For each:
│   ├── Name
│   ├── What problem it solves (different from core)
│   ├── Perceived value (defensible)
│   └── Why it's included
│
├── 6. Guarantee Design
│   ├── Type: performance / ROI / completion / reversal
│   ├── Statement: "If [specific result] doesn't happen in [timeframe], we [remedy]"
│   ├── Conditions (if any)
│   └── Why you can offer this
│
├── 7. Pricing Rationale (3 frames)
│   ├── Cost of inaction ($/month and $/year of NOT buying)
│   ├── Comparison stack (what each piece costs separately)
│   └── ROI timeline (when investment pays for itself)
│
├── 8. Urgency Element
│   ├── Mechanism: capacity / seasonal / price / bonus expiration / market timing
│   ├── Why it's real (not manufactured)
│   └── Exact language for sales assets
│
├── 9. Belief Stack (3-5 beliefs the prospect must hold to buy)
│   For each:
│   ├── The belief
│   ├── Current state (do they already believe this?)
│   ├── How to install it (content, proof, story)
│   └── Which belief depth layer (Surface / Behavior / Identity / Destiny)
│
├── 10. Objection Handling (top 4)
│   ├── "Too expensive" → [reframe]
│   ├── "Will this work for me?" → [proof]
│   ├── "Need to think about it" → [reframe]
│   └── "Been burned before" → [acknowledge + differentiate]
│
├── 11. Economics Validation
│   ├── Target LTV
│   ├── Target CAC
│   ├── LTV:CAC ratio (must be >= 3:1)
│   ├── Break-even point
│   └── Margin analysis
│
└── 12. Offer One-Pager (summary for all downstream agents)
    ├── Who it's for (1 sentence)
    ├── What they get (1 sentence)
    ├── The mechanism (1 sentence)
    ├── The price (range)
    ├── The guarantee (1 sentence)
    └── The CTA (what action to take)
```

---

### Step 5: Build the Research Data Source Registry

This file tells the Market Research agent WHERE to look:

```markdown
# Data Source Registry

## Tier 1: Always Check (Free, High Signal)
- Google Trends → demand velocity
- Reddit (via MCP) → pain language, unfiltered truth
- Google Autocomplete / PAA → buyer vocabulary
- Meta Ad Library → competitor investment proof
- YouTube search + comments → content demand + sentiment

## Tier 2: Check When Available (Free or Low Cost)
- Amazon/Goodreads reviews → purchase-linked pain
- G2/Capterra/Trustpilot → B2B competitor gaps
- Skool/Circle discovery → community market validation
- Udemy/Skillshare → education demand validation
- Job boards (LinkedIn/Indeed) → company investment signals

## Tier 3: Deep Dive (Paid Tools)
- SEMrush/Ahrefs → keyword demand + competitive gaps
- SparkToro → audience media habits
- SimilarWeb → competitor traffic share
- Exploding Topics → early trend detection (6mo ahead)
- Glimpse → absolute search volume on Google Trends

## MCP Servers to Wire In
- reddit-research-mcp (semantic search, 20K subreddits)
- google-trends-mcp-server (opportunity discovery)
- Apify MCP (10K+ scrapers for any platform)
- Firecrawl MCP (any URL → clean markdown)

## Swipe File Sources (for examples + calibration)
- SwipeFile.com → 2,908 copy examples, subject lines with open rates
- Swiped.co → VSL scripts, classic direct response archive, psychological breakdowns
- EmailDrips.com → 120+ complete email sequences
- Really Good Emails → 10,000+ emails
- Milled.com → 38M emails from 98K brands
- Meta Ad Library → competitor ad creatives (free)
- Foreplay.co → 100K+ human-curated ad creatives (paid)
```

---

### Step 6: Build the Onboarding FSM

```markdown
# spec/WORKFLOW.md — Foundation Onboarding

## States

### :start
  trigger: Event.eq(:type, :new_user)
  pipeline:
    - LoadContext → %{existing_context}
    - Branch.on(:existing_context.completeness)
        empty → FSM.transition(:market_research)
        has_audience → FSM.transition(:build_icp)
        has_icp → FSM.transition(:build_offer)
        has_offer → FSM.transition(:foundations_complete)

### :market_research
  owner: market-research-icp
  pipeline:
    - Research.invoke(%{niche: $user.niche, depth: :standard}) → %{brief}
    - QualityGate(%{brief, threshold: 0.5}) → %{passed}
    - Branch.on(:passed)
        true → WriteContext("reference/market-research.md", $brief)
               FSM.transition(:build_icp)
        false → Revise and retry (max 2)
  timeout: 24h

### :build_icp
  owner: market-research-icp
  requires: market_research_brief exists
  pipeline:
    - ICPBuilder.invoke(%{research: $brief, user_input: $user}) → %{icp}
    - CompletenessScore(%{icp}) → %{score}
    - Branch.on(:score >= 80)
        true → WriteContext("reference/icp.md", $icp)
               UpdateCompanyYaml("icp.summary", $icp.summary)
               FSM.transition(:build_positioning)
        false → AskUser("ICP needs more detail on: [missing sections]")
  timeout: 24h

### :build_positioning
  owner: offer-architecture
  requires: icp exists
  pipeline:
    - Positioning.invoke(%{icp: $icp, research: $brief}) → %{positioning}
    - QualityGate(%{positioning, threshold: 0.5})
    - WriteContext("reference/positioning.md", $positioning)
    - FSM.transition(:build_offer)

### :build_offer
  owner: offer-architecture
  requires: positioning exists
  pipeline:
    - OfferArchitect.invoke(%{icp: $icp, positioning: $positioning}) → %{offer}
    - EconomicsValidation(%{offer}) → %{ltv_cac_ratio}
    - Branch.on(:ltv_cac_ratio >= 3.0)
        true → WriteContext("reference/offers.md", $offer)
               UpdateCompanyYaml("offer.summary", $offer.one_pager)
               FSM.transition(:foundations_complete)
        false → FlagUser("Economics don't work: LTV:CAC = {ratio}. Revise pricing or targeting.")

### :foundations_complete
  trigger: auto
  pipeline:
    - NotifyUser("Foundations complete. Your ICP, positioning, and offer are locked in.")
    - Signal.emit(:foundations_complete)
    ## All other agents can now operate
```

---

## Build Order (What to Do in What Sequence)

### Week 1: Convert & Structure
```
Day 1-2: Create workspace structure (directories, SYSTEM.md, company.yaml)
Day 3-4: Convert 3 agent definitions from Notion → the workspace manifest format
Day 5:   Extract 8 frameworks from KNOWLEDGE.md → individual reference files
```

### Week 2: Templates & Examples
```
Day 1-2: Build Market Research Brief template
Day 3:   Build ICP Document template
Day 4:   Build Offer Document template + Positioning template
Day 5:   Copy 5 golden examples from Notion into reference/examples/
```

### Week 3: Skills & Wiring
```
Day 1-2: Write SKILL.md files (/research, /build-icp, /design-offer, /analyze-competitor)
Day 3:   Build data source registry + swipe file sources registry
Day 4:   Write spec/WORKFLOW.md (onboarding FSM)
Day 5:   End-to-end test: one user goes through full onboarding flow
```

### Week 4: Sharpen
```
Day 1-3: Run through 3 different user scenarios (coach, agency, info product)
Day 4:   Fix quality issues, sharpen templates based on real output
Day 5:   Lock foundations, begin Phase 2 (VSL + Sales stack)
```

---

## What to Give Your CTO

**Tell them:**
- 30 files total, not 200
- 8 already exist in Notion (convert, don't rewrite)
- 5 golden examples are your own real client work (copy from Notion)
- ~17 new files to create (templates, skills, wiring)
- 4-week build to a working Foundation that produces real output
- The agent structure (parent + 2 sub-agents) is already designed and tested in your Notion

**The technical decisions they need to make:**

1. **Runtime:** slash-command runtime terminal? Custom app via API? Both?
2. **Context Engine:** Does `company.yaml` + `reference/*.md` files suffice, or do you need a database-backed context store?
3. **Sub-agent delegation:** Single agent that loads different KNOWLEDGE.md per task (simpler), or actual multi-agent delegation via filesystem (architecturally correct)?
4. **MCP servers:** Which ones to wire in from day 1? (I recommend: Reddit Research MCP + Google Trends MCP + Firecrawl MCP as minimum)
5. **Quality gate implementation:** Signal Theory triple-layer verification as a separate validation step, or inline within each agent's output generation?

---

## Success Criteria

The Foundations are DONE when:

1. A new user can describe their business in plain language
2. The system produces a Market Research Brief with real data and viability score
3. The system produces an ICP Document scoring >= 80/100 completeness
4. The system produces an Offer Document with economics validation (LTV:CAC >= 3:1)
5. All outputs reference the user's specific business context (not generic)
6. All outputs use the user's audience's actual language (from research)
7. The ICP and Offer are written to `reference/knowledge/foundations.md` and `reference/knowledge/foundations.md`
8. Every downstream agent can load these files and produce calibrated output

**If the Foundation outputs are wrong, every VSL, email, funnel, and ad built on top of them will be wrong.** This is why we build one thing really well before building anything else.
