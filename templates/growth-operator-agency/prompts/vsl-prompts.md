# vsl-prompts

Drop-in prompts for VSL construction, hook variants, mechanism naming, stack slides, close variants. Pair with `/build-vsl` for variant exploration.

---

## Prompt 1 — Hook variant generator (10 hooks from one seed)

```
# Role
A senior VSL copywriter who knows the 10 VSL hook archetypes: curiosity-gap, specific-result, contrarian, problem-agitate, identity, insight, question, story, pattern-interrupt, and most-people-are-wrong.

# Task
Generate 10 distinct hooks for my VSL opening — one per archetype. Each hook must address the specific ICP + specific offer below, not generic.

# Inputs
ICP summary (1–2 sentences): {{ICP_SUMMARY}}
Offer one-liner: {{OFFER_ONE_LINER}}
Unique mechanism name: {{UNIQUE_MECHANISM}}
Primary pain (verbatim from customer language): {{PRIMARY_PAIN_VOC}}
Primary desire (verbatim): {{PRIMARY_DESIRE_VOC}}
Awareness level (Unaware / Problem-aware / Solution-aware / Offer-aware / Most-aware): {{AWARENESS_LEVEL}}
Sophistication stage (Naive / Aware / Skeptical / Exhausted): {{SOPHISTICATION}}

# Constraints
- No banned vocabulary.
- No copyrighted framework names.
- No "Hey guys" or "In this video we'll talk about" openers — start with tension.
- Each hook ≤ 25 words.

# Output format
| # | Archetype | Hook (≤25 words) | Best for awareness level | Best for sophistication |
|---|---|---|---|---|

End with: my top-3 picks + the voice-of-customer phrase each remixes.
```

---

## Prompt 2 — Mechanism-naming generator

```
# Role
A naming specialist who coins mechanism names that are: (1) memorable, (2) descriptive of the structure (not just a feeling), (3) unique enough to own, (4) usable as a teaching framework.

# Task
Generate 12 mechanism name candidates for my offer's unique method. Each name should be 2–5 words, concrete, and pass the 30-second explanation test (can the prospect explain what the mechanism does in 30 seconds after hearing the name).

# Inputs
Method in my own words (what my method actually does — 3–5 sentences): {{METHOD_DESCRIPTION}}
Key variables my method tracks: {{KEY_VARIABLES}}
What competitors call their similar methods (to avoid overlap): {{COMPETITOR_METHOD_NAMES}}
Brand voice tone: {{BRAND_VOICE_TONE}}

# Constraints
- No copyrighted framework names (don't mimic other operators' named frameworks).
- No generic filler ("System", "Secret", "a longevity-protocol" alone don't pass).
- 2–5 words.
- Pronounceable. Memorable. Ownable.

# Output format
| # | Name | Why it works | 30-sec explanation | Risk (too generic / too clever / conflict with known brand) |
|---|---|---|---|---|

End with: my top-3 + the one-line positioning line that each name enables.
```

---

## Prompt 3 — Stack-slide copy generator

```
# Role
A stack-slide copywriter. You write the "here's what you get" portion of a VSL as a list with perceived-value dollar amounts, grouped by what each component resolves in the customer's journey.

# Task
Write the stack slide for my offer. Include 6–10 components. Each component has a bracketed name, a one-line description, a dollar value, and a short "what this eliminates" note.

# Inputs
Offer: {{OFFER_ONE_LINER}}
Price: {{PRICE}}
Target total stack value (at least 5× price): {{TARGET_STACK_VALUE}}
Bonuses from the bonus library: {{BONUSES}}
Delivery format: {{DELIVERY_FORMAT}}
Primary objections to counter in the stack: {{OBJECTIONS}}

# Constraints
- Every component has a numeric value. No "priceless", no "you can't put a value on this".
- Stack value ≥ 5× price.
- Each value must be defensible (comparable product / course / service at that price).
- No banned vocabulary.

# Output format
| # | Component | Description | Value | Objection it eliminates |
|---|---|---|---|---|

Total stack value: $X
Price today: $Y
Savings: $(X - Y), a Z:1 ratio

End with: the one-line close copy that goes immediately after the stack.
```

---

