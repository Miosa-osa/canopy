---
name: write-x-thread
description: Produce X/Twitter thread in one of 7 thread types (Thread / Story Thread / Hot Take / How-To Thread / Listicle Thread / Case Study Thread / Daily Tweets batch). Specificity-first, open-curiosity-loop structure, final-tweet CTA. 2-3 threads per week.
signal:
  mode: linguistic
  genre: x-thread
  type: inform
  format: markdown
  structure: w-x-thread-7-type
  receiver: X audience + algorithm
  receiver_capacity: low-to-medium
department: marketing
agent_affinity: [marketing-head, twitter-writer]
required_compartments:
  audience_intelligence_system: 50
  offer_architecture: 30
  copy_messaging: 30
upstream_dependency: content-calendar
execution_mode: interactive
tier: structured_ai
temperature_gate: warm
required_tools: [file_read, file_write]
required_mcps: [filesystem]
required_integrations:
  social_posting: twitter-api
  scheduling: buffer-api
  analytics: twitter-analytics
credentials_required: [TWITTER_BEARER_TOKEN, TWITTER_API_KEY, TWITTER_API_SECRET, TWITTER_ACCESS_TOKEN, TWITTER_ACCESS_SECRET]
evidence_gate:
  - thread_type_selected
  - hook_tweet_specificity_gte_8
  - tweet_count_calibrated
  - final_cta_tweet_present
  - char_limits_respected
  - voice_matched
  - signal_score_gte_0_8
keywords:
  - twitter thread
  - x thread
  - write thread
  - twitter post
priority: 1
version: 1.0
---

# /write-x-thread — X/Twitter Thread (7 Types)

## Role

Produce X/Twitter threads in 7 canonical types. Lineage: Marketing department (7 thread types), direct-response X operators, content-to-conversion bridge applied to async-skim platform.

## The 7 Thread Types

| # | Type | Use |
|---|---|---|
| 1 | **Thread (standard)** | General teaching / analysis |
| 2 | **Story Thread** | Narrative with tension + reveal |
| 3 | **Hot Take** | Contrarian positioning, polarizing |
| 4 | **How-To Thread** | Step-by-step actionable |
| 5 | **Listicle Thread** | Ranked/numbered items |
| 6 | **Case Study Thread** | Real client result walkthrough |
| 7 | **Daily Tweets (batch)** | 5-7 single tweets for the week |

## Structure

```
Tweet 1 (HOOK)   — 280 chars max, 120-200 ideal, earns the open
Tweets 2-N (BODY) — each tweet = 1 idea, paragraph-style, save-optimized
Final tweet (CTA) — single action
Optional: reply-to-thread — link / lead magnet / offer mention
```

Tweet count calibrated by type:
- Thread / How-To: 7-12 tweets
- Story Thread: 10-15 tweets
- Hot Take: 3-5 tweets
- Listicle: 6-11 tweets (5-10 items + hook + CTA)
- Case Study: 8-14 tweets
- Daily Tweets: 5-7 standalone tweets (batch output, not a thread)

## Decision Logic

### Hook Tweet Invariants
- First line earns the click (first 50 chars visible on some clients)
- Specificity ≥ 8
- Number or named-entity or bold claim
- Opens a loop or promises specific value
- NEVER "A thread 🧵" as the whole hook — that's lazy

