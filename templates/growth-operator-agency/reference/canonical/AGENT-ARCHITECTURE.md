# Agent Architecture — Canonical Reference

> Imported from Growth Operating Agency predecessor project 2026-04-19. Growth Operating Agency agents reference this for 82KB of agent-design bible.

---

# Growth Operating Agency GrowthOS — Complete Agent Architecture

> The most optimal way to build an AI growth operating system using the the workspace manifest
> workspace protocol, Signal Theory quality encoding, and proven growth operator
> methodologies.

**Author:** Roberto H Signal Theory (the Miosa platform Research)
**Protocol:** the workspace manifest Workspace Protocol v1
**Theory:** Signal Theory — Optimal Intent Encoding (Signal Theory, 2026)
**Generated:** 2026-03-20

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Architecture Overview](#2-architecture-overview)
3. [The 7-Layer Workspace](#3-the-7-layer-workspace)
4. [Agent Registry (Complete)](#4-agent-registry)
5. [Skill Registry (Complete)](#5-skill-registry)
6. [Template Registry (Complete)](#6-template-registry)
7. [Knowledge Architecture](#7-knowledge-architecture)
8. [Coordination & Orchestration](#8-coordination--orchestration)
9. [Integration Layer](#9-integration-layer)
10. [Quality System (Signal Theory)](#10-quality-system)
11. [Build Order & Phases](#11-build-order--phases)
12. [Competitive Moat Analysis](#12-competitive-moat)
13. [Open Questions](#13-open-questions)

---

## 1. Design Philosophy

### The Root Objective

Every component in this system serves one purpose: **maximize Signal-to-Noise
Ratio across all growth operating tasks.**

A growth operating task is any task that moves a creator/coach/agency business
from its current state to a desired state: more leads, more sales, more content,
more systems, more revenue.

Every output the system produces is a **Signal** — classified across 5 dimensions:
`S = (Mode, Genre, Type, Format, Structure)` — and evaluated against 4 governing
constraints:

| Principle | Constraint | Applied to GrowthOS |
|-----------|-----------|-------------------|
| **information theory** (channel capacity) | Don't exceed the receiver's bandwidth | A DM is 1-3 sentences. A VSL is 12-30 min. An email is 200-400 words. Match the channel. |
| **cybernetics theory** (requisite variety) | Have enough templates for every situation | 100+ templates across all asset types. No "one-size-fits-all" |
| **viable systems theory** (viable structure) | Every agent is a viable system with 5 subsystems | Operations + Coordination + Control + Intelligence + Policy |
| **feedback-loop theory** (feedback loop) | Every output has a measurable feedback signal | VSL → heatmap. Email → open rate. DM → reply rate. Ad → ROAS. |

### The Dual-Process Encoding Principle

From Signal Theory Section 10.6:

- **System 2 (deliberative):** The FIRST time a task is done, the agent uses full
  reasoning — choosing mode, genre, template, structure. This is expensive.
- **System 1 (reflexive):** Every subsequent time, the agent recognizes the genre,
  reaches for the established template, and applies judgment only to content.

**Templates convert System 2 into System 1.** This is why template depth is the
moat. An agent with 100 structural blueprints handles 100 situations reflexively.
An agent with 5 templates must deliberate on 95% of requests — slower, more
expensive, lower quality.

### The Three Layers of Knowledge

```
METHODOLOGY (frameworks/)    = HOW to think about the problem
TEMPLATES (templates/)       = WHAT structure the output takes
EXAMPLES (examples/)         = WHAT good output looks like

An agent without methodology produces generic output.
An agent without templates produces unstructured output.
An agent without examples has no calibration target.
All three are required for optimal encoding.
```

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Growth Operating Agency GrowthOS Workspace                       │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ L0: SYSTEM.md + company.yaml          (~3K tokens, ALWAYS)   │  │
│  │ Identity, ICP summary, offer summary, routing table          │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
│                              │                                      │
│  ┌──────────────────────────┴────────────────────────────────────┐  │
│  │ L1: agents/ + skills/               (~2K per item, ON-DEMAND)│  │
│  │ 35 agents across 6 domains + 40 executable skills            │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
│                              │                                      │
│  ┌──────────────────────────┴────────────────────────────────────┐  │
│  │ L2: reference/                      (DEEP CONTEXT, per task) │  │
│  │ 15 frameworks + 110 templates + 50 examples + swipe files    │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
│                              │                                      │
│  ┌──────────────────────────┴────────────────────────────────────┐  │
│  │ L3: engine/                         (INVISIBLE, 0 tokens)    │  │
│  │ Integrations: GHL, Beehiiv, Bitalytics, Stripe, Meta, etc.  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ SPEC LAYER: FSMs + Procedures + Module DAG                   │  │
│  │ Deterministic coordination — spec wins over agent judgment    │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ OUTPUT: What agents produce → output/                        │  │
│  │ VSLs, funnels, sequences, scripts, calendars, SOPs, reports  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Agent Count Summary

| Domain | Agents | Skills | Templates |
|--------|--------|--------|-----------|
| **Foundations** | 5 | 5 | 4 |
| **Marketing** | 10 | 12 | 55 |
| **Nurture** | 5 | 6 | 26 |
| **Sales** | 7 | 9 | 38 |
| **Launch** | 2 | 2 | 5 |
| **Scale** | 6 | 6 | 20 |
| **Partnerships** | 1 | 2 | 4 |
| **TOTAL** | **36** | **42** | **152** |

### Reusable from the workspace manifest Library

14 of these 36 agents can be **adapted from existing the workspace manifest library agents**
rather than built from scratch. 60+ skills can be imported directly. See
Section 4 for which agents map to which library files.

---

## 3. The 7-Layer Workspace

### Layer 0: SYSTEM.md (Always Loaded)

```markdown
# Growth Operating Agency GrowthOS

> You are Growth Operating Agency — an AI growth operating system that builds, launches, and
> scales creator businesses. You don't advise. You execute.

## Identity

You operate as the growth team for {business_name}. Every asset you create
is calibrated to this specific business's ICP, offer, and brand voice.

## Boot Sequence

1. Load company.yaml (ICP, offer, brand voice)
2. Load reference/icp.md (full ICP profile)
3. Load reference/offers.md (offer stack)
4. Load reference/brand-voice.md (tone, language, personality)
5. Ready to execute

## Core Loop

User request
  → Classify: which domain? (foundations|marketing|nurture|sales|launch|scale)
  → Route: which agent + skill?
  → Load: agent definition + skill definition + relevant template
  → Execute: follow template structure, customize with business context
  → Quality gate: S/N >= 0.8 for client-facing, 0.5 for internal
  → Deliver: output to output/ directory (+ push to integrations if configured)

## Agent Registry

### Foundations (Plan Mode)
| Agent | Skill | What It Produces |
|-------|-------|-----------------|
| Research Agent | /research | Market intelligence, competitor analysis |
| Niche Architect | /define-niche | Niche validation, positioning |
| ICP Builder | /build-icp | Full ICP profile |
| Offer Architect | /design-offer | Complete offer architecture |
| Brand Voice Extractor | /extract-voice | Brand voice profile |

### Marketing (Execute Mode)
| Agent | Skill | What It Produces |
|-------|-------|-----------------|
| Content Strategist | /content-calendar | 30-day orchestrated calendar |
| YouTube Agent | /youtube-script | 7 video script types |
| Short-Form Agent | /short-form | 9 reel/short types |
| Story Sequence Agent | /story-sequence | 8 story sequence types |
| Twitter/X Agent | /twitter-thread | 7 thread/tweet types |
| LinkedIn Agent | /linkedin-post | 6 post types |
| Paid Ads Agent | /ad-creative | 8 ad creative types |
| SEO/Blog Agent | /blog-post | SEO-optimized articles |
| Marketing Assets Agent | /marketing-asset | Graphics briefs, media kits |
| Podcast Agent | /podcast-outline | Show structure, episode outlines |

### Nurture (Educate Mode)
| Agent | Skill | What It Produces |
|-------|-------|-----------------|
| Email Sequence Agent | /email-sequence | 8 sequence types |
| Lead Magnet Agent | /lead-magnet | 8 lead magnet types |
| Community Agent | /community-content | Engagement content calendar |
| Webinar/Challenge Agent | /webinar-script | 6 event types |
| SMS Agent | /sms-sequence | Text nurture sequences |

### Sales (Convert Mode)
| Agent | Skill | What It Produces |
|-------|-------|-----------------|
| VSL Builder | /build-vsl | 7 VSL frameworks |
| Funnel Assets Agent | /build-funnel | 7 funnel architectures |
| Sales Script Agent | /sales-script | 7 script types |
| DM Sales Agent | /dm-sequence | 5 DM sequence types |
| Call Prep Agent | /call-prep | Pre-call closer brief |
| Proposal Agent | /proposal | Custom proposals |
| CRM Automation Agent | /crm-update | Pipeline management |

### Launch (Deploy Mode)
| Agent | Skill | What It Produces |
|-------|-------|-----------------|
| Launch Manager | /plan-launch | 5 launch types |
| Post-Launch Analyst | /launch-report | Performance analysis + recommendations |

### Scale (Systemize Mode)
| Agent | Skill | What It Produces |
|-------|-------|-----------------|
| SOP Builder | /build-sop | 14 role/process SOPs |
| Team Builder | /hiring-brief | 8 role hiring briefs |
| Competitor Agent | /analyze-competitor | Competitive intelligence |
| Financial Agent | /revenue-report | Revenue analysis, forecasting |
| Client Retention Agent | /retention-check | Health scoring, churn prevention |
| Case Study Agent | /case-study | Testimonial → case study conversion |

## Quality Rules

- Every output MUST resolve all 5 Signal dimensions: S=(M, G, T, F, W)
- Client-facing assets require S/N >= 0.8
- Internal assets require S/N >= 0.5
- NEVER produce output without loading the relevant template first
- ALWAYS load ICP + offer + brand voice before creating any asset
- NEVER skip the quality gate — if S/N < threshold, rewrite before delivering
```

### Layer 0: company.yaml (Always Loaded)

```yaml
# company.yaml — The user's business identity
# This file is populated during onboarding (foundations phase)

business:
  name: ""
  niche: ""
  category: ""  # coaching | agency | info-product | saas | creator
  stage: ""     # idea | launched | scaling | established

icp:
  summary: ""           # 2-3 sentence ICP summary (L0)
  full_profile: "reference/icp.md"  # Full ICP (L2)

offer:
  name: ""
  type: ""              # high-ticket | low-ticket | hybrid
  price: ""
  delivery: ""          # 1:1 | group | course | community | done-for-you
  unique_mechanism: ""
  full_profile: "reference/offers.md"

brand:
  voice_summary: ""     # 2-3 sentence brand voice (L0)
  full_profile: "reference/brand-voice.md"
  tone: ""              # direct | conversational | authoritative | casual
  language_level: ""    # sophisticated | accessible | street | academic

goals:
  primary: ""           # e.g., "Scale to $100K/mo"
  monthly_revenue_target: 0
  monthly_lead_target: 0
  primary_channel: ""   # instagram | youtube | linkedin | paid-ads | email

budget:
  monthly_total: 0      # USD
  per_agent: {}         # agent_id: monthly_usd

governance:
  approval_required:
    - client_facing_content
    - payment_integrations
    - ad_spend > 500
  auto_approved:
    - internal_research
    - draft_content
    - sop_creation

runtime_bindings:
  email_provider: ""      # beehiiv | convertkit | activecampaign
  funnel_provider: ""     # gohighlevel | clickfunnels | kajabi
  video_hosting: ""       # bitalytics | wistia | vimeo
  crm_provider: ""        # gohighlevel | close | hubspot
  payment_provider: ""    # stripe
  social_scheduler: ""    # buffer | hypefury
  ad_platform: ""         # meta | google | tiktok
  dm_platform: ""         # instagram_api | manychat
```

---

## 4. Agent Registry

### 4.1 Foundations Agents

#### Research Agent
```yaml
---
name: Research Agent
id: research
role: analyst
title: Market Intelligence Analyst
reportsTo: orchestrator
budget: 400
adapter: claude_code
signal: S=(data, report, inform, markdown, research-brief)
tools: [read, write, search, web-search]
context_tier: l0
---
```
**Core Mission:**
1. Scan markets for demand signals, pain points, and opportunity gaps
2. Analyze competitors for positioning, pricing, and messaging weaknesses
3. Validate niche viability with data-backed scoring
4. Produce research briefs that feed ICP Builder and Offer Architect

**Signal Encoding:** Every research output is an `inform` Signal (assertive — states
facts). Mode is `data` (structured findings). Genre is `report`.

**What makes this OPTIMAL vs Cook.ai's "Truth Engine":**
- Cook.ai scans "10,000+ signals" but doesn't say what signals or how they're scored
- Our Research Agent loads `reference/frameworks/icp-scoring.md` — a specific
  scoring rubric with weighted criteria
- Output follows a structural blueprint from `reference/templates/research/market-brief.md`
- Quality gate verifies: Are all claims sourced? Are comparisons apples-to-apples?
  Is the viability score justified by the data?

---

#### Niche Architect
```yaml
---
name: Niche Architect
id: niche-architect
role: strategist
title: Niche Positioning Strategist
reportsTo: orchestrator
budget: 300
adapter: claude_code
signal: S=(linguistic, spec, decide, markdown, niche-definition)
tools: [read, write, search, web-search]
context_tier: l1
---
```
**Core Mission:**
1. Take research output → define a "category of one" positioning
2. Identify the intersection of: audience pain × unique expertise × market gap
3. Name the category, define the vocabulary, establish positioning
4. Output: niche definition document that all downstream agents reference

---

#### ICP Builder
```yaml
---
name: ICP Builder
id: icp-builder
role: analyst
title: Ideal Customer Profile Architect
reportsTo: orchestrator
budget: 400
adapter: claude_code
signal: S=(data, spec, commit, markdown, icp-profile)
tools: [read, write, search, web-search]
context_tier: l1
---
```
**Core Mission:**
1. Build comprehensive ICP: demographics, psychographics, pain points,
   objections, buying triggers, awareness levels, language patterns
2. Score ICP completeness (every downstream agent depends on ICP quality)
3. Extract the prospect's actual language — how they describe their problems

**Why ICP is load-bearing:**
Every asset downstream uses ICP data:
- VSL hook → ICP pain points
- Email subject lines → ICP language patterns
- DM qualification → ICP buying triggers
- Ad targeting → ICP demographics
- Objection handling → ICP objections

A shallow ICP produces generic everything. A deep ICP produces personalized everything.

**ICP Completeness Scoring:**
| Section | Weight | Complete When |
|---------|--------|--------------|
| Demographics | 10% | Age, location, income, occupation defined |
| Psychographics | 20% | Values, beliefs, identity, aspirations defined |
| Pain Points | 20% | 5+ specific, language-matched pain points |
| Objections | 15% | Top 5 objections with response scripts |
| Buying Triggers | 15% | What events trigger purchase consideration |
| Awareness Level | 10% | Problem-aware, solution-aware, product-aware |
| Language Patterns | 10% | 20+ phrases they actually use to describe problems |

ICP must score >= 80% before downstream agents produce client-facing content.

---

#### Offer Architect
```yaml
---
name: Offer Architect
id: offer-architect
role: strategist
title: Offer Design Strategist
reportsTo: orchestrator
budget: 500
adapter: claude_code
signal: S=(linguistic, spec, commit, markdown, offer-stack)
tools: [read, write, search]
context_tier: l1
---
```
**Core Mission:**
1. Design the complete offer: unique mechanism, positioning, value stack,
   pricing, guarantee, bonuses, delivery model
2. Create the offer one-pager that all sales agents reference
3. Build the belief stack: what beliefs must the prospect hold to buy?

**Offer Architecture Template:**
```
1. The Problem (what's broken in their world)
2. The Unique Mechanism (why your solution is different)
3. The Promise (specific, measurable outcome)
4. The Vehicle (how it's delivered: course, coaching, DFY, etc.)
5. The Value Stack (core + bonuses, each solving adjacent problem)
6. The Price Anchor (what it would cost without you)
7. The Price (your actual price)
8. The Guarantee (risk transfer mechanism)
9. The Urgency (why now, not later)
10. The Belief Stack (3-5 beliefs that make buying logical)
```

---

#### Brand Voice Extractor
```yaml
---
name: Brand Voice Extractor
id: brand-voice
role: analyst
title: Brand Voice Analyst
reportsTo: orchestrator
budget: 200
adapter: claude_code
signal: S=(linguistic, spec, inform, markdown, brand-voice-profile)
tools: [read, write, search]
context_tier: l0
---
```
**Core Mission:**
1. Analyze user's existing content (social posts, emails, videos, DMs)
2. Extract: tone, sentence structure, vocabulary, personality traits,
   phrases they overuse, phrases they avoid
3. Produce `brand-voice.md` that every content agent loads

**Why this matters:**
Without brand voice, all agents sound like ChatGPT. With brand voice,
the coach's emails sound like them, the DMs sound like them, the VSL
sounds like them. This is what makes the output feel real, not AI-generated.

---

### 4.2 Marketing Agents

#### Content Strategist (The Orchestrator)
```yaml
---
name: Content Strategist
id: content-strategist
role: strategist
title: Content Strategy Director
reportsTo: orchestrator
budget: 600
adapter: claude_code
signal: S=(data, plan, direct, markdown, content-calendar)
tools: [read, write, search]
context_tier: l1
---
```
**Core Mission:**
1. Take ICP + offer + all channel agents → produce 30-day content calendar
2. Coordinate SIGNAL CHAINS: which YouTube video feeds which short-form
   which email which story sequence
3. Ensure content variety (cybernetics theory) — not 30 days of the same content type
4. Balance content pillars: value, story, proof, CTA

**The Content Repurposing Chain:**
```
1 YouTube video (long-form)
  → 3-5 short-form clips (OpusClip/manual)
  → 1 Twitter thread (key points)
  → 1 LinkedIn post (professional angle)
  → 5-7 story slides (Instagram)
  → 1 email (nurture sequence)
  → 2-3 quote graphics (marketing assets)
  → 1 blog post (SEO)
```

This is the **most efficient content production topology** — parallel flow from
a single source signal. The Content Strategist coordinates this chain.

---

#### YouTube Agent
```yaml
---
name: YouTube Agent
id: youtube
role: scriptwriter
title: YouTube Script Specialist
reportsTo: content-strategist
budget: 500
adapter: claude_code
signal: S=(linguistic, script, direct, markdown, youtube-script)
tools: [read, write, search]
context_tier: l1
---
```
**Templates (7):**
| Template | Structure | Best For |
|----------|-----------|----------|
| Educational/Value | Hook → Problem → Framework → Steps → CTA | Authority building |
| VSSL (Value-Style Sales) | Hook → Story → Proof → Reveal → CTA | Soft selling |
| Lifestyle/Vlog | Intro → Day/Scene → Lesson → CTA | Personal brand |
| Tutorial/How-To | Problem → Tool → Step-by-step → Result → CTA | SEO/search |
| Story-based | Hook → Setup → Conflict → Resolution → Lesson | Connection |
| Case Study | Result → Before → Process → After → CTA | Social proof |
| Interview/Podcast | Intro → Guest → Questions → Key Takeaways → CTA | Authority |

---

#### Short-Form Agent
```yaml
---
name: Short-Form Agent
id: short-form
role: scriptwriter
title: Short-Form Content Specialist
reportsTo: content-strategist
budget: 400
adapter: claude_code
signal: S=(linguistic, script, direct, markdown, short-form-hook)
tools: [read, write, search]
context_tier: l1
---
```
**Templates (9):**
| Template | Hook Type | Duration | Best For |
|----------|-----------|----------|----------|
| Storytelling | "I was..." | 30-60s | Connection |
| Lifestyle | Visual hook | 15-30s | Aspirational |
| Lead Magnet Reel | "Free [thing]..." | 15-30s | List building |
| Hook + Value | Pattern interrupt | 30-60s | Authority |
| Behind The Scenes | "Day in my life..." | 30-60s | Authenticity |
| Quick Tips | "3 things..." | 15-30s | Saves/shares |
| Transformation | Before/after | 15-30s | Social proof |
| Testimonial | Client quote | 15-30s | Trust |
| Split Screen | React/stitch | 15-30s | Trending |

**information theory constraint for short-form:**
Channel capacity = 15-60 seconds of audio = 50-200 words MAX.
Every word must earn its place. No filler. No "in this video I'm going to..."

---

#### Story Sequence Agent
```yaml
---
name: Story Sequence Agent
id: stories
role: scriptwriter
title: Instagram Story Strategist
reportsTo: content-strategist
budget: 300
adapter: claude_code
signal: S=(linguistic, sequence, direct, markdown, story-sequence)
tools: [read, write, search]
context_tier: l1
---
```
**Templates (8):**
| Template | Purpose | Slides | Best For |
|----------|---------|--------|----------|
| Launch Sequence | Drive to offer | 7-12 | Product launch |
| Proof from Many | Social proof stack | 5-8 | Credibility |
| Objection Breaking | Handle resistance | 5-7 | Pre-selling |
| Education/Differentiation | Teach + position | 5-8 | Authority |
| FAQ/Clarity | Answer questions | 5-7 | Objection removal |
| Personal Connection | Behind the scenes | 3-5 | Trust |
| Skepticism Removal | Address doubts | 5-7 | Pre-selling |
| Mission/Values | Why you do this | 3-5 | Brand building |

---

#### Twitter/X Agent
```yaml
---
name: Twitter/X Agent
id: twitter
role: copywriter
title: Twitter/X Content Specialist
reportsTo: content-strategist
budget: 300
adapter: claude_code
signal: S=(linguistic, thread, inform, markdown, twitter-thread)
tools: [read, write, search]
context_tier: l1
---
```
**Templates (7):**
| Template | Structure | Typical Length |
|----------|-----------|---------------|
| Thread | Hook → Points → CTA | 5-15 tweets |
| Story Thread | Hook → Chronological → Lesson | 7-12 tweets |
| Hot Take | Contrarian claim → Evidence → Conclusion | 3-5 tweets |
| How-To Thread | Problem → Steps → Result | 5-10 tweets |
| Listicle Thread | "X things I learned..." | 7-15 tweets |
| Case Study Thread | Before → Process → After | 5-8 tweets |
| Daily Tweets | Standalone insights | 1 tweet |

---

#### LinkedIn Agent
```yaml
---
name: LinkedIn Agent
id: linkedin
role: copywriter
title: LinkedIn Content Specialist
reportsTo: content-strategist
budget: 300
adapter: claude_code
signal: S=(linguistic, post, inform, markdown, linkedin-post)
tools: [read, write, search]
context_tier: l1
---
```
**Templates (6):**
| Template | Format | Best For |
|----------|--------|----------|
| Carousel | 8-12 slides, visual | High saves/shares |
| Personal Story | Hook → Narrative → Lesson | Connection |
| Industry Insight | Data + interpretation | Authority |
| Company Update | Milestone → Lesson | Brand building |
| Thought Leadership | Contrarian + evidence | Positioning |
| Engagement Post | Question → Context → Invite | Algorithm boost |

---

#### Paid Ads Agent
```yaml
---
name: Paid Ads Agent
id: paid-ads
role: creative-strategist
title: Paid Advertising Specialist
reportsTo: content-strategist
budget: 600
adapter: claude_code
signal: S=(mixed, brief, direct, markdown, ad-creative)
tools: [read, write, search, web-search]
context_tier: l1
---
```
**Templates (8):**
| Template | Format | Platform | Best For |
|----------|--------|----------|----------|
| Profile Funnel Ads | Image/Video | Meta | Cold traffic → profile |
| Retargeting Ads | Image/Video | Meta | Warm → conversion |
| Video Ad (Hook Style) | Video 15-60s | Meta/TikTok/YT | Cold → VSL |
| Video Ad (Story Style) | Video 30-90s | Meta/YT | Cold → application |
| Video Ad (Testimonial) | Video 30-60s | Meta | Warm → conversion |
| Image Ad (Single) | Static image | Meta/LinkedIn | Cold → landing page |
| Carousel Ad | 3-10 images | Meta/LinkedIn | Education → CTA |
| UGC-Style Ad | Video 15-60s | Meta/TikTok | Cold → trust |

---

#### SEO/Blog Agent
```yaml
---
name: SEO/Blog Agent
id: seo-blog
role: writer
title: SEO Content Specialist
reportsTo: content-strategist
budget: 400
adapter: claude_code
signal: S=(linguistic, article, inform, markdown, seo-article)
tools: [read, write, search, web-search]
context_tier: l1
---
```
**Core Mission:**
1. Keyword research → identify high-intent, low-competition topics
2. Write long-form SEO articles (1,500-3,000 words)
3. Structure for featured snippets and AI search optimization
4. Internal linking strategy across content

---

#### Marketing Assets Agent
```yaml
---
name: Marketing Assets Agent
id: marketing-assets
role: designer
title: Marketing Asset Producer
reportsTo: content-strategist
budget: 200
adapter: claude_code
signal: S=(visual, brief, direct, markdown, asset-brief)
tools: [read, write, search]
context_tier: l0
---
```
**Outputs:** Lead magnet graphics briefs, social proof screenshots, testimonial
card copy, brand kit specifications, media kit content.

---

#### Podcast Agent
```yaml
---
name: Podcast Agent
id: podcast
role: scriptwriter
title: Podcast Content Specialist
reportsTo: content-strategist
budget: 300
adapter: claude_code
signal: S=(linguistic, script, inform, markdown, podcast-outline)
tools: [read, write, search]
context_tier: l1
---
```
**Outputs:** Show concept, episode outlines, guest prep sheets, show notes, clip
suggestions for repurposing.

---

### 4.3 Nurture Agents

#### Email Sequence Agent
```yaml
---
name: Email Sequence Agent
id: email-sequence
role: copywriter
title: Email Strategy Specialist
reportsTo: orchestrator
budget: 500
adapter: claude_code
signal: S=(linguistic, sequence, direct, markdown, email-sequence)
tools: [read, write, search]
context_tier: l1
---
```

**Templates (8):**
| Template | Emails | Purpose | Timing |
|----------|--------|---------|--------|
| Welcome Sequence | 5-7 | Onboard new subscriber | Days 0-7 |
| Nurture Sequence | 7-14 | Build trust + authority | Days 7-30 |
| Launch Sequence | 7-10 | Drive to offer | 7-10 day window |
| Webinar Sequence | 5-7 | Register + show up + follow up | Pre/post event |
| Re-engagement Sequence | 3-5 | Win back cold subscribers | After 30+ days inactive |
| Application Sequence | 3-5 | Drive to application form | Post-VSL or post-webinar |
| Post-Purchase Sequence | 5-7 | Onboard + reduce refunds | Days 0-14 post-purchase |
| Single Broadcast | 1 | One-off announcement | Immediate |

**Methodology:** VEST Framework (Value → Empathy → Story → Transition)
- Email 1-2: Pure value (earn the right to keep emailing)
- Email 3-4: Empathy + story (build connection)
- Email 5+: Transition to offer (only after trust established)

**Critical Rules:**
- NEVER pitch before email 3 in a nurture sequence
- ALWAYS write 2 subject line variants per email (A/B testing)
- NEVER use more than 1 CTA per email
- ALWAYS reference ICP pain points in exact audience language
- information theory constraint: 200-400 words per email for mobile reading

---

#### Lead Magnet Agent
```yaml
---
name: Lead Magnet Agent
id: lead-magnet
role: designer
title: Lead Magnet Architect
reportsTo: orchestrator
budget: 400
adapter: claude_code
signal: S=(linguistic, guide, inform, markdown, lead-magnet)
tools: [read, write, search]
context_tier: l1
---
```

**Templates (8):**
| Template | Format | Pages | Best For |
|----------|--------|-------|----------|
| PDF Guide | Long-form PDF | 10-30 | Deep education |
| Checklist | 1-page PDF | 1-2 | Quick wins |
| Cheat Sheet | 1-page PDF | 1-2 | Reference material |
| Swipe File | Multi-page PDF | 5-15 | Templates to copy |
| Mini Course | 3-5 video/email | Varies | Nurture into offer |
| Quiz/Assessment | Interactive | 10-15 Qs | Segmentation + engagement |
| Calculator/Tool | Spreadsheet/app | N/A | Quantified value |
| Free Training | Video 20-45 min | 1 video | Pre-sell into offer |

---

#### Community Agent
```yaml
---
name: Community Agent
id: community
role: strategist
title: Community Engagement Specialist
reportsTo: orchestrator
budget: 300
adapter: claude_code
signal: S=(linguistic, plan, direct, markdown, community-strategy)
tools: [read, write, search]
context_tier: l1
---
```
**Outputs:** 30-day community content calendar, welcome posts, engagement
prompts, challenge frameworks, member spotlight templates, weekly theme plans.

---

#### Webinar/Challenge Agent
```yaml
---
name: Webinar/Challenge Agent
id: webinar
role: scriptwriter
title: Event Script Specialist
reportsTo: orchestrator
budget: 500
adapter: claude_code
signal: S=(linguistic, script, direct, markdown, webinar-script)
tools: [read, write, search]
context_tier: l1
---
```

**Templates (6):**
| Template | Duration | Structure | Best For |
|----------|----------|-----------|----------|
| Live Webinar | 60-90 min | Teach → Pitch → Q&A | High-ticket |
| Evergreen Webinar | 45-60 min | Automated version of live | Passive |
| 3-Day Challenge | 3 × 30-45 min | Day 1: What, Day 2: How, Day 3: Offer | Launch |
| 5-Day Challenge | 5 × 20-30 min | Quick wins → bigger transformation → offer | Community |
| 7-Day Challenge | 7 × 15-20 min | Daily micro-wins building to offer | Nurture |
| Workshop | 2-3 hours | Deep training → offer at end | Premium |

---

#### SMS Agent
```yaml
---
name: SMS Agent
id: sms
role: copywriter
title: SMS Sequence Specialist
reportsTo: orchestrator
budget: 200
adapter: claude_code
signal: S=(linguistic, sequence, direct, message, sms-sequence)
tools: [read, write, search]
context_tier: l0
---
```
**information theory constraint:** SMS = 160 characters. MMS = slightly more. Every character counts.
**Templates:** Appointment reminder, webinar reminder, flash sale, re-engagement.

---

### 4.4 Sales Agents

#### VSL Builder
```yaml
---
name: VSL Builder
id: vsl-builder
role: scriptwriter
title: VSL Script Architect
reportsTo: orchestrator
budget: 800
adapter: claude_code
signal: S=(linguistic, script, commit, markdown, vsl-script)
tools: [read, write, search]
context_tier: l1
---
```

**Methodology:** pull-push-persuade Framework (11 steps)
```
PULL (Steps 1-4): Earn the right to be heard
  1. The Promise (Hook) — 8 seconds to filter the right viewer
  2. The Profile (Self-Selection) — describe their situation back to them
  3. The Proof (Credibility) — results proof, specificity proof, pattern proof
  4. The Presence (Introduction) — only NOW introduce yourself

PUSH (Steps 5-8): Create honest emotional pressure
  5. Pain Points (Cost of Inaction) — compounding pain, not surface pain
  6. Case Studies — before/after that mirrors the viewer's situation
  7. The Process (Differentiator) — show that a PROCESS exists
  8. Future Pacing — make the outcome tangible and concrete

PERSUADE (Steps 9-11): Remove barriers and close
  9. Objection Handling — preemptive demolition of 4 core objections
  10. The Close — 5 layers: deliverable, value stack, price anchor, guarantee, CTA
  11. The Postscript — catch people still on the fence
```

**Templates (7):**
| Template | Length | Best For | Price Point |
|----------|--------|----------|-------------|
| Archetype-Based | 25-35 min | Identity-driven coaching | $3K-$25K |
| 15-Minute VSL | 12-15 min | Direct, no-fluff | $497-$2K |
| 30-Minute VSL | 25-30 min | Full story arc | $2K-$10K |
| 45-Minute VSL | 40-45 min | Webinar replacement | $5K-$25K |
| Webinar-Style | 45-60 min | Teach + pitch | $2K-$10K |
| Story-Driven | 20-30 min | Personal journey | $1K-$5K |
| Case Study VSL | 15-25 min | Proof-first | $1K-$10K |

**This is Growth Operating Agency's #1 differentiator.** No other platform has this depth of VSL
methodology encoded as machine-readable templates with structural blueprints.

---

#### Funnel Assets Agent
```yaml
---
name: Funnel Assets Agent
id: funnel-assets
role: copywriter
title: Funnel Copy & Architecture Specialist
reportsTo: orchestrator
budget: 600
adapter: claude_code
signal: S=(linguistic, spec, direct, markdown, funnel-blueprint)
tools: [read, write, search]
context_tier: l1
---
```

**Templates (7):**
| Template | Pages | Flow | Best For |
|----------|-------|------|----------|
| VSL Funnel | 3-4 | VSL → Application → Thank You → Booking | High-ticket |
| Webinar Funnel | 4-5 | Reg → Thank You → Live → Replay → Application | Mid-ticket |
| Application Funnel | 3 | Sales Page → Application → Booking | High-ticket |
| Low-Ticket Funnel | 3-4 | Sales Page → Checkout → Upsell → Thank You | $27-$297 |
| Challenge Funnel | 4-5 | Reg → Daily Content → Offer → Application | Community |
| Book-a-Call Funnel | 2-3 | VSL/Sales Page → Calendar → Confirmation | High-ticket |
| Tripwire Funnel | 3-4 | Lead Magnet → $7-$47 Offer → Upsell → Thank You | List building |

---

#### Sales Script Agent
```yaml
---
name: Sales Script Agent
id: sales-scripts
role: scriptwriter
title: Sales Conversation Specialist
reportsTo: orchestrator
budget: 500
adapter: claude_code
signal: S=(linguistic, script, direct, markdown, sales-script)
tools: [read, write, search]
context_tier: l1
---
```

**Templates (7):**
| Template | Role | Duration | Structure |
|----------|------|----------|-----------|
| Closer Script | Closer | 30-45 min | Rapport → Discovery → Present → Close |
| Setter Script | Setter | 5-10 min | Qualify → Pain → Book |
| Dialer/SDR Script | SDR | 3-5 min | Intro → Qualify → Book |
| Follow-Up Script | Any | 2-5 min | Context → Value → Next Step |
| Objection Library | Any | N/A | 20+ objections with response scripts |
| Upgrade/Upsell Script | CSM | 10-15 min | Results → Gap → Upgrade |
| Referral Ask Script | Any | 3-5 min | Celebrate → Ask → Incentivize |

---

#### DM Sales Agent
```yaml
---
name: DM Sales Agent
id: dm-sales
role: setter
title: DM Sales Automation Specialist
reportsTo: orchestrator
budget: 600
adapter: claude_code
signal: S=(linguistic, sequence, direct, message, dm-sequence)
tools: [read, write, search]
context_tier: l1
---
```

**Templates (5):**
| Template | Trigger | Messages | Goal |
|----------|---------|----------|------|
| Cold DM Sequence | Outbound to ICP match | 3-5 | Start conversation |
| Warm DM Sequence | Engaged with content | 3-5 | Qualify + book |
| Comment-to-DM | Commented on post/reel | 2-3 | Deliver value + qualify |
| Story Reply Sequence | Replied to story | 2-4 | Deepen + qualify |
| Closing Sequence | Qualified, not booked | 3-5 | Overcome resistance + book |

**This agent replaces Mochi** when built with:
- ICP-aware qualification (not generic)
- Offer-aligned messaging (knows what to sell)
- Brand voice compliance (sounds like the user)
- Setter→Closer handoff protocol (structured handoff template)
- Feedback loop: reply rate + booking rate per message variant

---

#### Call Prep Agent
```yaml
---
name: Call Prep Agent
id: call-prep
role: analyst
title: Pre-Call Intelligence Specialist
reportsTo: orchestrator
budget: 200
adapter: claude_code
signal: S=(data, brief, inform, markdown, call-prep-brief)
tools: [read, search]
context_tier: l0
---
```
**No competitor has this.** Before every sales call, this agent produces a 1-page
closer brief containing:
- Lead's full context (where they came from, what they engaged with)
- Conversation history summary (DMs, emails, comments)
- ICP score and which criteria they match
- Top 3 likely objections (based on their profile)
- Recommended approach (which case study to reference, which angle)
- MEDDPICC qualification status

---

#### Proposal Agent
```yaml
---
name: Proposal Agent
id: proposal
role: copywriter
title: Proposal & Invoice Specialist
reportsTo: orchestrator
budget: 300
adapter: claude_code
signal: S=(linguistic, proposal, commit, markdown, proposal-template)
tools: [read, write, search]
context_tier: l1
---
```
**Outputs:** Custom proposals with value stacking, pricing, terms, SOW.
Integration: PandaDoc, Stripe for payment links.

---

#### CRM Automation Agent
```yaml
---
name: CRM Automation Agent
id: crm-automation
role: operator
title: CRM & Pipeline Specialist
reportsTo: orchestrator
budget: 300
adapter: claude_code
signal: S=(data, report, inform, markdown, pipeline-update)
tools: [read, write, search]
context_tier: l0
---
```
**Outputs:** Pipeline stage management, automated follow-up triggers, deal
scoring, revenue forecasting, missed follow-up alerts.

---

### 4.5 Launch Agents

#### Launch Manager
```yaml
---
name: Launch Manager
id: launch-manager
role: strategist
title: Launch Strategy Director
reportsTo: orchestrator
budget: 600
adapter: claude_code
signal: S=(data, plan, direct, markdown, launch-sequence)
tools: [read, write, search]
context_tier: l1
---
```

**Templates (5):**
| Template | Duration | Phases | Best For |
|----------|----------|--------|----------|
| Live Launch | 7-14 days | Pre-launch → Cart Open → Cart Close | First launch |
| Evergreen Launch | Continuous | Automated trigger → sequence → deadline | Passive |
| Rolling Launch | Monthly | Monthly cohort → deadline → next cohort | Recurring |
| Flash Sale | 24-72 hours | Announce → Urgency → Close | Revenue spike |
| Beta Launch | 5-7 days | Invite → Feedback → Iterate | Validation |

**The Launch Manager orchestrates ALL other agents:**
```
Pre-Launch:
  → Email Agent: pre-launch sequence
  → Story Agent: anticipation sequence
  → Content Strategist: launch content calendar
  → Ad Agent: pre-launch awareness ads

Launch:
  → Email Agent: launch sequence (cart open → close)
  → Story Agent: launch sequence
  → DM Agent: warm DM sequence to engaged leads
  → Ad Agent: retargeting ads
  → Webinar Agent: if applicable

Post-Launch:
  → Post-Launch Analyst: full performance analysis
  → Email Agent: post-purchase sequence
  → Community Agent: new member onboarding
```

---

#### Post-Launch Analyst
```yaml
---
name: Post-Launch Analyst
id: post-launch
role: analyst
title: Launch Performance Analyst
reportsTo: launch-manager
budget: 300
adapter: claude_code
signal: S=(data, report, inform, markdown, launch-report)
tools: [read, search]
context_tier: l0
---
```
**Outputs:** Complete post-mortem with:
- Funnel metrics: traffic → opt-in rate → VSL watch rate → application rate → show rate → close rate
- Revenue: total, per lead, per dollar spent
- Content performance: which posts/emails/stories drove most conversions
- Specific recommendations for next launch

---

### 4.6 Scale Agents

#### SOP Builder
```yaml
---
name: SOP Builder
id: sop-builder
role: operator
title: Standard Operating Procedure Architect
reportsTo: orchestrator
budget: 400
adapter: claude_code
signal: S=(linguistic, SOP, direct, markdown, role-sop)
tools: [read, write, search]
context_tier: l1
---
```

**Role Templates (8):**
| Role | SOP Focus | Deliverable |
|------|-----------|-------------|
| Setter | DM qualification + booking | Setter playbook |
| Closer | Sales call process | Closer playbook |
| SDR/Dialer | Cold calling process | Dialer playbook |
| Content Manager | Content production pipeline | Content SOP |
| Video Editor | Edit specs, delivery format | Editor SOP |
| Customer Success | Client management process | CS playbook |
| VA/Admin | Daily operations | Admin SOP |
| Marketing Manager | Campaign management | Marketing SOP |

**Process Templates (6):**
| Process | Steps | Owner |
|---------|-------|-------|
| Sales Process | Lead → Qualify → Call → Close → Onboard | Sales team |
| Content Production | Idea → Script → Shoot → Edit → Publish | Content team |
| Client Onboarding | Purchase → Welcome → Access → Kickoff | CS team |
| Lead Management | Capture → Score → Route → Nurture | Marketing/Sales |
| Quality Assurance | Draft → Review → Approve → Publish | All teams |
| Reporting | Collect → Analyze → Report → Action | Operations |

---

#### Team Builder
```yaml
---
name: Team Builder
id: team-builder
role: strategist
title: Hiring & Team Design Specialist
reportsTo: orchestrator
budget: 300
adapter: claude_code
signal: S=(linguistic, brief, direct, markdown, hiring-brief)
tools: [read, write, search]
context_tier: l1
---
```
**Outputs:** Job descriptions, interview question banks, skills assessments,
compensation benchmarks, onboarding checklists.

---

#### Competitor Agent
```yaml
---
name: Competitor Agent
id: competitor
role: analyst
title: Competitive Intelligence Specialist
reportsTo: orchestrator
budget: 400
adapter: claude_code
signal: S=(data, report, inform, markdown, competitor-brief)
tools: [read, write, search, web-search]
context_tier: l1
---
```
**Outputs:** Competitor profiles, pricing analysis, ad library scanning,
positioning gaps, battlecards for sales team.

---

#### Financial Agent
```yaml
---
name: Financial Agent
id: financial
role: analyst
title: Revenue Intelligence Analyst
reportsTo: orchestrator
budget: 400
adapter: claude_code
signal: S=(data, report, inform, markdown, financial-dashboard)
tools: [read, write, search]
context_tier: l0
---
```
**Outputs:** MRR tracking, LTV calculation, churn analysis, CAC by channel,
ROAS by campaign, cash flow forecasting, unit economics analysis.

---

#### Client Retention Agent
```yaml
---
name: Client Retention Agent
id: retention
role: strategist
title: Client Success Strategist
reportsTo: orchestrator
budget: 300
adapter: claude_code
signal: S=(linguistic, plan, direct, markdown, retention-plan)
tools: [read, write, search]
context_tier: l1
---
```
**Outputs:** Client health scores, check-in sequences, upsell triggers,
NPS survey + analysis, churn risk alerts, win-back sequences.

---

#### Case Study Agent
```yaml
---
name: Case Study Agent
id: case-study
role: copywriter
title: Testimonial & Case Study Specialist
reportsTo: orchestrator
budget: 300
adapter: claude_code
signal: S=(linguistic, report, inform, markdown, case-study)
tools: [read, write, search]
context_tier: l1
---
```
**Outputs:** Transforms raw client results into:
- Long-form case study (for website)
- Short-form case study (for VSL/email)
- Testimonial card copy (for social)
- Video testimonial questions (for client to record)
- Social proof screenshots (formatted for ads)

---

## 5. Skill Registry

Every skill follows this pattern:
```
/skill-name <required_arg> [--optional flag]

Agent Activation:
  Wave 1: [agents activated in parallel]
  Wave 2: [agents activated after Wave 1 completes]
  Wave N: ...

Process:
  1. Load relevant context (ICP, offer, brand voice)
  2. Load template from reference/templates/
  3. Execute using methodology from reference/frameworks/
  4. Quality gate: S/N check
  5. Output to output/ directory
  6. If integrations configured: push to platform

Output: signal encoding + file path
```

### Complete Skill List (40 skills)

**Foundations (5):**
| Skill | Command | Agents | Output |
|-------|---------|--------|--------|
| Market Research | `/research <topic>` | research | Research brief |
| Niche Definition | `/define-niche` | niche-architect, research | Niche document |
| ICP Build | `/build-icp` | icp-builder, research | Full ICP profile |
| Offer Design | `/design-offer` | offer-architect | Offer architecture |
| Voice Extraction | `/extract-voice` | brand-voice | Brand voice profile |

**Marketing (12):**
| Skill | Command | Agents | Output |
|-------|---------|--------|--------|
| Content Calendar | `/content-calendar [--days 30]` | content-strategist | 30-day calendar |
| YouTube Script | `/youtube-script <type>` | youtube | Video script |
| Short-Form | `/short-form <type>` | short-form | Reel/short script |
| Story Sequence | `/story-sequence <type>` | stories | Story slide sequence |
| Twitter Thread | `/twitter-thread <type>` | twitter | Thread/tweets |
| LinkedIn Post | `/linkedin-post <type>` | linkedin | LinkedIn content |
| Ad Creative | `/ad-creative <type> [--platform meta]` | paid-ads | Ad copy + brief |
| Blog Post | `/blog-post <topic>` | seo-blog | SEO article |
| Marketing Asset | `/marketing-asset <type>` | marketing-assets | Asset brief |
| Podcast Outline | `/podcast-outline <topic>` | podcast | Episode outline |
| Competitor Analysis | `/analyze-competitor <url>` | competitor, research | Competitor brief |
| Content Repurpose | `/repurpose <source_content>` | content-strategist | Multi-format content |

**Nurture (6):**
| Skill | Command | Agents | Output |
|-------|---------|--------|--------|
| Email Sequence | `/email-sequence <type>` | email-sequence | Full email sequence |
| Lead Magnet | `/lead-magnet <type>` | lead-magnet | Lead magnet content |
| Community Content | `/community-content [--days 30]` | community | Content calendar |
| Webinar Script | `/webinar-script <type>` | webinar | Full event script |
| SMS Sequence | `/sms-sequence <type>` | sms | SMS nurture sequence |
| Retarget Sequence | `/retarget <trigger>` | email-sequence, sms | Multi-channel retarget |

**Sales (9):**
| Skill | Command | Agents | Output |
|-------|---------|--------|--------|
| Build VSL | `/build-vsl <type> [--length 30]` | vsl-builder, research | Complete VSL script |
| Build Funnel | `/build-funnel <type>` | funnel-assets | Funnel copy + structure |
| Sales Script | `/sales-script <type>` | sales-scripts | Call script |
| DM Sequence | `/dm-sequence <type>` | dm-sales | DM conversation flow |
| Call Prep | `/call-prep <lead_info>` | call-prep | Pre-call brief |
| Proposal | `/proposal <client>` | proposal | Custom proposal |
| CRM Update | `/crm-update <action>` | crm-automation | Pipeline updates |
| Objection Library | `/objections` | sales-scripts | Complete objection library |
| Full Sales Stack | `/sales-stack` | ALL sales agents | Complete sales infrastructure |

**Launch (2):**
| Skill | Command | Agents | Output |
|-------|---------|--------|--------|
| Plan Launch | `/plan-launch <type>` | launch-manager, ALL | Complete launch plan |
| Launch Report | `/launch-report` | post-launch | Performance analysis |

**Scale (6):**
| Skill | Command | Agents | Output |
|-------|---------|--------|--------|
| Build SOP | `/build-sop <role\|process>` | sop-builder | SOP document |
| Hiring Brief | `/hiring-brief <role>` | team-builder | Job description + process |
| Revenue Report | `/revenue-report` | financial | Financial analysis |
| Retention Check | `/retention-check` | retention | Client health report |
| Case Study | `/case-study <client_results>` | case-study | Full case study |
| Competitor Intel | `/competitor-intel <competitor>` | competitor | Battlecard |

---

## 6. Template Registry

**Total: 148 templates across 15 categories**

| Category | Count | Location |
|----------|-------|----------|
| YouTube scripts | 7 | reference/templates/youtube/ |
| Short-form scripts | 9 | reference/templates/short-form/ |
| Story sequences | 8 | reference/templates/stories/ |
| Twitter/X | 7 | reference/templates/twitter/ |
| LinkedIn | 6 | reference/templates/linkedin/ |
| Paid ads | 8 | reference/templates/ads/ |
| Email sequences | 8 | reference/templates/email/ |
| Lead magnets | 8 | reference/templates/lead-magnets/ |
| Webinars/challenges | 6 | reference/templates/webinar/ |
| VSL scripts | 7 | reference/templates/vsl/ |
| Funnel architectures | 7 | reference/templates/funnel/ |
| Sales scripts | 7 | reference/templates/sales-scripts/ |
| DM sequences | 5 | reference/templates/dm/ |
| Launch types | 5 | reference/templates/launch/ |
| SOPs (roles + processes) | 14 | reference/templates/sops/ |
| Proposals | 3 | reference/templates/proposals/ |
| Case studies | 3 | reference/templates/case-studies/ |
| SMS sequences | 4 | reference/templates/sms/ |
| Blog/SEO | 4 | reference/templates/blog/ |
| Podcast | 3 | reference/templates/podcast/ |
| Community | 4 | reference/templates/community/ |
| Hiring briefs | 8 | reference/templates/hiring/ |

Each template file follows this structure:
```markdown
# [Template Name]

## Signal Encoding
S=(mode, genre, type, format, structure)

## When to Use
[Situation this template is optimal for]

## Structure
[Section-by-section structural blueprint with purpose per section]

## Rules
[NEVER/ALWAYS constraints specific to this template]

## information theory Constraints
[Channel capacity limits: word count, duration, character count]

## Example
[Golden example following this exact structure]
```

---

## 7. Knowledge Architecture

### Where Domain Knowledge Lives

```
reference/
│
├── frameworks/                    ← HOW to think (methodology)
│   ├── pull-push-persuade.md      ← 11-step VSL framework
│   ├── vest-email.md              ← Value→Empathy→Story→Transition
│   ├── super-intelligence.md      ← Growth Operating Agency strategic thinking frameworks
│   ├── offer-creation.md          ← Unique mechanism, value stack, guarantee
│   ├── icp-scoring.md             ← ICP completeness criteria + scoring
│   ├── meddpicc-sales.md          ← High-ticket qualification
│   ├── hook-frameworks.md         ← 12 hook types for all content
│   ├── aida-p.md                  ← Attention→Interest→Desire→Action→Proof
│   ├── content-repurposing.md     ← 1→20 pieces content chain
│   ├── launch-formula.md          ← Pre-launch→Launch→Post-launch
│   ├── dm-psychology.md           ← DM conversation psychology
│   ├── objection-handling.md      ← 4 core objection categories + frameworks
│   ├── pricing-psychology.md      ← Price anchoring, value perception
│   ├── signal-encoding.md         ← Signal Theory applied to marketing
│   └── storytelling-framework.md  ← Story structure for all content types
│
├── templates/                     ← WHAT structure (148 blueprints)
│   └── [see Template Registry above]
│
├── examples/                      ← WHAT good looks like (2-3 per template)
│   ├── vsl/
│   │   ├── archetype-coaching.md
│   │   ├── story-driven-agency.md
│   │   └── case-study-saas.md
│   ├── email/
│   │   ├── welcome-coach.md
│   │   └── launch-course.md
│   └── [2-3 examples per template type]
│
├── swipe-file/                    ← PROVEN real-world assets
│   ├── hooks-that-converted.md
│   ├── subject-lines-tested.md
│   ├── dm-scripts-that-close.md
│   ├── ad-copy-winners.md
│   └── vsl-scripts-proven.md
│
├── operator-playbooks/            ← Growth Operating Agency synthesized methodologies
│   ├── growth-os-nhb-methodology.md
│   ├── growth-os-cloutprofit-methodology.md
│   ├── growth-os-systems-methodology.md
│   ├── growth-os-infoproducts-methodology.md
│   └── growth-os-ai-automation-methodology.md
│
├── market-intelligence/           ← LIVING knowledge (updated by agents)
│   ├── competitor-landscape.md
│   ├── platform-algorithms.md
│   ├── pricing-benchmarks.md
│   └── conversion-benchmarks.md
│
├── icp.md                         ← User's ICP (built by ICP Builder)
├── offers.md                      ← User's offer stack (built by Offer Architect)
└── brand-voice.md                 ← User's voice (built by Brand Voice Extractor)
```

### How Knowledge Loads (Tiered)

```
User: "/build-vsl archetype --length 30"

L0 (already loaded):
  SYSTEM.md → knows this is a sales task
  company.yaml → ICP summary + offer summary + brand voice summary

L1 (loaded on demand):
  agents/vsl-builder.md → agent identity + methodology + rules
  skills/sales/build-vsl/SKILL.md → execution workflow + wave activation

L2 (loaded for this specific task):
  reference/frameworks/pull-push-persuade.md → 11-step methodology
  reference/templates/vsl/archetype-based.md → structural blueprint
  reference/examples/vsl/archetype-coaching.md → golden example
  reference/icp.md → full ICP profile (pain points, objections, language)
  reference/offers.md → full offer details (mechanism, value stack, price)
  reference/brand-voice.md → how the user talks

L3 (invisible, if configured):
  engine/integrations/video.yaml → Bitalytics API
  engine/integrations/funnel.yaml → GoHighLevel API

Total context: ~20-30K tokens of HYPER-RELEVANT information
vs. Cook.ai dumping generic context into a 4K prompt
```

---

## 8. Coordination & Orchestration

### The Spec Layer

Agent coordination uses three files in `spec/`:

#### PROCEDURES.md — Action Bindings

Every external API call is a typed procedure:

```markdown
### UploadVSL → Actions.upload_vsl/2
  @spec upload_vsl(context(), %{video_url: String.t(), title: String.t()})
    :: {:ok, hosted_url} | {:error, reason}
  Runtime: video_hosting provider (hot-swap: Bitalytics, Wistia, Vimeo)
  Timeout: 120s
  Approval: none

### DeployFunnel → Actions.deploy_funnel/2
  @spec deploy_funnel(context(), %{funnel_type: atom(), pages: list()})
    :: {:ok, funnel_url} | {:error, reason}
  Runtime: funnel_provider (hot-swap: GoHighLevel, {FUNNEL_BUILDER}, Kajabi)
  Timeout: 60s
  Approval: governance.funnel_review (if contains payment page)

### SendEmailSequence → Actions.send_email_sequence/2
  @spec send_email_sequence(context(), %{sequence: list(), list_id: String.t()})
    :: {:ok, campaign_id} | {:error, reason}
  Runtime: email_provider (hot-swap: Beehiiv, ConvertKit, ActiveCampaign)
  Timeout: 30s
  Approval: none

### CreateAdCampaign → Actions.create_ad_campaign/2
  @spec create_ad_campaign(context(), %{platform: atom(), creative: map()})
    :: {:ok, campaign_id} | {:error, reason}
  Runtime: ad_platform (hot-swap: Meta, Google, TikTok)
  Timeout: 30s
  Approval: governance.ad_spend_review (if daily_budget > 100)

### PublishContent → Actions.publish_content/2
  @spec publish_content(context(), %{platform: atom(), content: map()})
    :: {:ok, post_id} | {:error, reason}
  Runtime: social_scheduler (hot-swap: Buffer, Hypefury)
  Timeout: 15s
  Approval: none (if content passed quality gate)

### SendDM → Actions.send_dm/2
  @spec send_dm(context(), %{platform: atom(), recipient: String.t(), message: String.t()})
    :: {:ok, message_id} | {:error, reason}
  Runtime: dm_platform (hot-swap: Instagram API, ManyChat)
  Timeout: 10s
  Approval: none (if message passed brand voice check)

### BookAppointment → Actions.book_appointment/2
  @spec book_appointment(context(), %{calendar: String.t(), lead: map()})
    :: {:ok, booking_id} | {:error, reason}
  Runtime: calendar_provider (hot-swap: Calendly, GHL Booking)
  Timeout: 10s
  Approval: none

### ProcessPayment → Actions.process_payment/2
  @spec process_payment(context(), %{amount: float(), customer: map()})
    :: {:ok, payment_id} | {:error, reason}
  Runtime: payment_provider (Stripe)
  Timeout: 30s
  Approval: governance.payment_review (always)
```

#### WORKFLOW.md — Finite State Machines

```markdown
## User Onboarding FSM

### :start
  trigger: Event.eq(:type, :new_user)
  pipeline:
    - FSM.transition(:research)

### :research
  trigger: auto
  pipeline:
    - ResearchAgent.invoke(%{topic: $user.niche}) → %{market_data}
    - Branch.on(:market_data.viability_score)
        >= 7 → FSM.transition(:build_icp)
        < 7 → FSM.transition(:niche_revision)
  timeout: 24h

### :build_icp
  trigger: auto
  pipeline:
    - ICPBuilder.invoke(%{market_data: $research, user_input: $user}) → %{icp}
    - Branch.on(:icp.completeness_score)
        >= 80 → FSM.transition(:build_offer)
        < 80 → FSM.transition(:icp_revision)
  timeout: 24h

### :build_offer
  trigger: auto
  pipeline:
    - OfferArchitect.invoke(%{icp: $icp, user_input: $user}) → %{offer}
    - BrandVoice.invoke(%{user_content: $user.content}) → %{voice}
    - FSM.transition(:foundations_complete)
  timeout: 24h

### :foundations_complete
  trigger: auto
  pipeline:
    - NotifyUser("Foundations complete. Ready to build assets.")
    - Signal.emit(:foundations_complete, %{icp: $icp, offer: $offer, voice: $voice})
  ## User can now request any marketing/sales/launch skill


## Content Production FSM

### :idle
  trigger: Event.eq(:type, :content_requested)
  pipeline:
    - LoadICP → %{icp}
    - LoadOffer → %{offer}
    - LoadVoice → %{voice}
    - FSM.transition(:producing)

### :producing
  trigger: auto
  pipeline:
    - ContentAgent.invoke(%{type: $request.type, template: $request.template}) → %{draft}
    - QualityGate.invoke(%{signal: $draft, threshold: 0.8}) → %{score, passed}
    - Branch.on(:passed)
        true → FSM.transition(:delivering)
        false → FSM.transition(:revising)
  timeout: 1h

### :revising
  trigger: auto
  max_retries: 2
  pipeline:
    - ContentAgent.invoke(%{draft: $draft, feedback: $score.feedback}) → %{revised}
    - QualityGate.invoke(%{signal: $revised, threshold: 0.8}) → %{score, passed}
    - Branch.on(:passed)
        true → FSM.transition(:delivering)
        false → Branch.on(:retry_count)
            < 2 → :continue (loop)
            >= 2 → EscalateToUser("Content quality threshold not met after 2 revisions")

### :delivering
  trigger: auto
  pipeline:
    - WriteOutput.invoke(%{content: $draft, path: "output/"}) → %{file_path}
    - Branch.on($company.integrations.configured?)
        true → PublishContent.invoke(%{content: $draft, platform: $request.platform})
        false → :skip
    - FSM.transition(:idle)


## Launch FSM

### :planning
  trigger: Event.eq(:type, :launch_requested)
  pipeline:
    - LaunchManager.invoke(%{type: $launch.type}) → %{plan}
    - PARALLEL:
        EmailAgent.invoke(%{type: :launch_sequence, plan: $plan})
        StoryAgent.invoke(%{type: :launch_sequence, plan: $plan})
        AdAgent.invoke(%{type: :retargeting, plan: $plan})
    - FSM.transition(:pre_launch)

### :pre_launch
  trigger: auto
  pipeline:
    - DeployAssets(%{emails: $emails, stories: $stories, ads: $ads})
    - ScheduleSequence(%{start: $plan.start_date})
    - FSM.transition(:live)

### :live
  trigger: Event.eq(:type, :launch_started)
  pipeline:
    - MonitorMetrics(%{funnel: true, email: true, ads: true})
    - AlertOnAnomaly(%{threshold: 20%_deviation})
  timeout: $plan.duration → FSM.transition(:post_launch)

### :post_launch
  trigger: auto
  pipeline:
    - PostLaunchAnalyst.invoke(%{metrics: $metrics}) → %{report}
    - NotifyUser("Launch complete. Report ready.")
    - FSM.transition(:idle)
```

#### MODULES.md — DAG Topology

```markdown
## Module Registry

### FoundationsEngine
  source: WORKFLOW.md → :research, :build_icp, :build_offer
  supervision: permanent
  description: Onboarding pipeline — always available

### ContentFactory
  strategy: union
  children:
    - YouTubeProduction     (when: request.type == :youtube)
    - ShortFormProduction    (when: request.type == :short_form)
    - StoryProduction        (when: request.type == :stories)
    - TwitterProduction      (when: request.type == :twitter)
    - LinkedInProduction     (when: request.type == :linkedin)
    - BlogProduction         (when: request.type == :blog)
    - PodcastProduction      (when: request.type == :podcast)

### SalesEngine
  strategy: pipeline
  children: [LeadQualifier, VSLProduction, FunnelBuilder, EmailSequencer, CRMSync]
  description: Full sales infrastructure build

### LaunchOrchestrator
  strategy: pipeline
  children: [LaunchPlanner, AssetCoordinator, Deployer, MetricsMonitor, PostAnalysis]
  description: End-to-end launch management

### NurtureEngine
  strategy: union
  children:
    - EmailNurture          (when: channel == :email)
    - SMSNurture            (when: channel == :sms)
    - DMNurture             (when: channel == :dm)
    - CommunityNurture      (when: channel == :community)

### GrowthRouter
  strategy: union
  children:
    - FoundationsEngine     (when: event.domain == :foundations)
    - ContentFactory        (when: event.domain == :marketing)
    - NurtureEngine         (when: event.domain == :nurture)
    - SalesEngine           (when: event.domain == :sales)
    - LaunchOrchestrator    (when: event.domain == :launch)
    - ScaleEngine           (when: event.domain == :scale)
  description: Top-level router — classifies and dispatches all requests
```

### Agent Handoff Protocol

Every handoff between agents uses a structured template (never freeform):

```markdown
## Handoff: standard
**From:** {agent_id}  **To:** {agent_id}  **Phase:** {phase}

### Work Completed
[What this agent produced]

### Decisions Made
[Choices that affect downstream work]

### Artifacts Produced
[File paths to outputs]

### Quality Score
- S/N score: {0.0-1.0}
- Signal: S=({M}, {G}, {T}, {F}, {W})

### Context for Next Agent
[What the receiving agent needs to know]

### Open Items
[Anything unresolved]
```

---

## 9. Integration Layer

```
engine/
├── config.yaml                    ← Which backends are active
├── integrations/
│   ├── email.yaml                 ← Beehiiv / ConvertKit / ActiveCampaign
│   ├── funnel.yaml                ← GoHighLevel / {FUNNEL_BUILDER} / Kajabi
│   ├── video.yaml                 ← Bitalytics / Wistia / Vimeo
│   ├── crm.yaml                   ← GoHighLevel / Close / HubSpot
│   ├── social.yaml                ← Buffer / Hypefury
│   ├── ads.yaml                   ← Meta Ads / Google Ads / TikTok Ads
│   ├── dm.yaml                    ← Instagram API / ManyChat
│   ├── calendar.yaml              ← Calendly / GHL Booking
│   ├── payment.yaml               ← Stripe
│   ├── analytics.yaml             ← GA4 / Bitalytics / Funnel analytics
│   └── community.yaml             ← Skool / Circle
└── scripts/
    ├── deploy-funnel.sh
    ├── upload-vsl.sh
    ├── create-email-campaign.sh
    ├── publish-social.sh
    └── health.sh
```

**Integration Config Example:**
```yaml
# engine/integrations/email.yaml
provider: beehiiv
api_url: https://api.beehiiv.com/v2
api_key_env: BEEHIIV_API_KEY
publication_id_env: BEEHIIV_PUB_ID
defaults:
  from_name: "${company.business.name}"
  reply_to: "${company.business.email}"
capabilities:
  - create_campaign
  - schedule_sequence
  - subscriber_management
  - analytics
```

---

## 10. Quality System (Signal Theory)

### Every Output is a Signal

```
S = (Mode, Genre, Type, Format, Structure)

Mode:     How is it perceived? (linguistic, visual, auditory, code, data, mixed)
Genre:    What form does it take? (script, sequence, brief, report, SOP, etc.)
Type:     What does it DO? (direct, inform, commit, decide, express)
Format:   What container? (markdown, video, email, DM, PDF)
Structure: Internal skeleton (the template)
```

### Quality Gate (Triple-Layer Verification)

```
Quality = w1 × formal + w2 × semantic + w3 × info-theoretic

Where:
  formal (40%):     Does it follow the template structure?
                    Are all required sections present?
                    Is it within channel capacity (information theory)?

  semantic (35%):   Does it match the user's brand voice?
                    Does it reference ICP pain points accurately?
                    Is the offer positioned correctly?

  info-theoretic (25%): Does it tell the prospect something they
                        didn't already know? Does it reduce uncertainty?
                        Is there actual insight, not just filler?

Thresholds:
  Client-facing (VSL, email, DM, ad, funnel): S/N >= 0.8
  Internal (research, SOP, report): S/N >= 0.5
  Below threshold: reject → rewrite → recheck (max 2 retries)
```

### The 4-Principle Check

Before ANY output leaves the system:
```
1. information theory: Is it within channel capacity?
   DM = 1-3 sentences. Email = 200-400 words. VSL = 12-30 min.
   If over capacity → compress or split.

2. cybernetics theory: Is the right template being used for this situation?
   Cold lead ≠ warm lead. High-ticket ≠ low-ticket.
   If wrong variety → switch template.

3. viable systems theory: Is this output connected to the broader system?
   Does the VSL feed the funnel? Does the email support the launch?
   If orphaned → connect to workflow.

4. feedback-loop theory: Can we measure if this worked?
   VSL → watch time/heatmap. Email → open/click rate. Ad → ROAS.
   If unmeasurable → add tracking.
```

---

## 11. Build Order & Phases

### Phase 1: Foundations (Week 1-2)
```
Priority: CRITICAL (everything depends on this)

Build:
  ✅ SYSTEM.md
  ✅ company.yaml schema
  ✅ Research Agent + /research skill
  ✅ ICP Builder Agent + /build-icp skill
  ✅ Offer Architect Agent + /design-offer skill
  ✅ Brand Voice Extractor Agent + /extract-voice skill
  ✅ reference/frameworks/icp-scoring.md
  ✅ reference/frameworks/offer-creation.md

Test: One user completes full onboarding flow
Milestone: Foundations FSM runs end-to-end
```

### Phase 2: Core Sales Stack (Week 3-4)
```
Priority: HIGH (this is the demo)

Build:
  ✅ VSL Builder Agent + /build-vsl skill + pull-push-persuade framework
  ✅ 3 VSL templates (archetype, story-driven, case study)
  ✅ Funnel Assets Agent + /build-funnel skill
  ✅ 2 funnel templates (VSL funnel, application funnel)
  ✅ Email Sequence Agent + /email-sequence skill
  ✅ 3 email templates (welcome, nurture, launch)
  ✅ spec/WORKFLOW.md (content production FSM)
  ✅ Quality gate system

Test: "Tell the AI about your business → get a live VSL + funnel + email sequence"
Milestone: Full sales stack in one conversation
```

### Phase 3: Content Engine (Week 5-6)
```
Build:
  ✅ Content Strategist + /content-calendar
  ✅ YouTube Agent + 7 templates
  ✅ Short-Form Agent + 9 templates
  ✅ Story Sequence Agent + 8 templates
  ✅ Twitter/X Agent + 7 templates
  ✅ Content repurposing chain skill

Milestone: 30-day content calendar with all platforms coordinated
```

### Phase 4: DM Sales + Nurture (Week 7-8)
```
Build:
  ✅ DM Sales Agent + 5 sequence types
  ✅ Sales Script Agent + 7 script types
  ✅ Call Prep Agent (unique differentiator)
  ✅ Lead Magnet Agent + 8 types
  ✅ Webinar Agent + 6 event types
  ✅ SMS Agent
  ✅ Setter→Closer handoff protocol

Milestone: Full nurture + sales pipeline automated
```

### Phase 5: Launch + Scale (Week 9-10)
```
Build:
  ✅ Launch Manager + 5 launch types
  ✅ Launch FSM (orchestrates all agents)
  ✅ Post-Launch Analyst
  ✅ SOP Builder + 14 templates
  ✅ Financial Agent
  ✅ Client Retention Agent
  ✅ Case Study Agent

Milestone: End-to-end launch orchestration
```

### Phase 6: Integrations (Week 11-12)
```
Build:
  ✅ engine/integrations/ configs for all providers
  ✅ spec/PROCEDURES.md action bindings
  ✅ Deploy-to-GHL, Beehiiv, Bitalytics, Stripe scripts
  ✅ spec/MODULES.md full DAG topology

Milestone: Agents push output to live platforms
```

---

## 12. Competitive Moat

| Dimension | Cook.ai | Mochi | GHL | Growth Operating Agency |
|-----------|---------|-------|-----|-------|
| **Theory** | None | None | None | Signal Theory |
| **Templates** | Shallow | DM only | Funnel only | 148 structural blueprints |
| **Methodology** | Generic LLM | Setter analytics | Workflow builder | 15 proven frameworks |
| **Quality Gate** | None | Reply rate | None | Triple-layer S/N verification |
| **Scope** | High-ticket only | DM only | CRM + funnels | ALL growth ops A-Z |
| **Coordination** | "Missions" (basic) | None | Workflows (manual) | Spec layer: FSMs + DAG + handoffs |
| **Knowledge** | Generic | None | None | Operator playbooks + swipe files |
| **Portability** | Locked SaaS | Locked SaaS | Locked SaaS | workspace protocol (any runtime) |
| **Examples** | None visible | None | Templates | 2-3 golden examples per template |
| **Feedback Loop** | Basic | Sentence-level DM | Funnel analytics | feedback-loop theory-compliant across ALL channels |

**The moat is NOT the agents. It's the knowledge layer.**

Any competitor can build agents. What they cannot replicate:
1. Your Signal Theory quality framework (published, mathematical)
2. Your 148 structural templates (each encoding optimal methodology)
3. Your operator playbooks (real-world validated by $25M+ operators)
4. Your golden examples (calibration targets for every template)
5. Your swipe files (proven assets with performance data)

---

## 13. Open Questions

These questions must be answered to complete the architecture:

### Product Questions
1. **User #1 profile:** Coach with $5K offer? Agency owner? Growth operator?
2. **Entry point:** $97/mo research-only (like Cook.ai)? Or full access from day 1?
3. **Interface:** Terminal (slash-command runtime) MVP? Or GUI (OSA/the Miosa platform) from launch?
4. **Distribution:** Self-hosted (git clone)? Managed SaaS? Both?

### Technical Questions
5. **Primary CRM/funnel:** Is GoHighLevel the default? Or fully pluggable?
6. **Real-time DM:** Live conversational AI (replace Mochi)? Or template generator?
7. **Voice clones:** Include Mochi-like voice note capability? Or skip?
8. **Video generation:** Integrate HeyGen/Synthesia? Or scripts-only?
9. **Ad platform API:** Direct Meta/Google Ads integration? Or creative-only?

### Knowledge Questions
10. **Growth Operating Agency Super Intelligence Framework:** Encode as core thinking layer for all agents?
11. **Operator playbooks:** Synthesize into one methodology? Or keep separate per operator?
12. **Swipe file sources:** Which proven assets do you have with performance data?

### Business Questions
13. **White-label:** Agency mode where clients resell Growth Operating Agency? (Like Cook.ai)
14. **Pricing model:** Per-workspace? Per-agent? Per-output? Flat monthly?
15. **Which OS verticals after GrowthOS?** Agency OS? Creator OS? SaaS OS? E-commerce OS?

---

## 14. Additions from Gap Analysis

### New Agent: Affiliate & Partnership Agent
```yaml
---
name: Affiliate & Partnership Agent
id: partnerships
role: strategist
title: Partnership & Affiliate Program Manager
reportsTo: orchestrator
budget: 400
adapter: claude_code
signal: S=(linguistic, plan, direct, markdown, partnership-plan)
tools: [read, write, search, web-search]
context_tier: l1
---
```
**Core Mission:**
1. Identify and recruit JV partners, affiliates, and collaborators
2. Build affiliate program structure (commission tiers, swipe copy, tracking)
3. Coordinate co-promotions, bundle deals, and cross-promotions
4. Manage partner communications and performance tracking
5. Pitch podcast guest appearances and PR opportunities

**Templates (4):**
| Template | Purpose |
|----------|---------|
| JV Webinar Proposal | Co-hosted event pitch to potential partners |
| Affiliate Onboarding Kit | Welcome + swipe copy + tracking links + commission structure |
| Podcast Pitch | Guest appearance pitch with talking points + one-sheet |
| Partnership Outreach Sequence | 3-5 email sequence for cold partnership outreach |

### New Skills
| Skill | Command | Agent |
|-------|---------|-------|
| Partnership Outreach | `/partner-outreach <target>` | partnerships |
| Affiliate Setup | `/affiliate-setup` | partnerships |

### Missing Task Coverage (added to existing agents)

These tasks were identified as gaps and are now assigned to existing agents:

| Task Area | Assigned To | How |
|-----------|-------------|-----|
| Email deliverability (SPF/DKIM/DMARC) | Email Sequence Agent | Add `/email-deliverability` diagnostic skill |
| Dunning / failed payment recovery | Financial Agent | Add dunning sequence template |
| Ad creative refresh cycles | Paid Ads Agent | Add to `/ad-creative` process (fatigue detection step) |
| Voice-of-customer research | Research Agent | Add `/voc-research` skill (Reddit, reviews, comments) |
| Post-launch evergreen conversion | Post-Launch Analyst | Add evergreen conversion template to output |
| Client offboarding + referral | Client Retention Agent | Add offboarding + referral ask templates |
| Platform-specific SEO | YouTube, Short-Form, Podcast agents | Add SEO optimization step to each agent's process |
| Quiz/assessment funnels | Lead Magnet Agent | Already in template list; add dedicated `/quiz-funnel` skill |

### the workspace manifest Library Import Map

These agents should be **forked from the the workspace manifest library** and customized:

```
# Copy and customize these agents:
cp library/agents/marketing/content-creator.md       agents/marketing/content-strategist.md
cp library/agents/marketing/twitter-engager.md        agents/marketing/twitter.md
cp library/agents/marketing/linkedin-content-creator.md agents/marketing/linkedin.md
cp library/agents/marketing/tiktok-strategist.md      agents/marketing/short-form.md
cp library/agents/marketing/seo-specialist.md         agents/marketing/seo-blog.md
cp library/agents/marketing/podcast-strategist.md     agents/marketing/podcast.md
cp library/agents/sales/outbound-prospector.md        agents/sales-ops.md
cp library/agents/sales/proposal-writer.md            agents/sales-ops.md
cp library/agents/support/finance-tracker.md          agents/financial-modeler.md
cp library/agents/design/brand-guardian.md            agents/brand-voice.md
cp library/agents/paid-media/creative-strategist.md   agents/marketing/paid-ads.md
cp library/agents/specialized/workflow-architect.md   agents/sop-builder.md
cp library/agents/product/trend-researcher.md         agents/competitor-analyst.md
cp library/agents/specialized/corporate-training-designer.md agents/talent-recruiter.md

# Import these skills directly (no modification needed):
cp -r library/skills/paid-media/    skills/paid-media/
cp -r library/skills/content/       skills/content/
cp -r library/skills/strategy/      skills/strategy/
cp -r library/skills/workflow/      skills/workflow/
cp -r library/skills/coordination/  skills/coordination/
cp -r library/skills/governance/    skills/governance/
cp -r library/skills/learning/      skills/learning/
cp -r library/skills/ai-patterns/   skills/ai-patterns/
```

This gives you **18 paid-media skills**, **7 coordination skills**, **6 learning
skills**, **14 AI reasoning patterns**, **4 strategy skills**, and **5 content
skills** — all production-ready from the the workspace manifest library. That's **54 skills
for free** before you build a single custom one.

---

## Appendix: File Tree

```
growth-os-growth-os/
│
├── SYSTEM.md
├── company.yaml
│
├── agents/
│   ├── foundations/
│   │   ├── research.md
│   │   ├── niche-architect.md
│   │   ├── icp-builder.md
│   │   ├── offer-architect.md
│   │   └── brand-voice.md
│   ├── marketing/
│   │   ├── content-strategist.md
│   │   ├── youtube.md
│   │   ├── short-form.md
│   │   ├── stories.md
│   │   ├── twitter.md
│   │   ├── linkedin.md
│   │   ├── paid-ads.md
│   │   ├── seo-blog.md
│   │   ├── marketing-assets.md
│   │   └── podcast.md
│   ├── nurture/
│   │   ├── email-sequence.md
│   │   ├── lead-magnet.md
│   │   ├── community.md
│   │   ├── webinar.md
│   │   └── sms.md
│   ├── sales/
│   │   ├── vsl-builder.md
│   │   ├── funnel-assets.md
│   │   ├── sales-scripts.md
│   │   ├── dm-sales.md
│   │   ├── call-prep.md
│   │   ├── proposal.md
│   │   └── crm-automation.md
│   ├── launch/
│   │   ├── launch-manager.md
│   │   └── post-launch.md
│   └── scale/
│       ├── sop-builder.md
│       ├── team-builder.md
│       ├── competitor.md
│       ├── financial.md
│       ├── retention.md
│       └── case-study.md
│
├── skills/
│   ├── foundations/
│   │   ├── research/SKILL.md
│   │   ├── define-niche/SKILL.md
│   │   ├── build-icp/SKILL.md
│   │   ├── design-offer/SKILL.md
│   │   └── extract-voice/SKILL.md
│   ├── marketing/
│   │   ├── content-calendar/SKILL.md
│   │   ├── youtube-script/SKILL.md
│   │   ├── short-form/SKILL.md
│   │   ├── story-sequence/SKILL.md
│   │   ├── twitter-thread/SKILL.md
│   │   ├── linkedin-post/SKILL.md
│   │   ├── ad-creative/SKILL.md
│   │   ├── blog-post/SKILL.md
│   │   ├── marketing-asset/SKILL.md
│   │   ├── podcast-outline/SKILL.md
│   │   ├── analyze-competitor/SKILL.md
│   │   └── repurpose/SKILL.md
│   ├── nurture/
│   │   ├── email-sequence/SKILL.md
│   │   ├── lead-magnet/SKILL.md
│   │   ├── community-content/SKILL.md
│   │   ├── webinar-script/SKILL.md
│   │   ├── sms-sequence/SKILL.md
│   │   └── retarget/SKILL.md
│   ├── sales/
│   │   ├── build-vsl/SKILL.md
│   │   ├── build-funnel/SKILL.md
│   │   ├── sales-script/SKILL.md
│   │   ├── dm-sequence/SKILL.md
│   │   ├── call-prep/SKILL.md
│   │   ├── proposal/SKILL.md
│   │   ├── crm-update/SKILL.md
│   │   ├── objections/SKILL.md
│   │   └── sales-stack/SKILL.md
│   ├── launch/
│   │   ├── plan-launch/SKILL.md
│   │   └── launch-report/SKILL.md
│   └── scale/
│       ├── build-sop/SKILL.md
│       ├── hiring-brief/SKILL.md
│       ├── revenue-report/SKILL.md
│       ├── retention-check/SKILL.md
│       ├── case-study/SKILL.md
│       └── competitor-intel/SKILL.md
│
├── reference/
│   ├── frameworks/          (15 methodology files)
│   ├── templates/           (148 structural blueprints)
│   ├── examples/            (50+ golden examples)
│   ├── swipe-file/          (5 proven asset collections)
│   ├── operator-playbooks/  (5 operator methodology files)
│   ├── market-intelligence/ (4 living knowledge files)
│   ├── icp.md
│   ├── offers.md
│   └── brand-voice.md
│
├── workflows/
│   ├── user-onboarding.md
│   ├── content-production.md
│   ├── launch-sequence.md
│   └── client-acquisition.md
│
├── handoffs/
│   ├── standard.md
│   ├── escalation.md
│   └── quality-revision.md
│
├── spec/
│   ├── PROCEDURES.md        (8 action bindings)
│   ├── WORKFLOW.md           (3 FSMs)
│   └── MODULES.md            (6 module compositions)
│
├── engine/
│   ├── config.yaml
│   ├── integrations/        (11 provider configs)
│   └── scripts/             (5 deployment scripts)
│
└── output/
    ├── research/
    ├── content/
    ├── sequences/
    ├── vsl/
    ├── funnels/
    ├── scripts/
    ├── ads/
    ├── sops/
    ├── launches/
    └── reports/
```

---

*This document is itself a Signal:*
```
S = (linguistic + code, spec, direct + inform, markdown, architecture-document)
Source: Growth Operating Agency system architect
Destination: Roberto H Signal Theory (founder) + engineering team
Channel: This markdown file
Noise: Any ambiguity in the above — close the feedback loop by answering
       the questions in Section 13.
```
