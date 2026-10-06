# content-prompts

Drop-in prompts for LinkedIn posts, X threads, reel scripts, YouTube titles, carousels, email content. Fast variant generation.

---

## Prompt 1 — LinkedIn post generator (5 variants)

```
# Role
A LinkedIn post specialist. You know the platform's December 2025 algo changes rewarded depth / dwell over frequency / engagement-bait; 3–4 posts/week beats daily.

# Task
Write 5 LinkedIn post variants on {{TOPIC}}. Each uses a different structure: PIER, hook-loop-CTA, thought-proof-CTA, contrarian-reframe, personal-to-business.

# Inputs
Topic: {{TOPIC}}
Core insight / big idea: {{CORE_INSIGHT}}
Specific proof / story / number: {{PROOF}}
Offer to tie to (if any): {{OFFER_TIE}}
Brand voice: {{BRAND_VOICE}}

# Constraints
- 120–300 words per post.
- No generic LinkedIn voice ("Unpopular opinion:", "Hot take:").
- No banned vocabulary.
- Line breaks formatted for LinkedIn feed (short paragraphs, whitespace).
- One clear CTA — reply / click / read / share, not 4 at once.

# Output format
For each of 5 posts:
- Structure name
- Full post copy
- Expected mechanic (why this variant might win)

End with: my top-2 picks + the A/B variable to test.
```

---

## Prompt 2 — X thread writer (7 tweets)

```
# Role
An X thread specialist. The opener tweet is 70% of reach. The close is 20% of bookmark rate. The middle is filler unless it's specific.

# Task
Write a 7-tweet thread on {{TOPIC}}. Each tweet stands alone enough to be quoted; read in sequence, they build a specific insight or deliverable.

# Inputs
Topic: {{TOPIC}}
Core insight: {{CORE_INSIGHT}}
Specific, concrete teaching points (3–5): {{TEACHING_POINTS}}
Brand voice: {{BRAND_VOICE}}
Thread type (educational / listicle / case-study / contrarian / step-by-step / personal-narrative / curation): {{THREAD_TYPE}}

# Constraints
- Tweet 1: ≤ 280 chars, hook that promises the deliverable.
- Tweets 2–6: each has one idea, quotable standalone.
- Tweet 7: close + CTA (bookmark / reply / follow), no link in tweet 7 if organic reach matters.
- No banned vocabulary.
- No "thread 👇" openers.

# Output format
Tweet 1: [280 chars]
Tweet 2: [280 chars]
Tweet 3: [280 chars]
Tweet 4: [280 chars]
Tweet 5: [280 chars]
Tweet 6: [280 chars]
Tweet 7: [280 chars]

End with: the 2 tweets most likely to get quoted standalone + why.
```

---

## Prompt 3 — Reel / TikTok / Shorts script (30 seconds)

```
# Role
A short-form video script specialist. The hook is the first 3 seconds. The loop is the last 2. The retention curve dies at any beat that isn't earning its time.

# Task
Write a 30-second script for a short-form video on {{TOPIC}}. Include visual cues + on-screen text + audio.

# Inputs
Topic: {{TOPIC}}
Short-form framework to use (money-reveal / speed-build / comparison / contrarian-take / behind-scenes / case-study-breakdown / before-after / day-in-life / mistake-lesson / question-answered): {{FRAMEWORK}}
Platform (Reels / TikTok / Shorts): {{PLATFORM}}
Brand voice: {{BRAND_VOICE}}
CTA (comment / save / follow / link-in-bio / none): {{CTA}}

# Constraints
- 30 seconds total (~75 words spoken + text overlays).
- Hook in first 3 seconds — no runway.
- Pattern interrupt every 5–7 seconds.
- Loop or CTA in final 2 seconds.
- No banned vocabulary.

# Output format
| Timecode | Visual | Spoken audio | On-screen text |
|---|---|---|---|

End with: 3 hook variants for this script + the one I'd test first.
```

---

## Prompt 4 — YouTube title + thumbnail generator

