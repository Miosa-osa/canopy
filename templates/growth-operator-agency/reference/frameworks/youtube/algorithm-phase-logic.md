# YouTube Algorithm Phase Logic

> **Why this matters:** The same video can succeed or fail based on which algorithm phase it triggers. Creators who publish without understanding how the algorithm grades videos hour-by-hour, day-by-day, year-by-year — waste 80% of their content's potential lifespan.

## Source / Lineage

- Derral Eves (YouTube Algorithm)
- TubeBuddy + VidIQ documented algorithm studies
- the content OS director (phase-aware publishing)
- 2024–2026 YouTube analytics internal operator tracking

---

## The 6 Algorithm Phases

YouTube's ranking system evaluates videos differently at each phase. A video passes through phases sequentially — and gets stuck at whichever phase it fails.

| Phase | Timeframe | What's Measured | What Creator Does |
|-------|-----------|-----------------|-------------------|
| 1. Publish | 0–2 hours | Initial pickup, subscriber alert CTR | Publish clean, notify subs |
| 2. Small Audience Test | 2–24 hours | CTR + first-hour retention | Nothing (don't edit yet) |
| 3. Browse / Home | 1–7 days | CTR + session contribution | Optional thumbnail A/B swap |
| 4. Suggested | 3–14 days | Session time + relevance to other watches | Create connected videos |
| 5. Search | Day 7+ | SEO relevance + retention on searcher intent | Optimize description, tags |
| 6. Evergreen | 30+ days | Sustained retention + cross-referrals | Refresh thumbnail annually |

---

## Phase 1 — Publish (0–2 hours)

### What YouTube is measuring

- Subscriber notification CTR (the % of subs who see the notification and click)
- First 15-minute retention
- Early comments, likes, shares

### What wins here

- A strong subscriber base that actually clicks notifications (the channel's "earned audience")
- A hook that holds the first 30 seconds
- Initial social signal (comments/likes within first hour)

### What kills videos here

- Publishing during low-activity windows for your audience
- Title-thumbnail mismatch that fools subscribers into clicking and bouncing
- Technical issues (bad audio, wrong aspect ratio) that triggers immediate drop-off

### Creator actions

- Publish during peak audience hours (check analytics for your channel's peak window)
- Pin a comment with a question 5 minutes after publish to seed engagement
- Share to email list + other platforms to seed initial views
- Do NOT edit title or thumbnail in first 2 hours — YouTube reads that as instability

### Benchmarks

- Subscriber CTR: 4–10% (notifications are turned on by ~5–15% of subs)
- First-hour retention: >55% at the 50% mark

---

## Phase 2 — Small Audience Test (2–24 hours)

### What YouTube is measuring

YouTube is running a controlled experiment: it shows your video to a small test audience beyond your subscribers. It measures:
- CTR from impressions
- Watch time per impression
- Whether the video leads to another session event
- Signals of relevance (was the click from someone who watches similar content?)

### What wins here

- CTR above the channel's trailing average
- Retention above the channel's trailing average
- Videos that generate comments ("this is the one I needed") — positive sentiment

### What kills videos here

- Low CTR from non-sub browse impressions
- Drop-off before 50% — tells YouTube the video failed the viewer
- Negative sentiment in early comments ("this is clickbait")

### Creator actions

- Don't touch the video
- Monitor analytics but don't react to noise
- If CTR is below 2% after 6 hours, consider swapping thumbnail (only after 6 hours, not earlier)

### Benchmarks

- CTR: 4–8% for most channels; 8–12% for strong
- Average view duration (AVD): target varies by video length (see `length-calibration.md`)

---

## Phase 3 — Browse / Home (1–7 days)

### What YouTube is measuring

If the video passed Phase 2, YouTube expands distribution to Browse (home page) for a broader audience. It measures:
- Whether broader audiences also hold retention
- Whether this video successfully initiates viewing sessions
- CTR decay (sustains or drops?)

### What wins here

- Session-starter properties (see `session-starter-strategy.md`)
- Consistent retention across broader audience
- Strong end-screen click-through — meaning viewers continue watching the channel

### What kills videos here

- Retention falls when the broader audience hits (common for niche topics)
- Video doesn't lead to another session — dead-end content

### Creator actions

- If performance is strong: promote via email, social channels, other videos' end-cards
- If performance is weakening: thumbnail A/B test is now fair game
- Plan the "next video in the series" to capture the now-warm audience

### Benchmarks

- CTR from browse: 5–10% for strong
- % of viewers watching 2+ videos from your channel: target >25%

---

## Phase 4 — Suggested (3–14 days)

### What YouTube is measuring

If the video passed Phase 3, YouTube starts recommending it from the "Up Next" / Suggested panel on other people's videos. It measures:
- Session-time contribution (does this video extend the overall viewing session?)
- Relevance — is it being suggested on videos that logically relate?
- Completion rate (retention full-end)

### What wins here

- High session-time generated per view
- Explicit mid-video and end-card links to related videos
- Content that LOGICALLY connects to other videos — same topic, same creator ecosystem, same audience

### What kills videos here

- Video ends and the viewer bounces to a different channel
- No clear "next thing to watch" from your ecosystem
- Topic is too isolated — nothing else for the algorithm to suggest it from

### Creator actions

- Build 2–3 "connected" videos explicitly in the same topic cluster
- End-card to the most-watched video that shares this video's audience
- Internal playlists with this video as the anchor

### Benchmarks

- % of views from "Suggested" source: 30–50% for healthy channels
- Views-per-suggestion-impression: 6–12%

---

## Phase 5 — Search (Day 7+)

### What YouTube is measuring

Once a video has enough data, YouTube indexes it for search. It measures:
- Click-through from search results pages
- Retention by searchers (often LOWER than browse viewers because searchers have narrower intent)
- Whether the video answers the specific search query

### What wins here

- Titles that match search intent (include keyword phrases)
- Descriptions that reinforce keyword context
- Chapter markers — YouTube pulls these into search snippets
- Closed captions — searchable

### What kills videos here

- Clickbait titles that don't match search intent
- No keyword discipline in title/description
- Retention collapse when search viewers realize the video isn't about what they searched

### Creator actions

- Once the video is 7+ days old, optimize description for long-tail keywords
- Add timestamps (chapters)
- Ensure accurate closed captions
- Pin a comment that addresses the top search-intent question

### Benchmarks

- % of views from search: varies wildly by topic (tutorials 40%+; opinion content 5%)
- Retention for search viewers: usually 10–20% lower than browse — acceptable

---

## Phase 6 — Evergreen (Day 30+)

### What YouTube is measuring

After 30 days, a video either enters "evergreen" status (sustained daily views) or fades. YouTube measures:
- Sustained daily view rate
- Continued session contribution
- Cross-referral from other videos

### What wins here

- Topics with stable search volume (tutorials, frameworks, how-to)
- Strong session-starter properties
- Content still relevant in 6 months (not tied to a specific date or trend)

### What kills videos here

- Topic fades (trending news, dated references)
- Better videos on the same topic appear (yours gets outranked)
- Thumbnail feels visually dated compared to current channel style

### Creator actions

- Annually: refresh the thumbnail of top evergreen videos
- Every 18 months: consider a re-record of high-value evergreen topics
- Ensure description + chapters stay updated
- Use evergreen videos as end-card destinations for new uploads

### Benchmarks

- Evergreen videos should maintain 30–80% of peak daily views indefinitely
- Top 10% of evergreens on a channel produce 40–60% of long-term channel revenue

---

## Phase-Specific KPI Cheat Sheet

| Metric | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Phase 6 |
|--------|---------|---------|---------|---------|---------|---------|
| CTR (target) | 6%+ | 5%+ | 5%+ | 5%+ | 4%+ | 4%+ |
| AVD (target) | 45%+ | 45%+ | 45%+ | 50%+ | 40%+ | 40%+ |
| End-card CTR | n/a | 5%+ | 7%+ | 9%+ | 5%+ | 5%+ |
| Session contribution | n/a | +1 | +1.5 | +2 | +1 | +1.5 |

---

## The 24-Hour Rule

In the first 24 hours after publish, every metric YouTube measures against the channel's trailing 30-day average. If this video performs better than average, the algorithm expands distribution. If worse, it stops distribution.

This means: **a channel's own past performance is its grading curve.** A video that would have been a win for a small channel can fail for a large channel because the bar is higher.

Implication: if your channel has 3 huge viral hits, your algorithm bar is now very high for anything else you publish. Counter-strategy: publish a smaller-scope video first after a hit to reset the baseline, rather than trying to top the viral video every time.

---

## Diagnostic: Where Did My Video Get Stuck?

Pull YouTube Analytics and answer these:

- **Did it pass Phase 1?** Check subscriber notification CTR. Below 3% = sub base isn't engaged.
- **Did it pass Phase 2?** Check first-24-hour CTR + AVD vs. channel average.
- **Did it pass Phase 3?** Check "Browse" as a traffic source after day 2. If <20%, didn't enter browse.
- **Did it pass Phase 4?** Check "Suggested" as a traffic source after day 7. If <25%, didn't enter suggested.
- **Did it pass Phase 5?** Check "Search" as a traffic source after day 14. If <10%, search indexing failed.
- **Is it evergreen?** Check views at day 60 vs. day 30. If <50% of day-30 daily rate, it's fading.

Find the phase where it got stuck, and the fix is usually within that phase's mechanics.

---

## How this applies in Growth Operating Agency

- Skill that consumes this: `/audit-youtube-video`, `/diagnose-youtube-dropoff`
- Agent that uses it: `youtube-producer`, `channel-analyst`
- When to reference: After every publish (48-hour check) + monthly channel review

## Non-applicable scenarios

- Unlisted / private videos (no phase progression)
- Shorts (different algorithm entirely — see `shorts-mrbeast-strategy.md`)
- Live streams (different ranking)
- Premieres (phase timing compressed)

## Cross-references

- `reference/frameworks/youtube/title-thumbnail-patterns.md`
- `reference/frameworks/youtube/5-phase-psychology.md`
- `reference/frameworks/youtube/session-starter-strategy.md`
- `reference/frameworks/youtube/binge-loop-mechanic.md`

---
*v1.0 — 2026-04-19 — YouTube framework canonical.*
