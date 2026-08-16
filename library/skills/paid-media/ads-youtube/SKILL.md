---
name: ads youtube
description: >
  YouTube Ads specific analysis covering campaign types, creative quality,
  audience targeting, and measurement. Evaluates video ad performance across
  skippable, non-skippable, bumper, Shorts, and Demand Gen formats.
  Triggers on: "YouTube Ads", "video ads", "pre-roll", "bumper ads",
  "YouTube campaign", "Shorts ads", "YouTube audit"
---

# /ads youtube — YouTube Ads Analysis

> Campaign-by-campaign analysis of YouTube advertising across all video formats.

## Usage

```bash
/ads youtube
```

## Process

1. Collect YouTube Ads data (Google Ads export filtered to Video campaigns)
2. Evaluate campaign setup, creative quality, targeting, and measurement
3. Generate YouTube-specific findings report with health score

## Campaign Types Assessment

### Skippable In-Stream (TrueView)
- Length: 12s minimum, 15-30s recommended
- Bidding: Target CPV or Target CPA
- Skip rate benchmark: 65-80% is normal
- View rate: >=15% is good
- Evaluate: hook quality in first 5 seconds, CTA card usage

### Non-Skippable In-Stream
- Length: up to 60s (expanded 2025)
- Bidding: Target CPM
- Best for: brand awareness, reach campaigns
- Evaluate: message completeness, frequency capping

### Bumper Ads
- Length: exactly 6s (non-skippable)
- Bidding: Target CPM
- Best for: reach extension, brand reinforcement
- Evaluate: single-message focus, brand visibility

### YouTube Shorts Ads
- Format: vertical 9:16 (1080x1920)
- Length: up to 60s
- Best for: younger demographics, mobile-first
- Evaluate: native feel, sound-on optimization

### Demand Gen (replaces Discovery)
- Placements: YouTube Home Feed, Watch Next, Discover, Gmail
- Formats: image + video carousel, product feeds
- Evaluate: creative diversity, audience signals

## Creative Quality Assessment

### Hook Analysis (First 5 Seconds)
- Does the video capture attention immediately?
- Brand mention within first 5 seconds (awareness)
- Problem/benefit statement upfront (performance)
- No slow intros, title cards, or logos-only openings

### Production Quality
- Audio quality: clear, professional
- Visual quality: HD minimum (1080p)
- Subtitles/captions present
- End screen: CTA, subscribe button, related video cards

### Creative Volume
- >=3 video variations per campaign
- Mix of lengths tested (6s + 15-60s + 30s)
- Vertical (9:16) and horizontal (16:9) versions
- Refresh cadence: every 4-8 weeks

## Audience Targeting

- **Custom Intent**: target users searching for specific terms
- **In-Market Audiences**: users actively researching
- **Affinity Audiences**: broad interest-based (awareness)
- **Customer Match**: first-party list retargeting
- **Placement Targeting**: specific channels, videos, topics
- Frequency capping: 3-5/week awareness, 1-2/week DR

## Key Metrics

| Metric | Benchmark | Notes |
|--------|-----------|-------|
| View Rate (skippable) | >=15% | Higher = better hook |
| CPV (skippable) | $0.01-0.10 | Varies by targeting |
| VTR (bumper) | 90%+ | Non-skippable |
| CPM (non-skip) | $6-15 | Varies by market |
| CTR (Demand Gen) | >=0.5% | Image+video combined |

## Attribution Considerations

- YouTube is upper/mid-funnel — don't judge by last-click alone
- Use data-driven attribution in Google Ads
- Track view-through conversions (important for video)
- Cross-channel impact: YouTube often assists Search/Shopping

## Health Score Weights

| Category | Weight |
|----------|--------|
| Creative Quality | 30% |
| Campaign Setup | 25% |
| Audience Targeting | 25% |
| Measurement | 20% |

## Output

### Deliverables
- `YOUTUBE-ADS-REPORT.md` — Campaign-by-campaign analysis
- Creative quality scorecard per video
- Audience strategy recommendations
- Measurement gap analysis
- Quick Wins for immediate improvement
