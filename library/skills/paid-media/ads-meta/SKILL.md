---
name: ads meta
description: >
  Meta Ads deep analysis covering Facebook and Instagram advertising.
  Evaluates 46 checks across Pixel/CAPI health, creative diversity and fatigue,
  account structure, and audience targeting. Includes Advantage+ assessment.
  Triggers on: "Meta Ads", "Facebook Ads", "Instagram Ads", "Advantage+",
  "Meta campaign", "Meta audit", "FB ads"
---

# /ads meta — Meta Ads Deep Analysis

> 46-check audit of Meta (Facebook/Instagram) advertising accounts.

## Usage

```bash
/ads meta
```

## Process

1. Collect Meta Ads data (Ads Manager export, Events Manager screenshot, EMQ scores)
2. Evaluate all applicable checks as PASS, WARNING, or FAIL
3. Calculate Meta Ads Health Score (0-100)
4. Generate findings report with action plan

## What to Analyze

### Pixel / CAPI Health (30% weight)
- Meta Pixel installed and firing on all pages
- Conversions API (CAPI) active (30-40% data loss without it post-iOS 14.5)
- Event deduplication configured (event_id matching, >=90% dedup rate)
- Event Match Quality (EMQ) >=8.0 for Purchase event
- All standard events configured (ViewContent, AddToCart, Purchase, Lead)
- Custom conversions created for non-standard events
- Aggregated Event Measurement (AEM) configured for iOS
- Domain verification completed
- Server-side events include customer_information parameters
- Pixel fires with correct currency and value parameters

### Creative (30% weight)
- >=3 creative formats active (image, video, carousel, collection)
- >=5 creatives per ad set (Meta recommendation)
- Creative fatigue detection: CTR drop >20% over 14 days = FAIL
- Video creative: 15s max for Stories/Reels, 30s max for Feed
- UGC/testimonial creative tested
- Dynamic Creative Optimization (DCO) tested
- Ad copy: headline under 40 chars, primary text under 125 chars
- Creative refresh cadence: every 2-4 weeks for high-spend

### Account Structure (20% weight)
- Campaign Budget Optimization (CBO) vs Ad Set Budget (ABO) intentional
- Campaign consolidation: <=5 active campaigns per objective type
- Learning phase health: <30% ad sets in "Learning Limited" (FAIL >50%)
- Budget per ad set: >=5x target CPA (minimum for learning phase exit)
- Ad set audience overlap <30% (Audience Overlap tool)
- Campaign naming conventions consistent and descriptive
- Advantage+ Shopping Campaigns (ASC) active for e-commerce
- Simplified campaign structure (fewer, larger ad sets preferred)

### Audience & Targeting (20% weight)
- Prospecting frequency (7-day): <3.0 (WARNING 3-5, FAIL >5)
- Retargeting frequency (7-day): <8.0 (WARNING 8-12, FAIL >12)
- Custom Audiences: website visitors, customer lists, engagement
- Lookalike Audiences: multiple seed sizes tested (1%, 3%, 5%)
- Advantage+ Audience tested vs manual targeting
- Interest targeting: broad enough for algorithm optimization
- Exclusions: purchasers excluded from prospecting, overlap managed

## Advantage+ Assessment

- **ASC (Shopping Campaigns)**: catalog connected, existing customer cap set
- **Advantage+ Audience**: performance vs manual audience compared
- **Advantage+ Creative**: enhancements enabled
- **Advantage+ Placements**: enabled
- **Budget allocation**: Advantage+ campaigns getting fair test budget

## EMQ Optimization Guide

| EMQ Score | Status | Action |
|-----------|--------|--------|
| 8.0-10.0 | Excellent | Maintain current setup |
| 6.0-7.9 | Good | Add more customer_information parameters |
| 4.0-5.9 | Fair | Implement CAPI, improve data quality |
| <4.0 | Poor | Critical: CAPI + Enhanced Matching required |

## Key Thresholds

| Metric | Pass | Warning | Fail |
|--------|------|---------|------|
| EMQ (Purchase) | >=8.0 | 6.0-7.9 | <6.0 |
| Dedup rate | >=90% | 70-90% | <70% |
| CTR | >=1.0% | 0.5-1.0% | <0.5% |
| Creative formats | >=3 | 2 | 1 |
| Creatives per ad set | >=5 | 3-4 | <3 |
| Learning Limited | <30% | 30-50% | >50% |
| Budget per ad set | >=5x CPA | 2-5x CPA | <2x CPA |

## Output

### Deliverables
- `META-ADS-REPORT.md` — Full 46-check findings with pass/warning/fail
- EMQ improvement roadmap
- Creative fatigue alerts
- Quick Wins sorted by impact
- Advantage+ adoption recommendations
