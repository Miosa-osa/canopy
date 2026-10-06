# ad-creative-prompts

Drop-in prompts for paid-ad hook variants, angles, headline grids, CTA splits. Pair with `/ad-creative` for fast variant generation before a creative testing cycle.

---

## Prompt 1 — Hook variant grid (30 hooks in one run)

```
# Role
A paid-ad hook specialist. You know hooks split by emotion (fear / anger / greed / pride / guilt), by structure (question / stat / callout / story / identity), and by platform cadence (3-second TikTok / 5-second Reels / 7-second Meta feed / 15-second YouTube pre-roll).

# Task
Generate a 30-hook grid for my offer: 6 structures × 5 emotions. Each cell is one hook. Each hook is ≤ 12 words.

# Inputs
Offer: {{OFFER}}
ICP (1 sentence): {{ICP}}
Primary pain (verbatim VOC): {{PAIN_VOC}}
Primary desire (verbatim VOC): {{DESIRE_VOC}}
Unique mechanism: {{UNIQUE_MECHANISM}}
Platform: {{PLATFORM}}

# Constraints
- Max 12 words per hook.
- No banned vocabulary.
- No copyrighted framework names.
- No income-claim violations (platform policy).
- No medical-claim violations (if offer is health-adjacent).

# Output format
| Structure \ Emotion | Fear | Anger | Greed | Pride | Guilt |
|---|---|---|---|---|---|
| Question |   |   |   |   |   |
| Stat |   |   |   |   |   |
| Callout (identity) |   |   |   |   |   |
| Story opener |   |   |   |   |   |
| Contrarian |   |   |   |   |   |
| Direct-benefit |   |   |   |   |   |

End with: my top-5 to test first + the one-line rationale for each.
```

---

## Prompt 2 — Angle-test generator

```
# Role
An angle-testing strategist. You generate 5 distinct angles for the same offer — each angle targets a different belief, pain, or identity — so a creative testing cycle explores the message space, not just hook variance.

# Task
Propose 5 distinct angles for my offer. Each angle: a one-sentence core insight, the primary belief it installs, the proof it needs, the ICP segment it best serves.

# Inputs
Offer: {{OFFER}}
ICP: {{ICP}}
Current winning angle (if any): {{WINNING_ANGLE}}
Objections library (top 10): {{OBJECTIONS}}

# Constraints
- Each angle must be meaningfully different — not a hook swap.
- Each angle targets a different belief (not the same belief restated).
- No banned vocabulary.

# Output format
| # | Angle | Core insight | Belief installed | Proof needed | Best ICP segment |
|---|---|---|---|---|---|

End with: angle-priority test sequence (which to test first, why) + kill criteria (what metric tells me an angle is dead).
```

---

## Prompt 3 — Headline grid (10 headlines across 5 frameworks)

```
# Role
A headline-grid specialist. Frameworks: benefit-first, curiosity, social-proof, specific-result, contrarian.

# Task
Generate 10 ad headlines — 2 per framework.

# Inputs
Offer: {{OFFER}}
Primary benefit: {{BENEFIT}}
Social proof available: {{SOCIAL_PROOF}}
Specific measurable result you can claim honestly: {{SPECIFIC_RESULT}}
Contrarian take that's defensible: {{CONTRARIAN_TAKE}}

# Constraints
- ≤ 10 words each.
- No banned vocabulary.
- Claims must be backed by proof you can show.

# Output format
| # | Framework | Headline | Proof anchor |
|---|---|---|---|

End with: my top-3 + which platform each is tuned for.
```

---

## Prompt 4 — Creative brief for video ad

```
# Role
A short-form video ad brief-writer. You spec: hook (first 3 seconds), body (middle 15–25 seconds), CTA (last 3–5 seconds), visual format (talking head vs UGC vs montage vs screen-record), compliance notes.

# Task
Write a complete video ad brief for one of my angles. Format: direct-response short-form (15–45 seconds).

# Inputs
Angle: {{ANGLE}}
Platform: {{PLATFORM}}
Offer: {{OFFER}}
CTA destination (landing page URL or quiz or booking): {{CTA_DESTINATION}}
Available assets (footage I have, testimonials, B-roll): {{AVAILABLE_ASSETS}}
Compliance flags (income / medical / financial): {{COMPLIANCE_FLAGS}}

# Constraints
- 15–45 seconds total.
- Hook in first 3 seconds.
- CTA explicit.
- No claims the proof doesn't back.
- No banned vocabulary.

# Output format
- Hook (0:00–0:03): visual + audio + on-screen text
- Body (0:03–0:30): visual + audio + on-screen text
- CTA (0:30–0:45): visual + audio + on-screen text + URL
- Captions text (on-screen, per beat)
- Compliance notes (what to avoid / include)

End with: 3 B-roll shots I need to capture + 2 lines I need the creator to film.
```

---

## Prompt 5 — Static image ad brief

```
# Role
A static-image ad specialist. You know where the eye lands first (top-left in Western markets, center for mobile feed), what three words must register in < 2 seconds, and how much body copy passes vs. stops scroll.

# Task
Write the creative brief for one static image ad.

# Inputs
Angle: {{ANGLE}}
Offer: {{OFFER}}
Platform: {{PLATFORM}} (Meta feed / LinkedIn feed / Display)
Brand voice / color palette: {{BRAND_VOICE_COLOR}}
Proof asset to feature (testimonial / metric / before-after): {{PROOF_ASSET}}

# Constraints
- Three-word scan test: what three words must register in 2 seconds?
- Body copy ≤ 40 words on the image itself.
- Caption copy ≤ 120 words, hook in first line.
- No banned vocabulary.

# Output format
- Three-word scan (the 3 most important words, biggest type)
- Image composition (what's in the frame, orientation)
- On-image body copy (≤ 40 words)
- Caption copy (≤ 120 words, hook first, CTA last)
- Alt text (for accessibility)

End with: the A/B variable I'd split first (background image / three-word scan / CTA wording).
```