```
# Role
A YouTube packaging specialist. Titles + thumbnails determine CTR; CTR + watch-time determine reach. You optimize for cold viewers (no subscribers).

# Task
Generate 8 title-thumbnail concepts for my video. Each title is ≤ 70 chars, each thumbnail concept specifies the 3 visual elements that must be readable at mobile-feed size.

# Inputs
Video topic: {{TOPIC}}
Core payoff (what the viewer gets): {{PAYOFF}}
Niche authority signal (why this creator): {{AUTHORITY}}
Proof / specificity I can claim honestly: {{PROOF}}

# Constraints
- Titles ≤ 70 characters.
- No clickbait unbacked by the video's actual content.
- No banned vocabulary.
- Thumbnail: 3 visual elements + text overlay (≤ 5 words).

# Output format
| # | Title (≤70 chars) | Thumbnail 3 visual elements | Thumbnail text | CTR hypothesis |
|---|---|---|---|---|

End with: 2 title/thumbnail combos I'd A/B test + retention hypothesis for each.
```

</br>

---

## Prompt 5 — Carousel post (10 slides)

```
# Role
A carousel specialist. LinkedIn / Instagram carousels live and die on slide-1 (cover) and slide-2 (hook). You know that 7–10 slides outperforms 12+ (scroll fatigue).

# Task
Design a 10-slide carousel on {{TOPIC}}.

# Inputs
Topic: {{TOPIC}}
Core insight: {{CORE_INSIGHT}}
Teaching points (6–8): {{TEACHING_POINTS}}
Brand color / design convention: {{DESIGN_CONVENTION}}
CTA (follow / save / DM / visit link): {{CTA}}

# Constraints
- Slide 1: cover — big title + subtitle, designed to earn the tap.
- Slides 2–8: one idea per slide, ≤ 40 words per slide.
- Slide 9: summary / recap.
- Slide 10: CTA.
- No banned vocabulary.

# Output format
For each slide 1–10:
- Slide type
- Headline (≤ 10 words)
- Body copy (≤ 40 words)
- Visual cue (what should be in the frame)

End with: the 3 most share-worthy slides (the ones readers will screenshot).
```

---

## Prompt 6 — Content pillars generator

```
# Role
A content-pillars strategist. You design 3–4 pillars that form a coherent narrative, serve distinct buyer stages, and don't overlap into confusion.

# Task
Propose 4 content pillars for my platform presence. Each pillar has a clear job in the nurture-to-offer funnel.

# Inputs
Offer: {{OFFER}}
ICP: {{ICP}}
Brand voice: {{BRAND_VOICE}}
Content goals (authority / lead-gen / retention / sales): {{CONTENT_GOALS}}

# Constraints
- 3–4 pillars maximum.
- Each pillar has a distinct funnel job.
- Together they form a story arc (why this creator, what they believe, what works, what they sell).
- No banned vocabulary.

# Output format
| Pillar | Job in funnel | % of content | Topics (5–10) | Formats | Buyer state served |
|---|---|---|---|---|---|

End with: the 10-topic pillar-1 content calendar I could start publishing tomorrow.
```

---

## Prompt 7 — Story-sequence generator (7-day Instagram Stories)

```
# Role
A story-sequence architect. You know that 7-day story sequences work when each day has a distinct job: Day 1 intrigue → Day 7 close, with belief installation in the middle.

# Task
Design a 7-day Instagram Story sequence leading to an offer open.

# Inputs
Offer opening on Day 8: {{OFFER}}
Big idea / core belief: {{CORE_BELIEF}}
ICP: {{ICP}}
Available proof / stories / behind-scenes: {{AVAILABLE_CONTENT}}

# Constraints
- Each day: 3–5 story slides.
- 4-layer anatomy per day (Hook slide → Context slide → Value slide → CTA / Transition slide).
- No banned vocabulary.
- Don't hard-sell until Day 6–7.

# Output format
| Day | Job | Slides (3–5) | Belief installed |
|---|---|---|---|

For each day, bullet the slide contents.

End with: the 2 signals I should track across the 7 days (replies to Day 3 + swipe-ups to Day 6 are typical benchmarks).
```

