---
name: ads google
description: >
  Google Ads deep analysis covering Search, Performance Max, Display, YouTube,
  and Demand Gen campaigns. Evaluates 74 checks across conversion tracking,
  wasted spend, account structure, keywords, ads, and settings.
  Triggers on: "Google Ads", "Google PPC", "search ads", "PMax",
  "Performance Max", "Google campaign", "Google audit"
---

# /ads google — Google Ads Deep Analysis

> Comprehensive 74-check audit of Google Ads accounts across all campaign types.

## Usage

```bash
/ads google
/ads google --focus pmax
```

## Process

1. Collect Google Ads account data (export, Change History, Search Terms Report)
2. Evaluate all applicable checks as PASS, WARNING, or FAIL
3. Calculate Google Ads Health Score (0-100)
4. Generate findings report with action plan

## What to Analyze

### Conversion Tracking (25% weight)
- Google tag (gtag.js) installed and firing on all pages
- Enhanced Conversions active (hashed first-party data)
- Consent Mode v2 implemented (required for EU/EEA)
- Conversion actions mapped correctly (primary vs secondary)
- Offline conversion import configured (for lead gen)
- Server-side tagging via GTM (recommended for accuracy)
- Attribution model: data-driven preferred (last-click as fallback only)
- Conversion lag analysis (are conversions still trickling in?)

### Wasted Spend (20% weight)
- Search Terms Report reviewed (last 30 days minimum)
- Negative keyword coverage adequate (shared lists + campaign-level)
- Display placement audit (exclude low-quality sites)
- Invalid click rate within norms (<10%)
- Broad Match only used with Smart Bidding (NEVER without it)
- Brand/non-brand campaigns separated
- Geographic targeting precise (no wasted international spend)

**Negative Keyword Rules (critical):**
- NEVER suggest Broad Match negatives unless explicitly justified
- Default to **Exact Match** `[keyword]` for specific irrelevant queries
- Use **Phrase Match** `"keyword"` for irrelevant intent patterns
- Source negatives from actual Search Terms Report, NOT guesses
- Group into themed lists: Informational, Job-seeker, Competitor, Free-intent
- Recommend **Shared Negative Lists** at account level
- Review existing negatives for over-blocking

### Account Structure (15% weight)
- Campaign-level organization follows business logic
- Ad groups themed tightly (15-20 keywords max per group)
- RSA ad groups have >=3 active ads
- PMax campaigns structured correctly (asset groups, signals)
- SKAGs evaluated (migrate to themed groups if present)
- Campaign labels/naming conventions consistent

### Keywords (15% weight)
- Match type strategy appropriate (Exact -> Phrase -> Broad progression)
- Quality Score distribution (aim >=7 average)
- Low QS keywords flagged (<5 = FAIL, 5-6 = WARNING)
- Keyword cannibalization check (same keywords in multiple campaigns)
- Impression share tracked for top keywords

### Ads (15% weight)
- RSA: >=8 unique headlines, >=3 descriptions per ad group
- RSA: ad strength "Good" or "Excellent"
- Pin usage minimal and strategic
- Ad extensions: sitelinks (>=4), callouts (>=4), structured snippets, image
- Dynamic keyword insertion used appropriately

### Settings (10% weight)
- Bid strategy appropriate for campaign maturity and goals
- Budget pacing: no campaigns limited by budget (unless intentional)
- Ad schedule aligned with business hours/conversion patterns
- Device bid adjustments set based on performance data
- Location targeting: "Presence" not "Presence or Interest"
- Network settings: Search Partners reviewed, Display opt-out for Search

## PMax Deep Dive

If Performance Max campaigns exist, additionally evaluate:
- Asset group diversity (text, images, video, feeds)
- Audience signals configured (custom segments, lists, demographics)
- URL expansion settings reviewed
- Brand exclusions applied
- Search themes utilized
- Insights tab reviewed

## AI Max for Search (2026)

If AI Max for Search is available/active:
- Broad Match + AI Max integration evaluated
- Auto-generated headline performance monitored
- Search term categories reviewed for relevance

## Key Thresholds

| Metric | Pass | Warning | Fail |
|--------|------|---------|------|
| Quality Score (avg) | >=7 | 5-6 | <5 |
| CTR (Search) | >=6.66% | 3-6.66% | <3% |
| CVR (Search) | >=7.52% | 3-7.52% | <3% |
| CPC (Search) | <=$5.26 | $5.26-8.00 | >$8.00 |
| Wasted Spend | <10% | 10-20% | >20% |
| Ad Strength | Good+ | Average | Poor |
| Invalid Clicks | <5% | 5-10% | >10% |

## Output

### Deliverables
- `GOOGLE-ADS-REPORT.md` — Full 74-check findings with pass/warning/fail
- Wasted spend estimate (monthly $ value)
- Quick Wins sorted by impact
- PMax-specific recommendations (if applicable)
- Keyword health matrix with QS, CTR, CVR per keyword group
