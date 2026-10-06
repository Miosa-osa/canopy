# content-repurposing-prompts

Drop-in prompts for turning one long-form asset into 10+ derivative assets without cannibalizing. YouTube → short-form, podcast → threads, blog → emails, etc.

---

## Prompt 1 — YouTube video → 7 derivatives

```
# Role
A repurposing specialist who extracts 7 distinct derivative assets from one long-form YouTube video without the derivatives feeling like copy-paste.

# Task
Extract 7 derivatives from my YouTube video.

# Inputs
Video title: {{VIDEO_TITLE}}
Video length: {{VIDEO_LENGTH}}
Video transcript (paste or summary): {{TRANSCRIPT}}
Key teaching beats: {{TEACHING_BEATS}}
Best customer-facing quotes from the video: {{BEST_QUOTES}}
Platforms to distribute: {{PLATFORMS}}

# Constraints
- Each derivative has a distinct hook + platform-native format.
- No direct copy-paste.
- No banned vocabulary.

# Output format
1. 60-second reel / TikTok script (hook + beats + CTA)
2. 7-tweet X thread (opener + 5 body tweets + close)
3. LinkedIn post (200–300 words)
4. Newsletter edition (300–500 words)
5. Instagram carousel (10 slides)
6. Email to list (with subject + preview)
7. Podcast micro-episode pitch (if I spin off an audio show)

End with: the 2 derivatives I'd publish first + the release sequence across 2 weeks.
```

---

## Prompt 2 — Podcast episode → 5 derivatives

```
# Role
A podcast-repurposing specialist. Podcast episodes have density but low shareable-snippet count; you find the 5 extractable assets that can stand alone.

# Task
Extract 5 derivatives from my podcast episode.

# Inputs
Episode title: {{EPISODE_TITLE}}
Episode length: {{LENGTH}}
Transcript / summary: {{TRANSCRIPT}}
Top 5 "quotable" moments (timestamps): {{QUOTABLE_MOMENTS}}
Guest (if any) + context: {{GUEST}}

# Constraints
- Each derivative uses a different format.
- Audio is hardest to distribute — at least 2 derivatives must be visual/text.
- No banned vocabulary.

# Output format
1. 60-second audiogram script (with the visual overlay text)
2. X thread (5–7 tweets)
3. LinkedIn post (200–300 words)
4. Email to list
5. Blog post / newsletter (500–800 words)

End with: the one quotable moment I'd pull as the thumbnail / headline across all derivatives.
```

---

## Prompt 3 — Blog post → email sequence

```
# Role
A blog-to-email specialist. You take one long-form blog post and extract 5 emails that tell the post's story across a week — same insight, different emotional angles.

# Task
Turn my blog post into a 5-email sequence.

# Inputs
Blog post title: {{POST_TITLE}}
Blog post (paste or summary): {{POST}}
Offer to tie to: {{OFFER}}
Brand voice: {{BRAND_VOICE}}

# Constraints
- Each email has one distinct job.
- No direct copy-paste of blog sections.
- Emails build on each other, not repeat.
- No banned vocabulary.

# Output format
| Day | Email job | Subject | Body (≤300 words) | CTA |
|---|---|---|---|---|

End with: the subscriber action pattern that would indicate the sequence is working.
```

---

## Prompt 4 — Long VSL → 10-part content calendar

```
# Role
A VSL-repurposer. The VSL is the densest asset in the business; extract every teaching beat and proof point into stand-alone content that drives traffic back to the VSL.

# Task
Extract a 10-part content calendar from my VSL.

# Inputs
VSL length: {{LENGTH}}
VSL transcript: {{TRANSCRIPT}}
Key beats (at minimum: hook, problem, mechanism, proof, stack, close): {{KEY_BEATS}}
Content platforms: {{PLATFORMS}}

# Constraints
- Each content asset is a distinct format + angle.
- Together they form a 2-week content arc that warms the audience before they watch the full VSL.
- No banned vocabulary.

# Output format
| # | Platform | Format | Angle pulled from VSL | Hook (first line) | CTA |
|---|---|---|---|---|---|

End with: the sequencing logic (which posts drive awareness → consideration → click-to-VSL).
```

</br>

---

## Prompt 5 — Course / curriculum → sales assets

```
# Role
A curriculum-repurposer. Course outline becomes sales-page copy, ad angles, lead-magnet design, and webinar structure.

# Task
Extract sales assets from my curriculum.

# Inputs
Course name: {{COURSE_NAME}}
Module names + 1-sentence outcomes: {{MODULE_NAMES_OUTCOMES}}
Core transformation: {{TRANSFORMATION}}
Proof / case studies available: {{PROOF}}

# Constraints
- Don't leak paid content in free assets.
- The hook for each asset should be the outcome, not the mechanism.
- No banned vocabulary.

# Output format
- Sales-page main section (the "here's what you get" with outcome framing per module)
- 3 ad angles (each tied to one module's outcome)
- 1 lead-magnet design (pulls forward the easiest Module-1 win)
- Webinar structure (how the curriculum maps to a 60-min teach)

End with: the 1 module's outcome that's most magnetic for cold traffic + why.
```

---

## Prompt 6 — Testimonial → 5 proof assets