## Prompt 4 — Close variant generator

```
# Role
A VSL close specialist. You know 6 close archetypes: assumptive close, crossroads close, question close, takeaway close, scarcity close, and identity close.

# Task
Write 6 distinct close variants for the VSL — one per archetype. Each variant is 60–90 seconds of spoken copy (roughly 150–225 words).

# Inputs
Offer: {{OFFER_ONE_LINER}}
Price: {{PRICE}}
Guarantee: {{GUARANTEE_COPY}}
Scarcity mechanism (if any): {{SCARCITY_MECHANISM}}
Brand voice: {{BRAND_VOICE}}
Final belief to install (the one thing the viewer must believe at the moment of decision): {{FINAL_BELIEF}}

# Constraints
- No banned vocabulary.
- Each close references the final belief.
- Each close ends with a specific CTA (URL or action).
- No "clicking below" without a reason.

# Output format
For each archetype:
- Name
- Spoken copy (150–225 words)
- Why this archetype fits this offer
- What objection it pre-empts

End with: my #1 pick + two-line explanation + the A/B test plan.
```

---

## Prompt 5 — 15-step VSL skeleton filler

```
# Role
A 15-step VSL practitioner who knows the full structural sequence from hook to stack to close.

# Task
Fill in the 15-step skeleton for my VSL. Each step is 1–3 bullets summarizing what that step will say (not full script copy — just the logical beats).

# Inputs
ICP: {{ICP_SUMMARY}}
Offer: {{OFFER_ONE_LINER}}
Unique mechanism: {{UNIQUE_MECHANISM}}
Primary belief to install: {{PRIMARY_BELIEF}}
Primary pain / desire: {{PAIN_DESIRE}}
Proof stack available (case studies, numbers, authority markers): {{PROOF_STACK}}
Guarantee: {{GUARANTEE}}

# Constraints
- Each step must serve the next. No orphan beats.
- No banned vocabulary.
- If a step cannot be filled from the inputs, mark it and propose what input I need.

# Output format
1. Hook (one sentence of the hook)
2. Big promise (what the VSL will deliver by the end)
3. Credibility injection (who's speaking + why trust them)
4. Problem framing (the pain)
5. Agitation (why the pain is worse than they think)
6. New opportunity (the reframe)
7. Unique mechanism intro
8. Mechanism demo (how it works, 2–4 components)
9. Proof (case study / numbers / authority)
10. Offer transition (why this mechanism requires help to implement)
11. Stack (components + total value)
12. Price reveal + contrast
13. Guarantee / risk reversal
14. Scarcity (real, not manufactured)
15. Close + CTA

End with: the 3 steps that need the most additional input to ship, and the question that unlocks each.
```

---

## Prompt 6 — VSL hook-to-opener bridge rewriter

```
# Role
A VSL editor who rewrites the first 60 seconds — the hook + the first 30 seconds of body — to compound retention instead of losing it.

# Task
Rewrite my current hook + opener to improve 30-second retention. Propose 3 alternative versions.

# Inputs
Current hook + opener (paste verbatim): {{CURRENT_OPENER}}
Current 30-second retention rate (if known): {{RETENTION_RATE}}
ICP: {{ICP_SUMMARY}}
Offer: {{OFFER}}

# Constraints
- Hook to body transition must not feel like a bait-and-switch.
- Body must immediately earn the attention the hook gained.
- No banned vocabulary.

# Output format
| # | Version | Hook | Opener | Retention play |
|---|---|---|---|---|

End with: which version I'd A/B test first + the retention-rate threshold at which I'd roll it out.
```

---

## Prompt 7 — 8-belief audit

```
# Role
An 8-belief VSL auditor. You check a VSL against the 8 Required Beliefs the viewer must hold by the end to buy: (1) transformation is possible, (2) transformation is desirable, (3) I can be transformed, (4) urgency, (5) this specific offer is the right vehicle, (6) this offer is better than alternatives, (7) I trust the person selling, (8) I trust the expertise.

# Task
Audit my VSL script against the 8 beliefs. For each belief, score 0–10 based on how strongly the script installs it. Identify the weakest belief(s) and propose concrete script changes.

# Inputs
Current VSL script (paste): {{VSL_SCRIPT}}
ICP: {{ICP_SUMMARY}}
Offer: {{OFFER}}

# Constraints
- Score on evidence from the script, not vibes.
- For each weak belief (< 6 / 10), propose specific lines to add or swap.
- Flag if a belief is installed too late (after the close window opens).

# Output format
| # | Belief | Score (0-10) | Where installed (line/beat) | Gap | Fix |
|---|---|---|---|---|---|

End with: the 2 weakest beliefs + the exact lines to insert + where in the script.
```

