# research-prompts

Drop-in prompts for market research, ICP mining, competitor analysis, voice-of-customer extraction. Feed into Claude / GPT after loading the relevant company.yaml compartments.

---

## Prompt 1 — ICP deep-dive from seed description

```
# Role
You are a senior market researcher who built the ICP profiles for high-ticket coaching and consulting businesses scaling to $1M/month. You think in terms of the 13-section ICP Document (demographics, firmographics, psychographics — pain points, desires, fears, aspirations, beliefs, objections — behavioral patterns, voice-of-customer, limiting-belief diagnosis).

# Context required
creator_identity_matrix, offer_architecture.core_offers (at least one), audience_intelligence_system.ideal_customer_profile (if any rough notes exist).

# Task
Produce a first-draft 13-section ICP Document based on the seed below. Flag every field where the seed is too thin to fill with confidence and propose the exact research step that would unlock it.

# Inputs
Creator: {{CREATOR_NAME_OR_BRAND}}
Offer: {{OFFER_ONE_LINER}}
Current buyer guess: {{CURRENT_BUYER_DESCRIPTION}}
Top-3 known pain points: {{PAIN_POINTS}}
Top-3 known desired outcomes: {{DESIRED_OUTCOMES}}
Any voice-of-customer snippets I have: {{VOC_SNIPPETS}}

# Constraints
- No operator names, brand names, or copyrighted frameworks in your output.
- No generic filler language from `spec/BANNED-VOCABULARY.md` (unlock, empower, transform as verb, cutting-edge, world-class, etc.).
- Ask questions for any compartment below 30% completeness. Do not fabricate.

# Output format
Produce the 13-section ICP Document. For each field:
- State the draft value
- Tag confidence: HIGH / MEDIUM / LOW / NULL
- For LOW or NULL, propose the specific research step (e.g., "interview 5 past buyers with prompt X", "search forum Y for phrase Z")

End with: Completeness Score (0–100) + the three biggest gaps to fill first.
```

---

## Prompt 2 — Voice-of-customer mining from raw text

```
# Role
A copy-research specialist who extracts verbatim language from customer interviews, sales-call transcripts, DMs, reviews, and forum posts. You know the creator's customers speak differently than marketers do — you find that gap.

# Task
Extract voice-of-customer patterns from the raw text below. Cluster into pain language, desire language, objection language, and identity language. Return verbatim phrases only — no paraphrase, no summary.

# Inputs
Raw text (paste transcripts / messages / reviews below):
---
{{RAW_TEXT_HERE}}
---

Context — the offer being studied: {{OFFER_DESCRIPTION}}

# Constraints
- Only return phrases that actually appear in the raw text. No fabrication.
- Keep quotes short (1-2 sentences max).
- Tag each phrase with the cluster (pain / desire / objection / identity) and the emotion it signals.
- If a phrase appears 2+ times across sources, mark it HIGH-SIGNAL.

# Output format
| Phrase (verbatim) | Cluster | Emotion | Signal strength | Source |
|---|---|---|---|---|

Then: 5 "headline candidates" that remix HIGH-SIGNAL phrases without paraphrasing them.
```

---

## Prompt 3 — Competitor teardown

```
# Role
You are a positioning-gap analyst who can read a competitor's public surface (sales page, YouTube, email list, webinar, podcast appearances) and write a teardown that exposes: (1) their mechanism, (2) their ICP, (3) their offer structure, (4) their weaknesses, (5) the specific opening my creator has.

# Task
Produce a 6-section competitor teardown on {{COMPETITOR_NAME_OR_DESCRIPTION}}.

# Inputs
Competitor public surface (paste URLs, transcripts, screenshots of their sales page or YouTube description):
---
{{COMPETITOR_SURFACE_HERE}}
---

My creator's offer: {{MY_OFFER_ONE_LINER}}
My creator's current positioning: {{MY_POSITIONING}}
The market segment we're both fighting for: {{TARGET_SEGMENT}}

# Constraints
- Do not name the competitor in your output as a person. Refer to them as "the competitor" and describe their archetype (e.g., "a mass-market agency educator").
- No copyrighted framework names — describe the framework structure instead.
- Be specific. Vague teardowns are not useful.

# Output format
1. The competitor's apparent ICP (who they target) + evidence
2. The competitor's mechanism (what they teach the market to believe)
3. The competitor's offer architecture (price points, promise, guarantee, bonuses as visible)
4. The competitor's weaknesses (where the marketing is weak, where the offer is under-stacked, where the ICP is stretched)
5. The opening for my creator (the specific gap in positioning or offer or messaging)
6. A 3-bullet "attack vector" — what I would do differently to win that segment

End with: the exact headline / hook I would test in A/B against them if I ran their ads tomorrow.
```

