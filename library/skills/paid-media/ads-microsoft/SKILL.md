---
name: ads microsoft
description: >
  Microsoft/Bing Ads deep analysis covering search, Performance Max, Audience
  Network, and Copilot integration. Evaluates 20 checks with focus on Google
  import validation, unique Microsoft features, and cost advantage assessment.
  Triggers on: "Microsoft Ads", "Bing Ads", "Bing PPC", "Copilot ads",
  "Microsoft campaign", "Bing audit"
---

# /ads microsoft — Microsoft Ads Deep Analysis

> 20-check audit of Microsoft (Bing) Ads with Google import validation and Copilot assessment.

## Usage

```bash
/ads microsoft
```

## Process

1. Collect Microsoft Ads data (account export, UET tag status, import results)
2. Evaluate all applicable checks as PASS, WARNING, or FAIL
3. Calculate Microsoft Ads Health Score (0-100)
4. Generate findings report with action plan

## What to Analyze

### Technical Setup (25% weight)
- UET tag installed and firing on all pages (MS01)
- Enhanced conversions enabled (MS02)
- Google Ads import validated: URLs, extensions, bids, goals (MS03)

### Syndication & Bidding (20% weight)
- Search partner network reviewed, low-performers excluded (MS04)
- Audience Network enabled only if testing intentionally (MS05)
- Bid targets 20-35% lower than Google (CPC advantage) (MS06)
- Target New Customers enabled for PMax (MS07)

### Campaign Structure (20% weight)
- Campaign structure mirrors Google or follows best practices (MS08)
- Budget proportional to Bing volume: typically 20-30% of Google (MS09)
- LinkedIn profile targeting for B2B — unique advantage (MS10)

### Creative & Extensions (20% weight)
- RSA: >=8 headlines, >=3 descriptions (MS11)
- Multimedia Ads tested — unique rich format (MS12)
- Ad copy optimized for Bing demographics (MS13)
- Action Extension utilized — unique to Microsoft (MS19)
- Filter Link Extension tested (MS20)

### Settings & Performance (15% weight)
- Copilot chat placement enabled for PMax: 73% CTR lift (MS14)
- Conversion goals configured natively (MS15)
- CPC 20-40% lower than Google for same keywords (MS16)
- CVR comparable to Google, not >50% lower (MS17)
- Impression share tracked for brand and top terms (MS18)

## Google Import Validation

### What Transfers Correctly
- Campaign structure and ad groups
- Keywords and match types
- RSA headlines and descriptions
- Basic bid strategies

### What Needs Manual Review
- **URLs**: verify all landing page URLs are correct post-import
- **Extensions**: not all Google extensions have Microsoft equivalents
- **Bid amounts**: should be 20-35% lower
- **Conversion goals**: re-create natively for better tracking
- **Audiences**: verify all are present
- **Negative keywords**: verify shared negative lists transferred

## Copilot Integration

- Available in Performance Max campaigns
- 73% CTR lift reported in chat placement
- Copilot Checkout launched Jan 2026 (in-chat purchase)
- Evaluate: is Copilot placement enabled? What % of traffic comes from it?

## Microsoft-Unique Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Multimedia Ads | Image-rich search ads | Medium |
| Action Extension | CTA button in search ad | Medium |
| Filter Link Extension | Filterable category links | Low |
| LinkedIn Profile Targeting | Target by company, industry, job function | High (B2B) |
| Copilot Chat Placement | Ads within Copilot conversations | High |

## Key Thresholds

| Metric | Pass | Warning | Fail |
|--------|------|---------|------|
| CTR (Search) | >=2.83% | 1.5-2.83% | <1.5% |
| CPC (Search) | <=$1.55 | $1.55-2.50 | >$2.50 |
| CPC vs Google | 20-40% lower | 10-20% lower | Same or higher |
| CVR vs Google | Within 20% | 20-50% lower | >50% lower |
| Impression share (brand) | >=80% | 60-80% | <60% |

## Output

### Deliverables
- `MICROSOFT-ADS-REPORT.md` — Full 20-check findings with pass/warning/fail
- Google import validation results
- Copilot integration readiness assessment
- Cost advantage analysis (CPC savings vs Google)
- Microsoft-unique feature adoption checklist
- Quick Wins sorted by impact