### Engagement Patterns (X-specific)
- Replies > likes (signal value)
- Bookmarks > replies (highest value — means they'll return)
- Threaded replies are decay-prone — main thread matters most
- Quote-tweets expand reach

### Format Choices
- **Image in hook tweet:** 15-30% reach boost for some accounts (test)
- **Video in hook tweet:** higher engagement, longer dwell
- **Text-only:** still works for authority/hot takes
- **Poll hook tweet:** engagement-heavy, less save-ability

### Voice-Match
- 3+ `phrases_to_use` across thread
- Creator's sentence rhythm preserved
- Banned vocabulary swept

### The Final-Tweet CTA
Single action:
- "Follow for more"
- "DM me for the playbook"
- "Link to full breakdown" (in reply, not in thread body)
- "Book a call" (for offer-tied threads only — 20% rule)

## Tacit Principles

1. **First 50 chars visible on many clients.** Hook must open in that window.

2. **Save-optimize** — threads that get bookmarked get re-surfaced. Structured lists + frameworks + checklists.

3. **One idea per tweet.** Don't cram. Threadability = readability.

4. **Polarize for hot takes.** Mild takes get zero traction.

5. **Story threads need tension.** Arrival → Adversity → Aftermath (Jenny Hoyos 3-A).

6. **No external link in thread body.** Link in last tweet or in reply.

7. **Quote-tweet your own thread** 24-48h later with a takeaway — 2× reach.

8. **Batch daily tweets on one topic.** 5 tweets around one theme > 5 random tweets.

9. **Reply to commenters** within 1-2 hours of posting.

10. **Don't over-thread.** 15+ tweets = drop-off steep. 7-12 is the sweet spot.

## Process

### Phase 0 — Load
- Calendar brief, compartments 1-5, voice doc
- `reference/frameworks/primitives/specificity.md`

### Phase 1 — Thread Type Selection
Per calendar brief pillar + stage. Or `--type=1-7`.

### Phase 2 — Hook Tweet
Draft 3-5 variants. Specificity ≥ 8. Select primary.

### Phase 3 — Body Draft
Per type:
- **Thread:** 1 idea per tweet, 7-12 total, logical progression
- **Story:** 3-A structure spread across 10-15 tweets
- **Hot Take:** 3-5 tweets — premise + support + sharpest point
- **How-To:** numbered steps, 7-12 tweets
- **Listicle:** countdown or ascending numbered list, 5-10 items
- **Case Study:** specific outcome → context → journey → mechanism → takeaway
- **Daily Tweets:** 5-7 standalone tweets on one theme (batch)

### Phase 4 — Final CTA Tweet
Single action. No stack of asks.

### Phase 5 — Voice-Match + Compliance
- 3+ phrases_to_use
- Banned vocab swept
- No income guarantees
- Specificity check per tweet

### Phase 6 — Visual Decisions
- Image/video in hook tweet (optional but tested)
- GIFs sparingly (not in every tweet)

### Phase 7 — Publishing Plan
- Optimal times: 9-11am + 6-8pm ET (adjust per audience tz)
- Reply-to-thread 24-48h later for lift
- Quote-tweet with takeaway 48-72h later

## Output Format

```markdown
# X Thread — [Creator Brand] — [Topic]

**Calendar Brief ID:** [e.g. W1-TW-1]
**Thread Type:** [1 Thread | 2 Story | 3 Hot Take | 4 How-To | 5 Listicle | 6 Case Study | 7 Daily Tweets]
**Tweet Count:** [N]
**Hook Specificity:** [N/10]
**Publish Time:** [window]
**Version:** 1.0

---

## Thread

### Tweet 1 — HOOK (⬇️ indicator included)
```
[hook copy — 120-200 chars, visible on first line, ends with "🧵" or "⬇️" or number indicator]
```

### Tweet 2
```
[one idea, 180-280 chars]
```

### Tweet 3
```
[...]
```

...

### Final Tweet — CTA
```
[single action — "Follow for more" | "DM me 'X'" | "Full breakdown: [link]"]
```

---

## Reply-to-Thread (scheduled T+24-48h)
```
[takeaway tweet — quotes own thread, drops 1 more insight, re-surfaces]
```

## Quote-Tweet Plan (T+48-72h)
```
[quote own hook with takeaway]
```

---

## Hook Variants (not selected)
1. [variant 1]
2. [variant 2]

## Voice-Match Audit
- phrases_to_use placements: [count]
- Banned vocabulary: [clean]

## Compliance
- [ ] No income guarantees
- [ ] Specificity ≥ 8 on hook
- [ ] FTC disclosure if testimonials

## Publishing Plan
- Publish time: [date + window]
- Reply-to-thread: T+24-48h
- Quote-tweet: T+48-72h
- Engagement block: T+0 to T+90 min

## Repurpose Chain
- Derivative 1: /write-linkedin-post
- Derivative 2: /write-reel (thread main insight as short)
- Derivative 3: /email-sequence (broadcast referencing thread)

---

## Appendix A — Thread structure diagram
[visual of tweet-by-tweet narrative flow]

## Appendix B — Per-tweet save-ability audit
[which tweets most bookmark-able]
```

## Important Rules

- **NEVER exceed 15 tweets in a single thread** (steep drop-off).
- **NEVER "A thread 🧵" as the whole hook.**
- **NEVER external link in thread body** — final tweet or reply.
- **NEVER stack multiple CTAs.**
- **ALWAYS hit specificity ≥ 8 on hook.**
- **ALWAYS 1 idea per tweet.**
- **ALWAYS reply-to-thread 24-48h for lift.**
- **ALWAYS voice-match.**

## Verification Checklist

- [ ] Thread type selected
- [ ] Hook specificity ≥ 8
- [ ] Tweet count calibrated to type
- [ ] 1 idea per tweet
- [ ] Character limits respected (280 max, 180-280 ideal)
- [ ] Final CTA tweet — single action
- [ ] Reply-to-thread scheduled
- [ ] Quote-tweet plan scheduled
- [ ] Voice-matched (3+ phrases_to_use)
- [ ] Compliance passed
- [ ] Triple-layer S/N ≥ 0.8

## Next Skills

- `/write-linkedin-post` — derivative
- `/write-reel` — short-form version
- `/email-sequence` — broadcast reference

## References

- Marketing department Department (7 thread types)
- `reference/frameworks/primitives/specificity.md`
- `reference/canonical/spec/INTEGRATIONS.md` (Twitter API)

---

*Version 1.0 — 2026-04-19. Cycle 3 Attention — X/Twitter.*
