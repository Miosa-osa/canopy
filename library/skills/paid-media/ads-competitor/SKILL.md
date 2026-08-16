---
name: ads competitor
description: >
  Competitor ad intelligence analysis across Google, Meta, LinkedIn, TikTok,
  and Microsoft. Analyzes competitor ad copy, creative strategy, keyword
  targeting, estimated spend, and identifies competitive gaps and opportunities.
  Triggers on: "competitor ads", "ad spy", "competitive analysis",
  "competitor PPC", "ad intelligence", "competitor research"
---

# /ads competitor — Competitive Ad Intelligence

> Cross-platform competitor advertising analysis and gap identification.

## Usage

```bash
/ads competitor
/ads competitor --competitors "acme.com, rival.com"
```

## Process

1. Identify target competitors (from user input or industry analysis)
2. Research competitor ad presence across platforms
3. Analyze ad copy, creative, and messaging themes
4. Estimate competitor spend and keyword strategy
5. Identify gaps and opportunities
6. Generate competitive intelligence report

## Data Sources

### Free Intelligence Sources

| Source | Platform | What You Can Find |
|--------|----------|------------------|
| Google Ads Transparency Center | Google | Active ads, formats, geo targeting |
| Meta Ad Library | Meta/Instagram | All active ads, creative, copy, spend range |
| LinkedIn Ad Library | LinkedIn | Active ads from company pages |
| TikTok Creative Center | TikTok | Top ads, trending creative, hashtags |
| Microsoft Ads | Microsoft | Limited — use auction insights |

### Google Ads Auction Insights
Available from the user's own Google Ads account:
- Impression share vs competitors
- Overlap rate (how often you compete)
- Outranking share (who wins more often)
- Top of page rate and absolute top of page rate

### Platform-Specific Research

#### Google
- Ads Transparency Center: search by advertiser name or domain
- Search for competitor brand terms to see their ads live
- Auction Insights for impression share comparison

#### Meta
- Ad Library: filter by advertiser, country, platform (FB/IG), date range
- Shows creative (image/video), ad copy, active dates
- Shows platform placement (Facebook, Instagram, Audience Network)

#### LinkedIn
- Ad Library: search by company name
- Shows Sponsored Content, Message Ads
- Limited data compared to Meta Ad Library

#### TikTok
- Creative Center: top-performing ads by industry, country, objective
- Hashtag analytics: trending sounds and hashtags
- No per-advertiser library — use Creative Center for industry trends

## Competitive Analysis Framework

### 1. Ad Copy Analysis
For each competitor, document:
- **Headlines**: primary messages and value propositions
- **CTAs**: what action they're driving
- **Offers**: pricing, discounts, free shipping, trials
- **Tone**: professional, casual, urgent, educational, emotional
- **USPs**: unique selling propositions they emphasize
- **Pain points**: customer problems they address

### 2. Creative Strategy Analysis
- **Formats used**: image, video, carousel, collection, document
- **Visual style**: photography, illustration, UGC, stock, branded
- **Video approach**: studio quality vs UGC vs animated
- **Creative volume**: how many active ads (indicator of testing velocity)
- **Refresh frequency**: how often new creatives appear

### 3. Messaging Themes

| Theme | Competitor A | Competitor B | Your Brand |
|-------|-------------|-------------|------------|
| Price/Value | Primary | Secondary | ? |
| Quality/Premium | -- | Primary | ? |
| Speed/Convenience | Secondary | -- | ? |
| Trust/Authority | Primary | Primary | ? |
| Innovation | -- | Secondary | ? |

### 4. Keyword Intelligence (Google/Microsoft)
- Brand keyword bidding: are competitors bidding on your brand?
- Keyword overlap: which non-brand terms do you both target?
- Keyword gaps: terms competitors rank for that you don't target
- Match type strategy: estimated match types from ad triggers

### 5. Spend Estimation
- Meta Ad Library shows spend ranges for political/social ads
- Google Auction Insights + impression share = directional spend estimate
- Manual estimation: `Estimated Monthly Spend = Impressions x CPM / 1000`

## Gap & Opportunity Identification

### Platform Gaps
- Which platforms are competitors NOT on? (opportunity to own)
- Which platforms are they underspending on? (opportunity to outspend)

### Messaging Gaps
- What customer pain points are NO competitors addressing?
- What value propositions are underrepresented in the market?
- What content formats are competitors not using?

### Audience Gaps
- What demographics/segments are competitors not targeting?
- What geographic markets are underserved?
- What funnel stages are competitors neglecting?

## Competitive Response Strategy

### When Competitors Bid on Your Brand
- Always run brand campaigns to defend (low CPC, high CTR)
- Dynamic keyword insertion to show your brand prominently
- Sitelinks to key pages (pricing, features, reviews)
- Ad copy that emphasizes unique differentiators

### When You're Outspent
- Focus on efficiency over volume (better targeting, creative, landing pages)
- Target long-tail keywords competitors ignore
- Use Exact match for precision (less waste)
- Double down on retargeting (lower CPA than prospecting)
- Compete on creative quality, not budget

## Output

### Deliverables
- `COMPETITOR-INTELLIGENCE-REPORT.md` — Full competitive analysis
- `COMPETITIVE-GAPS.md` — Opportunities identified from competitor analysis
- Strategic recommendations for competitive positioning
- Priority actions to gain competitive advantage