---

## Prompt 8 — VSL iteration after poor test

```
# Role
A VSL diagnostic specialist who reads paid-traffic test data and attributes poor performance to the right VSL section.

# Task
My VSL tested and underperformed. Given the retention curve, opt-in rate, and close rate below, diagnose which section is failing and propose the minimal-cost iteration to fix it.

# Inputs
VSL length: {{VSL_LENGTH_MINUTES}} min
Retention curve (percentages at key timestamps): {{RETENTION_CURVE}}
Opt-in / sign-up rate at CTA: {{OPT_IN_RATE}}
Close rate (of those who opt-in): {{CLOSE_RATE}}
Traffic source + ICP match: {{TRAFFIC_AND_ICP}}
Benchmark retention / opt-in / close for this archetype: {{BENCHMARKS}}

# Constraints
- Don't rewrite the whole VSL. Find the one section.
- Propose a test that isolates the fix.

# Output format
Diagnostic:
- Retention drop location(s) + probable cause
- Opt-in gap vs benchmark + probable cause
- Close gap vs benchmark + probable cause

Prescription:
- The one section to iterate first
- The 3 candidate rewrites for that section
- The A/B test spec (sample size, duration, success criteria)

End with: kill criteria — the test result at which I give up on this VSL and start fresh.
```

---

## Prompt 9 — VSL voice-calibration rewrite

```
# Role
A voice-calibration specialist. You take a VSL draft written in generic copy and rewrite it in the creator's actual voice — using their verbatim phrases, their sentence rhythm, their signature words.

# Task
Rewrite the VSL draft below in my brand voice. Use the phrases_to_use list where possible. Avoid every phrase in phrases_to_avoid.

# Inputs
Current VSL draft: {{VSL_DRAFT}}
Brand voice document summary: {{BRAND_VOICE_SUMMARY}}
phrases_to_use (verbatim): {{PHRASES_TO_USE}}
phrases_to_avoid: {{PHRASES_TO_AVOID}}
Signature sentence patterns (e.g., "I used to X, now I Y", or "Most people think A, but the truth is B"): {{SIGNATURE_PATTERNS}}

# Constraints
- Preserve the logical structure (don't drop beats).
- Use verbatim phrases from phrases_to_use wherever natural.
- Do not use any phrase from phrases_to_avoid.
- Rhythm: mirror the creator's sentence length variance.

# Output format
- Full rewritten VSL script
- A change log: which phrases I inserted from phrases_to_use, which I replaced, which I kept as original

End with: 3 lines I added that most strongly signal the creator's voice + why they land.
```

---

## Prompt 10 — Post-close Q&A pre-empter

```
# Role
A post-close objection pre-empter. You know the questions that come in the first 5 minutes after a VSL ends — DMs, replies, chatbot pings — and you write the Q&A or FAQ that pre-empts 80% of them.

# Task
Write 10 Q&A entries for the page that appears immediately after my VSL ends. Each Q is in the voice of a hesitant prospect. Each A resolves in under 90 words.

# Inputs
Offer: {{OFFER}}
Price: {{PRICE}}
Guarantee: {{GUARANTEE}}
Top 20 objections from the objection library: {{OBJECTIONS}}
Brand voice: {{BRAND_VOICE}}

# Constraints
- Q's in prospect's voice (casual, sometimes hesitant).
- A's confident but not dismissive.
- No banned vocabulary.

# Output format
| # | Question (prospect voice) | Answer (brand voice, ≤90 words) | Objection it counters |
|---|---|---|---|

End with: the 3 Q's where A's likely need testing + what to track.
```

---
*v1.0 — drop-in prompts for VSL construction. Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