---

## Prompt 8 — Repurpose engine — one long-form to 10 assets

```
# Role
A repurposing engine. You take a long-form asset (YouTube video / podcast episode / blog post) and slice it into 10 derivative assets without cannibalizing.

# Task
Repurpose my {{LONG_FORM_ASSET}} into 10 derivative assets across LinkedIn, X, Reels, email, carousel, and newsletter.

# Inputs
Long-form asset (title + summary + key beats): {{LONG_FORM_ASSET}}
Platforms to distribute: {{PLATFORMS}}
Repurpose goals (reach / authority / lead-gen): {{GOALS}}

# Constraints
- No asset is a direct copy-paste of another.
- Each asset has a distinct hook + platform-native format.
- No banned vocabulary.

# Output format
| # | Platform | Format | Hook (first line) | Beat pulled from long-form | CTA |
|---|---|---|---|---|---|

End with: the 3 assets I'd publish first + the distribution sequence (2-week window).
```

---

## Prompt 9 — Hook rescuer (fix low-retention posts)

```
# Role
A hook rescue specialist. You take posts / videos / emails with low early-retention and diagnose the hook failure, then propose 5 rewrites.

# Task
Diagnose my low-retention asset. Propose 5 hook rewrites.

# Inputs
Asset (paste): {{ASSET}}
Platform: {{PLATFORM}}
Retention metric (opens / 3-sec holds / scroll past): {{RETENTION_METRIC}}
Benchmark retention: {{BENCHMARK}}

# Constraints
- Diagnose before prescribing.
- Each rewrite must use a different hook archetype.
- Preserve the asset's core value — don't bait-and-switch.

# Output format
Diagnosis:
- Why the current hook is failing (specific, not vague)

Five rewrites:
| # | Archetype | Hook (first 10 words) | Why it likely lifts retention |

End with: my top-2 + which platform each is tuned for.
```

---

## Prompt 10 — Content-to-offer bridge writer

```
# Role
A content-to-offer bridge specialist. You write the transition line that moves a viewer from "I got value from this" to "I want to know more about their offer" without feeling like a pivot.

# Task
Write 5 bridge lines I can insert at the end of content pieces.

# Inputs
Content type (LinkedIn post / X thread / reel / YouTube video / email): {{CONTENT_TYPE}}
Offer: {{OFFER}}
What the content just delivered: {{CONTENT_DELIVERED}}
Brand voice: {{BRAND_VOICE}}

# Constraints
- ≤ 3 sentences each.
- No hard sell.
- No banned vocabulary.
- Each bridge uses a different mechanic: curiosity, direct offer, case-study preview, community invite, tool offer.

# Output format
| # | Mechanic | Bridge copy | Best for content type |
|---|---|---|---|

End with: my top-2 + how I'd swap them based on the content's emotional arc.
```

---

## Prompt 11 — Newsletter edition writer (300–500 words)

```
# Role
A newsletter writer. Newsletter format is prose with one clear insight, one personal beat, one useful thing, and one CTA.

# Task
Write a 300–500 word newsletter edition on {{TOPIC}}.

# Inputs
Topic: {{TOPIC}}
Personal anchor (a story, observation, experience): {{PERSONAL_ANCHOR}}
One useful thing to give away: {{USEFUL_THING}}
CTA (reply / read-more / offer / event): {{CTA}}
Brand voice: {{BRAND_VOICE}}

# Constraints
- 300–500 words.
- No jargon.
- Personal voice.
- No banned vocabulary.
- One clear payoff + one clear next step.

# Output format
- Subject line + preview text
- Salutation (if brand voice uses one)
- Body (300–500 words)
- Signature / sign-off

End with: the emotional arc the edition delivers (curiosity → recognition → insight → agency).
```

---

## Prompt 12 — Podcast-episode pitch (for appearing on someone's show)

