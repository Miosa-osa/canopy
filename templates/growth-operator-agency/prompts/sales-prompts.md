# sales-prompts

Drop-in prompts for objection reframes, call prep, proposal drafting, follow-up. Pair with `/sales-script`, `/objection-library`, `/call-prep`, `/proposal`.

---

## Prompt 1 — Objection reframe generator (3 layers × 3 angles)

```
# Role
An objection reframe specialist. You know that every objection has 3 layers — cognitive (the logical argument), emotional (the underlying fear), behavioral (the action alternative) — and that a strong reframe addresses all three.

# Task
Generate 3 reframes for the objection below — one per layer. Each reframe has: the reframe copy, the mechanic it uses, the follow-up question it invites.

# Inputs
Objection (verbatim from prospect): {{OBJECTION}}
Context (where in the call it landed): {{CONTEXT}}
Offer: {{OFFER_ONE_LINER}}
Price: {{PRICE}}
Brand voice: {{BRAND_VOICE}}

# Constraints
- No banned vocabulary.
- Don't be defensive.
- Reframe, don't argue.
- Each reframe ends with a question that re-engages the prospect's commitment.

# Output format
| Layer | Reframe (≤60 words) | Mechanic | Follow-up question |
|---|---|---|---|

End with: the reframe I'd lead with for this objection type + why.
```

---

## Prompt 2 — Call-prep brief generator

```
# Role
A call-prep specialist. You produce a 1-page brief a setter or closer reads 15 minutes before a discovery call — so they walk in with prospect-specific hooks, pain anchors, identity match, objection pre-empts.

# Task
Produce the 1-page pre-call brief for my call with {{PROSPECT_NAME}}.

# Inputs
Application form answers (paste): {{APPLICATION_ANSWERS}}
ICP match signals: {{ICP_MATCH}}
Offer being pitched: {{OFFER}}
Typical close-rate at this segment: {{SEGMENT_CLOSE_RATE}}

# Constraints
- 1 page — no more than 450 words.
- Action-oriented.
- Specific to this prospect.
- No banned vocabulary.

# Output format
- Prospect snapshot (name, role, company, stage)
- ICP match score (0-10) + evidence
- Primary pain anchor (verbatim from application if available)
- Primary desired outcome (verbatim)
- Decision style (solo / partner / board)
- Top-3 objections likely to come up + the pre-empt for each
- Opening tension (the 1-sentence opener that earns attention)
- Key question to surface in discovery (the single most useful question to ask this prospect)
- Offer fit diagnostic (how this offer serves this specific prospect)
- Recommended close archetype (assumptive / crossroads / question / takeaway)

End with: the 1 thing I should NOT say on this call (because it will trigger a known objection of this prospect type).
```

---

## Prompt 3 — Proposal drafter ($3K-$50K engagement)

```
# Role
A proposal writer for high-ticket consulting / coaching engagements. You write proposals that are 1-page scannable — scope, timeline, payment, risk reversal — not 15-page novels.

# Task
Draft the proposal for {{CLIENT_NAME}} based on our call notes below.

# Inputs
Call notes: {{CALL_NOTES}}
Proposed scope: {{PROPOSED_SCOPE}}
Proposed investment: {{INVESTMENT}}
Timeline: {{TIMELINE}}
Risk reversal / guarantee: {{GUARANTEE}}
Next step (sign, deposit, kickoff): {{NEXT_STEP}}
Brand voice: {{BRAND_VOICE}}

# Constraints
- 1 page max.
- No banned vocabulary.
- Scope is specific and bounded — not aspirational.
- Payment terms clear.
- Clear next-step action with a specific deadline.

# Output format
- Header (Client + Date)
- Challenge (one paragraph in client's words)
- Proposed work (bulleted scope with deliverables and milestones)
- Timeline (week-by-week or milestone-based)
- Investment (options: PIF, payment plan)
- Risk reversal
- What happens next (exact action + deadline)
- Sign-off lines

End with: the single line I'd drop if the prospect pushes back on price.
```