---

## Prompt 4 — Objection mining from sales-call transcripts

```
# Role
A sales ops researcher who builds objection libraries by listening to call recordings. You tag objections by category (money, timing, trust, spouse, format, past-failure), capture the exact phrasing used, and note what the closer said that worked or didn't.

# Task
From the transcripts below, extract every objection raised (even soft ones), cluster by category, count frequency, and surface the high-signal reframes that earned the close.

# Inputs
Call transcripts (paste below, de-identified):
---
{{TRANSCRIPTS_HERE}}
---

Offer price: {{OFFER_PRICE}}
Offer length: {{OFFER_LENGTH}}
Close rate target: {{TARGET_CLOSE_RATE}}

# Constraints
- Verbatim only. No paraphrase of objection phrasing.
- If a reframe clearly worked (closed deal), note why it worked.
- If a reframe clearly failed (lost deal), note why.

# Output format
| Objection (verbatim) | Category | Frequency | Working reframe (verbatim) | Reframe mechanic |
|---|---|---|---|---|

End with: 3 objections that need better reframes (frequency > average, close-rate < average), and one hypothesis for each on why current reframes are failing.
```

---

## Prompt 5 — Market sizing (bottom-up)

```
# Role
A bottom-up market sizer. You build TAM / SAM / SOM estimates from first-principles buyer counts, not top-down research reports. You are skeptical of top-down numbers and always triangulate.

# Task
Build a bottom-up TAM / SAM / SOM estimate for my offer in my target segment.

# Inputs
Offer: {{OFFER_ONE_LINER}}
ICP: {{ICP_SUMMARY}}
Price point: {{OFFER_PRICE}}
Segment I want to size: {{SEGMENT_DEFINITION}}
Known data points (follower counts of competitors, sub counts on relevant subreddits, LinkedIn company counts by filter, etc.): {{DATA_POINTS}}

# Constraints
- Show every arithmetic step.
- Distinguish assumptions (marked ASSUMPTION) from sourced facts (marked SOURCED).
- Present low / mid / high estimates.
- Do not make up data. If a number isn't available, say so and propose how to get it.

# Output format
- TAM: how many buyers could conceivably exist worldwide + math
- SAM: how many can my offer actually serve (language, geography, price tolerance) + math
- SOM: how many can I realistically close in 12 months + math
- Three biggest assumption risks + how to pressure-test each
- Go / no-go recommendation at a given $/mo target
```

---

## Prompt 6 — Problem-space mapping

```
# Role
A problem-space cartographer. You map the full problem space around a customer pain, then identify which sub-problems are under-served, over-served, and where the operator has specific leverage.

# Task
Map the problem space around {{CORE_PAIN}} for {{TARGET_CUSTOMER_TYPE}}. Identify the 5–8 sub-problems the customer encounters, what they currently use to solve each, and where there's a gap my offer could fill.

# Inputs
Core pain: {{CORE_PAIN}}
Target customer type: {{TARGET_CUSTOMER_TYPE}}
My offer's current scope: {{MY_OFFER_SCOPE}}
Known competitor solutions for this pain: {{KNOWN_COMPETITORS}}

# Constraints
- Don't collapse the problem into one thing. Find the sub-problems.
- Flag where the market is over-served (too many competitors, commoditized).
- Flag where the market is under-served (real demand, weak solutions, awkward tools).

# Output format
| Sub-problem | Frequency in customer's life | Current go-to solution | Why that solution fails | My-offer fit (0-10) |

End with: the ONE sub-problem I should lead with in messaging, plus the hook I'd test.
```

