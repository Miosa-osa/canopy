---
name: ads plan
description: >
  Strategic paid advertising planning with industry-specific templates.
  Covers platform selection, campaign architecture, budget planning,
  creative strategy, and phased implementation roadmap.
  Triggers on: "ad plan", "ad strategy", "campaign planning", "media plan",
  "PPC strategy", "advertising plan", "media strategy"
---

# /ads plan — Strategic Paid Advertising Plan

> End-to-end advertising strategy with platform selection, campaign architecture,
> budget planning, creative strategy, and phased implementation roadmap.

## Usage

```bash
/ads plan
/ads plan --industry saas
/ads plan --budget 10000
```

## Process

### 1. Discovery
- Business type, products/services, target audience
- Current advertising status (active platforms, spend, performance)
- Goals: brand awareness, lead generation, e-commerce sales, app installs
- Budget range (monthly/quarterly)
- Timeline and urgency
- In-house team capacity vs agency needs

### 2. Competitive Analysis
- Identify top 3-5 competitors
- Analyze ad presence across platforms (Google Ads Transparency, Meta Ad Library)
- Estimate competitor spend levels and platform mix
- Identify messaging themes and creative approaches
- Note keyword/audience gaps

### 3. Platform Selection

Match business type to recommended platform mix:

| Business Type | Primary | Secondary | Testing |
|---------------|---------|-----------|---------|
| SaaS B2B | Google Search, LinkedIn | Meta, YouTube | TikTok, Microsoft |
| E-commerce | Google Shopping, Meta | TikTok, YouTube | Microsoft, LinkedIn |
| Local Service | Google Search, Google LSA | Meta | Microsoft, YouTube |
| B2B Enterprise | LinkedIn, Google Search | Meta | Microsoft, TikTok |
| Info Products | Meta, YouTube | Google Search | TikTok |
| Mobile App | Meta, Google UAC | TikTok | Apple Search Ads |

### 4. Campaign Architecture

**Naming Convention:** `[Platform]_[Objective]_[Audience]_[Geo]_[Date]`

```
Account
-- Brand Campaign (always-on)
-- Non-Brand Prospecting
   -- Top Funnel (Awareness)
   -- Mid Funnel (Consideration)
   -- Bottom Funnel (Conversion)
-- Retargeting
   -- Website Visitors (7-30 days)
   -- Engaged Users
   -- Cart Abandoners / Form Starters
-- Testing
   -- New audiences, formats, messaging
```

### 5. Budget Planning (70/20/10)

| Tier | Allocation | Purpose |
|------|-----------|---------|
| Proven (70%) | Primary platforms with proven ROI | Revenue engine |
| Scaling (20%) | Platforms showing promise | Growth engine |
| Testing (10%) | New platforms or strategies | Innovation |

### 6. Creative Strategy

#### Content Pillars
- **Pain Point**: address specific problems
- **Social Proof**: testimonials, case studies, reviews
- **Product Demo**: show the product in action
- **Offer**: promotions, free trials, lead magnets
- **Education**: teach something valuable

#### Production Priority

| Priority | Asset Type | Platforms | Quantity |
|----------|-----------|-----------|----------|
| P1 | Product/service videos (15-30s) | Meta, TikTok, YouTube | 5-10 |
| P2 | Static images with copy | Google, Meta, LinkedIn | 10-15 |
| P3 | Carousel/collection | Meta, LinkedIn | 3-5 |
| P4 | UGC/testimonial video | TikTok, Meta | 3-5 |
| P5 | Long-form video (1-3 min) | YouTube | 2-3 |

### 7. Tracking Setup

| Platform | Client-Side | Server-Side | Priority |
|----------|------------|-------------|----------|
| Google | gtag.js | Enhanced Conversions, GTM SS | P1 |
| Meta | Pixel | CAPI | P1 |
| LinkedIn | Insight Tag | CAPI (2025) | P2 |
| TikTok | Pixel | Events API + ttclid | P2 |
| Microsoft | UET Tag | Enhanced Conversions | P2 |

### 8. Implementation Roadmap

- **Phase 1 (Weeks 1-2)**: Foundation — tracking, structure, audiences, first creative batch
- **Phase 2 (Weeks 3-4)**: Launch — primary platforms, conservative budgets, daily monitoring
- **Phase 3 (Weeks 5-8)**: Optimize — analyze data, adjust bidding, kill underperformers, A/B test
- **Phase 4 (Weeks 9-12)**: Scale — scale winners (20% rule), expand to testing platforms

## Output

### Deliverables
- `ADS-STRATEGY.md` — Complete strategic advertising plan
- `CAMPAIGN-ARCHITECTURE.md` — Campaign structure with naming conventions
- `BUDGET-PLAN.md` — Budget allocation with monthly pacing
- `CREATIVE-BRIEF.md` — Creative production plan
- `TRACKING-SETUP.md` — Tracking implementation checklist
- `IMPLEMENTATION-ROADMAP.md` — Phased rollout timeline