```
# Role
A proof-asset specialist. One strong testimonial yields 5+ distinct proof assets used in ads, sales pages, emails, and social.

# Task
Extract 5 proof assets from my client testimonial.

# Inputs
Testimonial (paste verbatim): {{TESTIMONIAL}}
Client context (stage, industry, investment, outcome): {{CLIENT_CONTEXT}}
Offer: {{OFFER}}

# Constraints
- Verbatim quotes — don't paraphrase the client.
- Each asset targets a different objection.
- Obtain release before using (Photo-Video-Release template if applicable).

# Output format
1. Sales-page hero-quote (≤ 20 words, attention-grabbing line)
2. Ad caption (120–180 words, using 2 quotes + context)
3. Email body (subject line + 250-word story + offer tie)
4. LinkedIn post (250 words using testimonial as anchor)
5. 30-second video script (verbal extract of the strongest beats)

End with: the 1 verbatim line I'd use as the ad headline + why it defeats the most common objection.
```

---

## Prompt 7 — Event / workshop recording → 10 social clips

```
# Role
A clip-extractor for live events / workshops. You find the 10 standalone moments worth clipping out of a 2-hour workshop.

# Task
Identify 10 clips from my workshop recording.

# Inputs
Workshop title: {{WORKSHOP_TITLE}}
Length: {{LENGTH}}
Rough transcript / key timestamps: {{TRANSCRIPT_OR_TIMESTAMPS}}
Platform fit: {{PLATFORM_FIT}}

# Constraints
- Each clip is 30–90 seconds.
- Each clip stands alone (makes sense without the full workshop).
- Clips span the emotional arc (high / medium / low intensity).

# Output format
| # | Timestamp | Length | Hook (first sentence of the clip) | Distribution platform | CTA |
|---|---|---|---|---|---|

End with: the 1 clip that's most "stops the scroll" + the ad-test hypothesis.
```

---

## Prompt 8 — DM / email exchange → case-study article

```
# Role
A case-study writer who builds case studies from the raw DM / email exchange between operator and client. You preserve authenticity while structuring for narrative.

# Task
Write a 1,000-word case-study from the exchange below.

# Inputs
DM / email exchange with client (anonymized as needed): {{EXCHANGE}}
Outcome achieved: {{OUTCOME}}
Time to outcome: {{TIME_TO_OUTCOME}}
Client consent to publish: {{CONSENT_YES_NO}}

# Constraints
- Don't fabricate dialogue.
- Preserve verbatim language where possible.
- Structure: situation → friction → decision → implementation → outcome → learning.
- No banned vocabulary.

# Output format
- Headline + sub-headline
- 1,000-word case-study in the structure above
- 3 verbatim pull-quotes

End with: the single beat that would make the best ad hook.
```

---

## Prompt 9 — Sales call transcript → objection-library entries

```
# Role
An objection-library builder. Every sales-call transcript yields 3–8 new or refined objection entries; you extract them and add them to the library.

# Task
Extract objection-library additions from the transcript below.

# Inputs
Sales-call transcript (de-identified): {{TRANSCRIPT}}
Existing objection categories in my library: {{EXISTING_CATEGORIES}}
Outcome of the call (closed / objected / stalled / lost): {{CALL_OUTCOME}}

# Constraints
- Verbatim quotes.
- Tag each objection by category + layer (cognitive / emotional / behavioral).
- Flag if the reframe used was new (add to library) or existing (note effectiveness).

# Output format
| # | Objection (verbatim) | Category | Layer | Reframe used | Reframe worked? (Y/N + why) |
|---|---|---|---|---|---|

End with: the 1 objection that deserves a new entry in my objection-library + the 3-layer reframe to ship.
```

---

## Prompt 10 — Support-ticket patterns → product-improvement brief

```
# Role
A support-pattern reader. Support tickets are the early-warning system for product friction, onboarding gaps, or mis-positioning. You extract the pattern and propose the fix.

# Task
Read the support tickets below. Identify top-3 patterns + propose the product / onboarding / content fix for each.

# Inputs
Recent support tickets (30+ ideally): {{TICKETS}}
Offer: {{OFFER}}
Onboarding flow: {{ONBOARDING}}

# Constraints
- Pattern = ≥ 5 tickets on the same issue.
- Distinguish friction (product issue) from confusion (content / communication issue).
- Don't overfit to one-off complaints.

# Output format
| Pattern | Frequency | Category (friction / confusion) | Root cause | Recommended fix | Owner |
|---|---|---|---|---|---|

End with: the 1 fix that would most reduce future ticket volume + expected reduction %.
```

---

## Prompt 11 — Customer interview → positioning update

```
# Role
A positioning updater. You read customer interviews looking for evidence the current positioning is off — verbatim language that doesn't match, desires that aren't served, pains that aren't mentioned.

# Task
Read the customer interview. Propose positioning updates based on verbatim signals.

# Inputs
Customer interview transcript: {{INTERVIEW}}
Current positioning document: {{CURRENT_POSITIONING}}
Customer segment: {{SEGMENT}}

# Constraints
- Only propose updates grounded in verbatim evidence.
- Don't rewrite the whole positioning — update the 1–3 lines that clearly need it.

# Output format
- Verbatim customer phrases that matter (3–8 phrases)
- Current positioning lines that conflict with customer language
- Proposed updates (old vs new for each conflict)
- Impact hypothesis (what improves if we make these updates)

End with: the 1 update I'd ship first + the A/B test if applicable.
```

---
*v1.0 — drop-in prompts for content repurposing. Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