---

## Prompt 4 — Follow-up sequence for prospects who didn't close

```
# Role
A follow-up specialist. You know that 60–80% of high-ticket deals close on follow-up #4–6, not #1. You design 5-touch sequences that don't feel desperate.

# Task
Design a 5-touch follow-up sequence for a prospect who said "let me think about it" on the discovery call.

# Inputs
Prospect context: {{PROSPECT_CONTEXT}}
Call recap (3 sentences): {{CALL_RECAP}}
Offer: {{OFFER}}
Primary objection articulated: {{OBJECTION}}
Prospect's own words / phrases from the call: {{PROSPECT_VOC}}
Brand voice: {{BRAND_VOICE}}

# Constraints
- 5 touches across 14 days.
- Each touch has one specific job (different each time).
- No "just checking in" copy.
- No hard closes in touches 1–3.
- No banned vocabulary.

# Output format
| Day | Channel | Subject / opener | Body (≤150 words) | Job |
|---|---|---|---|---|

End with: the prospect-specific signal I'd watch for across the 14 days + the escalation to "close it or lose it" conversation.
```

---

## Prompt 5 — Discovery-question generator

```
# Role
A discovery-question specialist. You know that the quality of the discovery = the quality of the close. Generic discovery ("what are your goals?") leaves the prospect with nothing to respond to except the price at the end.

# Task
Generate 12 discovery questions for a {{SEGMENT}} prospect considering {{OFFER}}. Each question is tuned to surface pain, desire, belief, objection, or identity — not asked for politeness.

# Inputs
Segment: {{SEGMENT}}
Offer: {{OFFER}}
Common pains / desires in this segment: {{PAINS_DESIRES}}
Common objections in this segment: {{OBJECTIONS}}

# Constraints
- 12 questions total.
- 3 each in 4 categories: pain-surfacer / desire-clarifier / belief-check / objection-pre-empter.
- Open-ended (not yes/no).
- Specific, not generic.
- No banned vocabulary.

# Output format
| # | Category | Question | Purpose |
|---|---|---|---|

End with: the 3 questions I'd lead with in the first 10 minutes of the call + the sequence.
```

---

## Prompt 6 — Close-rate diagnostic

```
# Role
A close-rate diagnostician. Given a setter's or closer's call metrics, you diagnose whether the bottleneck is show-rate, discovery, pitch, objection-handling, or close-mechanic.

# Task
Diagnose my close rate. Identify the one bottleneck to fix first.

# Inputs
Calls booked: {{CALLS_BOOKED}}
Show rate: {{SHOW_RATE}}
Qualified call rate: {{QUALIFIED_CALL_RATE}}
Pitched call rate: {{PITCHED_CALL_RATE}}
Close rate (of pitched): {{CLOSE_RATE}}
Benchmark close rate for this offer type / price: {{BENCHMARK_CLOSE_RATE}}
Average call length: {{AVG_CALL_LENGTH}}
Typical objections raised: {{TYPICAL_OBJECTIONS}}

# Constraints
- Diagnose from the metric chain, not vibes.
- The one bottleneck, not three.
- Prescribe a specific fix with a 14-day measurement window.

# Output format
Metric-chain analysis:
- Funnel stage where the biggest drop-off happens + evidence
- Likely root cause + evidence

Prescription:
- The single fix (what to change in the next 14 days)
- The metric to track
- The threshold where the fix is working

End with: the kill criteria — when to abandon the fix and try a different bottleneck.
```

---

## Prompt 7 — Application-form scoring rubric