---

## Prompt 6 — UGC-style ad script

```
# Role
A UGC ad script specialist. You write scripts that feel like a real customer recorded a phone-camera review — conversational, specific, emotionally grounded — not a polished talking head.

# Task
Write 3 UGC-style scripts (30–60 seconds each) for my offer.

# Inputs
Offer: {{OFFER}}
Target UGC actor profile (casting): {{ACTOR_PROFILE}}
Real customer results (verified, not fabricated): {{CUSTOMER_RESULTS}}
Platform: {{PLATFORM}}
FTC disclosure requirements: paid partnership flag Yes/No: {{PAID_DISCLOSURE}}

# Constraints
- Disclosure included where required ("#ad" / "paid partnership" / "I was compensated for this").
- Scripts must read as spoken, not written.
- No fabricated testimonials. If using a real customer, attribute. If using an actor-read, note.
- No medical / financial guarantee claims.

# Output format
For each of 3 scripts:
- Casting note (actor type)
- Opening line (first 3 seconds)
- Middle beats (the story + specific detail + emotional anchor)
- Close (the recommendation + CTA)
- Disclosure placement

End with: the 1 script I'd produce first + why.
```

---

## Prompt 7 — Retargeting ad brief

```
# Role
A retargeting specialist. You know warm-traffic ads need to be different from cold-traffic — they reference the viewer's prior engagement, reduce remaining objections, and push to the next funnel step.

# Task
Write 4 retargeting ad concepts for viewers who engaged with my VSL but didn't book / buy.

# Inputs
Cold-traffic angle that got them in: {{COLD_ANGLE}}
Viewer engagement state (watched VSL 50% / opted in / added to cart / attended webinar): {{ENGAGEMENT_STATE}}
Top-3 objections at this stage: {{OBJECTIONS}}
Offer: {{OFFER}}
New proof / scarcity / guarantee not shown in cold ad: {{NEW_ELEMENTS}}

# Constraints
- Each ad addresses ONE objection at a time.
- Acknowledge the viewer's prior engagement without being creepy ("You watched but haven't booked — here's what's different").
- No banned vocabulary.

# Output format
| # | Objection addressed | Ad concept (1–2 sentences) | Proof element | CTA |
|---|---|---|---|---|

End with: test order + budget allocation + kill criteria.
```

---

## Prompt 8 — CTA + landing-page alignment

```
# Role
A CTA-alignment specialist. You make sure the ad CTA, the landing-page headline, and the first fold of the landing page all send the same signal — no bait-and-switch, no cognitive-load spike between click and page.

# Task
Given my ad copy + landing page first fold, score alignment (0–10) and propose the minimal changes to hit 9+.

# Inputs
Ad copy (paste): {{AD_COPY}}
Ad CTA button text: {{AD_CTA}}
Landing page headline: {{LANDING_HEADLINE}}
Landing page sub-headline: {{LANDING_SUBHEAD}}
Landing page first CTA button: {{LANDING_CTA}}

# Constraints
- Alignment = promise continuity + vocabulary continuity + visual continuity.
- Don't rewrite either end — propose the minimal change.

# Output format
- Promise continuity score (0–10) + evidence
- Vocabulary continuity score (0–10) + evidence
- Visual continuity score (0–10) + evidence
- Minimal changes to hit 9+

End with: the one change that likely drives the biggest CVR lift.
```

---

## Prompt 9 — Winning-creative reverse-engineer

```
# Role
A reverse-engineer of winning ads. Given a winning ad's structure (hook, body, CTA, visual), you decompose what about it is winning + how to produce variants that hold the structural wins while testing new angles.

# Task
Decompose my current winning ad. Propose 5 variants that preserve the structural wins while testing meaningful angle / hook / proof changes.

# Inputs
Winning ad (transcript + screenshots): {{WINNING_AD}}
CPM / CPA / CVR vs benchmark: {{PERFORMANCE}}
Fatigue status (is it fading): {{FATIGUE_STATUS}}

# Constraints
- Variants must preserve the structural element that's likely driving the win.
- Variants must be meaningfully different from each other.
- Compliance safe.

# Output format
Structural win diagnosis (what element is driving performance):
- Hook / angle / proof / CTA / format / length / identity match

Five variants:
| # | What structural element preserved | What new element tested | Hypothesis |

End with: test priority + budget split + hold-winner protocol.
```

---

## Prompt 10 — Compliance safety check

```
# Role
A platform-policy compliance reviewer (Meta, Google, TikTok, YouTube). You read ad copy and flag claims that will get the ad disapproved or the ad account restricted.

# Task
Review the ad copy below. Flag every claim that violates platform policy or general advertising law (FTC / ASA / AUS / EU UCPD). Propose compliant rewrites.

# Inputs
Ad copy (paste all versions): {{AD_COPY_ALL_VERSIONS}}
Platforms running: {{PLATFORMS}}
Industry (financial / medical / coaching / agency / info): {{INDUSTRY}}
Claims I want to make: {{CLAIMS_WANTED}}

# Constraints
- Be specific about which policy / regulation is at risk.
- Propose compliant rewrites that preserve the spirit.
- Flag claims that require specific disclosures (income, health, testimonial).

# Output format
| # | Original claim | Platform at risk | Policy/regulation | Compliant rewrite |
|---|---|---|---|---|

End with: 3 disclosures I should add + their placement.
```

---
*v1.0 — drop-in prompts for paid-ad creative. Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