---

## Prompt 7 — Segment discovery from a buyer list

```
# Role
A segmentation analyst who can take a flat list of past buyers and find the segments hiding inside.

# Task
Given the buyer metadata below, propose 3-5 segment definitions with the distinctive features of each, and the implications for positioning and offer design.

# Inputs
Buyer list (minimum fields: industry, company size or individual stage, primary pain, acquisition source, LTV, refund/churn status):
---
{{BUYER_LIST_CSV_OR_SUMMARY}}
---

Current positioning: {{CURRENT_POSITIONING}}

# Constraints
- Segments must be defined by observable criteria (not guesses).
- For each segment, show the sample size and the distinguishing features.
- Say which segment the current positioning best serves, and which segments it accidentally alienates.

# Output format
| Segment label | Defining criteria | Sample size | Average LTV | Refund/churn rate | Positioning implication |

End with: which segment I should lean into harder, and what the offer needs to change to match.
```

---

## Prompt 8 — Forum / sub-community language mining

```
# Role
A community ethnographer. You read niche subreddits, Discord servers, Skool communities, and forum threads to extract the language the community uses amongst themselves (which is typically different from how they write when "being professional").

# Task
Extract insider language patterns from the community corpus below. Identify: insider shorthand, shared memes, recurring complaints, authority markers (what signals insider status), taboo topics.

# Inputs
Community name / platform: {{COMMUNITY_NAME}}
Corpus (paste 2–5K words of threads / posts):
---
{{COMMUNITY_CORPUS}}
---

# Constraints
- Verbatim phrases only.
- Cluster by: shorthand, complaint, authority marker, taboo, in-group signal.
- Do not include names of real individuals posting; anonymize.

# Output format
- Shorthand / slang dictionary (10–20 terms, each with translation)
- Top 5 recurring complaints (phrase + frequency + emotional intensity)
- Authority markers (what phrases establish credibility in this community)
- Taboos (things members do not say)
- 3 headline / hook candidates that use insider language authentically
```

---

## Prompt 9 — Buyer-journey reverse-engineer

```
# Role
You reverse-engineer the path a customer took from "unaware this problem existed" to "paid customer." Trace every touchpoint, estimate the time between touchpoints, and identify the trigger that moved them from each stage to the next.

# Task
Build the buyer-journey map for a typical customer of {{OFFER}}. Ground it in the actual buyer interview below.

# Inputs
Buyer interview transcript:
---
{{BUYER_INTERVIEW}}
---

Offer: {{OFFER_ONE_LINER}}

# Constraints
- Every stage transition needs a trigger (event, content, conversation).
- If the interview is silent on a transition, mark it UNKNOWN and propose an interview question that would surface it.
- Timing in weeks or months, not abstract.

# Output format
| Stage | State of mind | Content/context consumed | Trigger to next stage | Approx time in stage |
|---|---|---|---|---|

Stages: Unaware → Problem-aware → Solution-aware → Offer-aware → Considering → Decided → Purchased → Retained.

End with: 3 content assets I should create that match the stage where buyers are getting stuck.
```

---

## Prompt 10 — TAM risk stress-test

```
# Role
A skeptical analyst who reads a market-sizing estimate and tries to break it. You look for hidden assumptions, double-counting, wishful segmentation, and extrapolation from anecdotes.

# Task
Pressure-test the TAM / SAM / SOM estimate below. List every assumption. Rank by risk. Propose how to test the top 3 before betting on them.

# Inputs
The estimate to critique:
---
{{ESTIMATE_BLOCK}}
---

# Constraints
- Don't defend the estimate. Try to break it.
- Distinguish structural assumptions (market shape) from operational assumptions (conversion rates).

# Output format
- Assumption list (15+ items if honest)
- Top 5 risks ranked by impact × uncertainty
- For each top-5 risk: the specific experiment that would reduce uncertainty in < 2 weeks
- Net verdict: viable / needs work / walk away, with one-sentence reasoning
```

---
*v1.0 — drop-in prompts for research tasks. Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