```
# Role
A qualification specialist. You design application-form scoring rubrics that filter for fit, readiness, and trust — so closers only talk to qualified prospects.

# Task
Design a scoring rubric for the application-form answers below. Each answer scores 0–3. Total score maps to outcome: call / wait-list / decline.

# Inputs
Application questions (paste all questions): {{APPLICATION_QUESTIONS}}
Offer: {{OFFER}}
Ideal-buyer profile: {{IDEAL_BUYER}}
Red flags to watch: {{RED_FLAGS}}

# Constraints
- Scoring is evidence-based.
- Red flags override scores (auto-decline even with high score if red flag present).
- No banned vocabulary.

# Output format
| Question | 0 pts | 1 pt | 2 pts | 3 pts | Red-flag trigger |
|---|---|---|---|---|---|

Thresholds:
- 0–X: decline (auto-email)
- X+1 to Y: wait-list (nurture sequence)
- Y+ (and no red flags): book call

End with: the 2 questions most predictive of close rate + why.
```

---

## Prompt 8 — Urgency-real vs. urgency-fake audit

```
# Role
An urgency auditor. Fake urgency ("only 3 spots left" when there aren't) destroys trust; real urgency (price increase / cohort start date / bonus expiration) closes.

# Task
Audit my current offer's urgency mechanisms. Flag fake, propose real.

# Inputs
Current urgency mechanisms (paste every instance from the sales page / email / VSL): {{URGENCY_MECHANISMS}}
Offer: {{OFFER}}
Available real urgency anchors (cohort dates, bonus expirations, price increases, etc.): {{REAL_URGENCY_ANCHORS}}

# Constraints
- Every mechanism must be real, not manufactured.
- "Price goes up" urgency must actually execute — don't fake it.
- No banned vocabulary.

# Output format
| Current mechanism | Real or fake | Replace with |
|---|---|---|

End with: the 3 real urgency mechanisms I should lean into + the sales-page locations to add them.
```

---

## Prompt 9 — Spousal / partner objection handling

```
# Role
A specialist in the "let me talk to my spouse / partner" objection. You know the objection is almost never about the spouse — it's about the buyer's own ambivalence or inability to justify the purchase. Your reframes surface the real objection.

# Task
Generate 5 reframes for the spousal objection, each targeting a different underlying driver.

# Inputs
Offer: {{OFFER}}
Price: {{PRICE}}
Typical prospect profile: {{PROSPECT_PROFILE}}
Brand voice: {{BRAND_VOICE}}

# Constraints
- Don't dismiss the objection.
- Don't pressure the prospect to exclude their partner.
- Surface the real objection without making the prospect feel caught.
- No banned vocabulary.

# Output format
| # | Likely real objection | Reframe copy (≤80 words) | Next question |
|---|---|---|---|

End with: the 1 reframe I'd lead with + the conversation path if the prospect holds firm.
```

---

## Prompt 10 — Deposit-call script

```
# Role
A deposit-script specialist for high-ticket close conversations. You know that deposits right on the call (before the partner / spouse / accountant check) lock in commitment and close rate.

# Task
Write the deposit-ask script for a {{PRICE}} offer where a {{DEPOSIT_AMOUNT}} deposit secures the spot + payment plan.

# Inputs
Offer: {{OFFER}}
Price: {{PRICE}}
Deposit amount: {{DEPOSIT_AMOUNT}}
Payment-plan structure: {{PAYMENT_PLAN}}
Brand voice: {{BRAND_VOICE}}
Whether deposit is refundable: {{DEPOSIT_REFUNDABLE}}

# Constraints
- Natural, not scripted-feeling.
- Clear on what deposit does (secure / commit / next step).
- Clear on refund policy.
- No banned vocabulary.

# Output format
- Setup line (how to transition from close to deposit ask)
- Deposit ask (the actual words)
- Objection pre-empt (if they hesitate — 1 reframe)
- Payment-link send + next steps
- Confirmation script (what to say immediately after the deposit lands)

End with: the 3 signals that tell me to push vs pull back on the deposit ask.
```

---
*v1.0 — drop-in prompts for sales conversations and follow-up. Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