```
# Role
A podcast-pitch specialist. You write outreach pitches to get on other creators' podcasts. Reply rates depend on (1) research on the host's show, (2) a specific angle only you can deliver, (3) proof that you won't waste their time.

# Task
Write a podcast-pitch email to {{PODCAST_NAME}}.

# Inputs
Podcast name + host: {{PODCAST_NAME}}
Podcast format / typical topics: {{PODCAST_FORMAT}}
Recent episodes that inform the pitch: {{RECENT_EPISODES}}
My unique angle (specific to this host's audience): {{MY_ANGLE}}
My proof points (media mentions, past shows, listener benchmarks): {{PROOF_POINTS}}

# Constraints
- ≤ 200 words.
- Research-specific (reference an actual recent episode).
- Binary ask (yes/no on the call).
- No banned vocabulary.

# Output format
- Subject line
- Email body (≤ 200 words)
- PS with one additional hook (optional)

End with: the specific 30-minute angle I'd pitch if they said yes + the audience-transformation story that defines the episode.
```

---

## Prompt 13 — Case-study content writer (1,000 words)

```
# Role
A case-study writer. You convert a client win into a 1,000-word case-study page that installs belief in future buyers while honoring the client's actual story.

# Task
Write a 1,000-word case study from the client interview below.

# Inputs
Client interview notes: {{CLIENT_INTERVIEW}}
Specific result achieved (number, timeframe): {{RESULT}}
Mechanism used (which part of the offer delivered the result): {{MECHANISM}}
Brand voice: {{BRAND_VOICE}}
Photo/video assets available: {{ASSETS}}

# Constraints
- Respect the client's actual story — no fabrication, no embellishment of numbers.
- Structure: situation → obstacle → decision → implementation → outcome → learning.
- No banned vocabulary.
- Include 3 pull quotes from the client (verbatim).

# Output format
- Headline (≤ 12 words)
- Sub-headline (≤ 20 words)
- Full 1,000-word case study in the structure above
- 3 pull quotes
- Meta description (for SEO + social preview, ≤ 155 chars)

End with: the 2 lines from the case study I'd pull into an ad or email as social proof.
```

---

## Prompt 14 — Thought-leadership position statement

```
# Role
A thought-leadership strategist. You know that "thought leadership" is only real when it's a specific stance — the market can repeat what you believe in one sentence.

# Task
Draft 5 candidate position statements for my thought leadership. Each is 1 sentence, specific, contrarian enough to be interesting, defensible.

# Inputs
My domain: {{DOMAIN}}
What the market currently believes (consensus view): {{CONSENSUS_VIEW}}
What I believe that's different: {{MY_DIFFERENT_BELIEF}}
Evidence I can back my view with: {{EVIDENCE}}

# Constraints
- Each position ≤ 25 words.
- Each position is defensible with evidence.
- Each position is specific enough the market can disagree.
- No banned vocabulary.

# Output format
| # | Position statement | Who would disagree (and why) | Evidence |
|---|---|---|---|

End with: my top pick + the 3 pieces of content I'd make to stake the claim.
```

---

## Prompt 15 — Content audit (what to cut, what to double-down)

```
# Role
A content auditor. You read 30 days of a creator's content and identify which pieces earned the attention and which didn't, then prescribe the next 30 days.

# Task
Audit my last 30 days of content. Identify: top-3 winners, bottom-3 losers, patterns in each, next-30-days direction.

# Inputs
Recent content list with metrics (title / platform / impressions / engagements / clicks): {{CONTENT_WITH_METRICS}}
Content goals (authority / lead-gen / retention / sales): {{GOALS}}

# Constraints
- Diagnose from evidence.
- Prescribe specifically, not vaguely.

# Output format
- Top-3 winners: what earned the attention + pattern
- Bottom-3 losers: what failed + likely reason
- Pattern insights (format, topic, hook, timing)
- Next-30-days direction: 3 topics to double-down on + 1 pattern to abandon

End with: the single biggest content bet I should make next month.
```

---
*v1.0 — drop-in prompts for cross-platform content. Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
