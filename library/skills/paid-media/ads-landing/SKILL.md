---
name: ads landing
description: >
  Landing page quality assessment for paid advertising campaigns. Evaluates
  message match, page speed, mobile experience, trust signals, form
  optimization, and conversion rate potential.
  Triggers on: "landing page", "post-click experience", "landing page audit",
  "conversion rate", "landing page optimization", "LP audit"
---

# /ads landing — Landing Page Quality Assessment

> Evaluates landing pages specifically for paid ad campaign performance.

## Usage

```bash
/ads landing
/ads landing --url https://example.com/landing
```

## Process

1. Collect landing page URLs from active ad campaigns
2. Assess each landing page for ad-specific quality factors
3. Score landing pages and identify improvement opportunities
4. Generate recommendations prioritized by conversion impact

## Message Match Assessment

The #1 landing page issue in ad campaigns — does the page match the ad?

### What to Check
- **Headline match**: landing page H1 reflects ad copy headline/keyword
- **Offer match**: promoted offer (price, discount, trial) is visible above fold
- **CTA match**: landing page CTA matches ad's promised action
- **Visual match**: consistent imagery between ad creative and page
- **Keyword match**: search keyword appears naturally in page content

### Message Match Scoring

| Level | Description | Score |
|-------|-------------|-------|
| Exact match | Headline, offer, CTA all align perfectly | 100% |
| Partial match | Headline matches but offer/CTA differs | 60% |
| Weak match | Generic page, loosely related to ad | 30% |
| Mismatch | Page content doesn't reflect ad promise | 0% |

## Page Speed Assessment

For every 1s delay, CVR drops ~7%.

| Metric | Pass | Warning | Fail |
|--------|------|---------|------|
| LCP | <2.5s | 2.5-4.0s | >4.0s |
| FID/INP | <100ms | 100-200ms | >200ms |
| CLS | <0.1 | 0.1-0.25 | >0.25 |
| Time to Interactive | <3.0s | 3.0-5.0s | >5.0s |
| Page weight | <2MB | 2-5MB | >5MB |

## Mobile Experience

75%+ of ad clicks come from mobile.

### Mobile Checklist
- Tap targets: >=48x48px with >=8px spacing
- Font size: >=16px body text
- Form fields: properly sized, keyboard type matches input
- CTA button: full-width on mobile, visible without scrolling
- No horizontal scroll
- Images responsive and properly sized
- Phone number clickable (tel: link)
- No interstitials or popups blocking content on load

## Trust Signals

### Above-the-Fold
- Company logo visible
- Social proof (customer count, reviews, ratings)
- Security badges (SSL, payment security, guarantees)
- Recognizable client logos (B2B)

### Below-the-Fold
- Full testimonials with names, photos, companies
- Case study highlights with specific metrics
- Certifications, awards, accreditations
- Privacy policy link

## Form Optimization

| Fields | Expected CVR Impact | Use Case |
|--------|-------------------|----------|
| 1-3 fields | Highest CVR | Top-of-funnel, free offer |
| 4-5 fields | Moderate CVR | Mid-funnel, qualified leads |
| 6-8 fields | Lower CVR | Bottom-funnel, sales-ready |
| 9+ fields | Lowest CVR | Only for high-value offers |

### Best Practices
- Pre-fill fields where possible
- Use multi-step forms for 5+ fields
- Show progress indicator on multi-step forms
- Inline validation
- Submit button text is specific ("Get My Free Quote" not "Submit")

## Landing Page Quality by Platform

| Platform | Key Requirement | Notes |
|----------|----------------|-------|
| Google | QS component: landing page experience | Directly affects ad rank and CPC |
| Meta | Page load speed critical | Slow pages = Meta penalizes delivery |
| LinkedIn | Professional, B2B appropriate | Match LinkedIn's professional context |
| TikTok | Mobile-first mandatory | 95%+ TikTok traffic is mobile |
| Microsoft | Desktop-optimized matters more | Higher desktop % than other platforms |

## Output

### Deliverables
- `LANDING-PAGE-REPORT.md` — Per-page assessment with scores
- Message match analysis per ad-to-page combination
- Page speed improvement priorities
- Mobile experience fixes
- Form optimization recommendations
- Quick Wins sorted by conversion impact
