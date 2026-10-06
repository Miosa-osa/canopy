# offer-prompts

Drop-in prompts for offer design, pricing, guarantee construction, bonus brainstorming. Pair with `/design-offer` when you want fast variants instead of the full skill run.

---

## Prompt 1 — Offer variant generator

```
# Role
A senior offer architect who thinks in terms of the Value Equation (Dream Outcome × Perceived Likelihood) / (Time Delay × Effort & Sacrifice). You produce 5 meaningfully different offer architectures from a single seed — each targeting a different awareness level or buyer segment.

# Task
Generate 5 offer variants of {{CORE_PRODUCT}} for {{ICP_SUMMARY}}. Each variant should solve the same underlying problem but with a distinct angle on price, format, delivery, or belief installed.

# Inputs
Core product: {{CORE_PRODUCT}}
Current price: {{CURRENT_PRICE}}
ICP: {{ICP_SUMMARY}}
Core transformation (before → after): {{BEFORE_AFTER}}
Current Value Equation score if known: {{VE_SCORE}}

# Constraints
- No copyrighted framework names.
- Each variant must be meaningfully different (not just a rename).
- Show price, delivery format, primary bonus, guarantee, and the awareness level each variant is tuned for.

# Output format
| # | Name | Price | Format | Primary bonus | Guarantee | Awareness target |
|---|---|---|---|---|---|---|

For each variant, one paragraph describing the belief-installation play and who it beats in the market.

End with: my top-2 picks + the one-line pitch of each.
```

---

## Prompt 2 — Bonus stack brainstorm

```
# Role
A bonus-stacking specialist. Every bonus you propose counters a specific objection.

# Task
For the offer below, propose 12 bonus candidates, each tied to a specific objection it counters. Then rank them by perceived-value-to-cost-to-deliver ratio.

# Inputs
Offer: {{OFFER_ONE_LINER}}
Price: {{PRICE}}
Top 10 objections from our library (if none provided, mine from ICP): {{OBJECTIONS}}

# Constraints
- Every bonus must counter a specific named objection.
- Include 4 category types: speed-up bonuses, done-for-you bonuses, ascension/after-sale bonuses, social/community bonuses.
- Note which bonuses can be low-cost-to-deliver but high-perceived-value (those should win).

# Output format
| # | Bonus | Dollar value | Objection countered | Cost to deliver | Category |
|---|---|---|---|---|---|

End with: the 5 bonuses I should actually include + a one-sentence justification for each selection.
```

---

## Prompt 3 — Guarantee copy generator

```
# Role
A guarantee-writer who knows how to construct ROI-positive guarantees that convert without tanking refund rates. You distinguish between unconditional guarantees, conditional guarantees, performance guarantees, and reversed guarantees.

# Task
Write 5 different guarantee candidates for my offer, each a different type. Include the exact customer-facing copy + the internal eligibility criteria + expected refund-rate impact.

# Inputs
Offer: {{OFFER_ONE_LINER}}
Price: {{PRICE}}
Delivery duration: {{DELIVERY_DURATION}}
Current refund rate: {{CURRENT_REFUND_RATE}}
Current close rate: {{CURRENT_CLOSE_RATE}}
Historical customer objections to price: {{PRICE_OBJECTIONS}}

# Constraints
- No fabricated results or case numbers.
- Each guarantee must be feasible to honor.
- Show the statutory rights disclaimer every guarantee needs.

# Output format
| # | Type | Customer-facing copy | Internal eligibility rules | Est. refund-rate impact | Est. close-rate lift |
|---|---|---|---|---|---|

End with: which guarantee I'd ship first + why + what to A/B it against.
```

---

## Prompt 4 — Value Equation repair

```
# Role
A diagnostic offer architect. Given a Value Equation that is below 150, you identify which of the four terms is the bottleneck and prescribe the specific fix.

# Task
Audit the current offer's Value Equation. For each of the four terms, score 1–10. Identify the term with the lowest score. Prescribe 3 concrete interventions to fix that term.

# Inputs
Offer: {{OFFER_ONE_LINER}}
Dream outcome (stated): {{DREAM_OUTCOME}}
Perceived likelihood (proof, social proof, guarantee, mechanism specificity): {{LIKELIHOOD_ELEMENTS}}
Time delay (days / weeks / months to result): {{TIME_DELAY}}
Effort & sacrifice (what customer has to do, what they give up): {{EFFORT_SACRIFICE}}

Current VE score: {{CURRENT_VE_SCORE}}

# Constraints
- Don't move all 4 terms. Find the bottleneck.
- Interventions must be concrete: rename a bonus, add a DFY component, shorten the time delay with a quick-win module, add a named customer result to prove likelihood, etc.
- Estimate each intervention's impact on the VE score.

# Output format
| Term | Current score (1-10) | Evidence / diagnostic | Bottleneck? |
|---|---|---|---|

For the bottleneck term:
- Intervention 1: description + estimated VE lift
- Intervention 2: description + estimated VE lift
- Intervention 3: description + estimated VE lift

End with: implementation sequence + 2-week milestone for each intervention.
```

---

## Prompt 5 — Price-point exploration

```
# Role
A pricing strategist who thinks in three dimensions: willingness-to-pay (from ICP), LTV:CAC feasibility (from economics), and identity signaling (what price says to the market).

# Task
Propose 4 price points for the offer: floor / value / anchor / stretch. For each, describe the buyer type it attracts, the perceived positioning, and the LTV:CAC implication.

# Inputs
Offer: {{OFFER_ONE_LINER}}
Current price: {{CURRENT_PRICE}}
Current CAC: {{CURRENT_CAC}}
Current 12-month LTV: {{CURRENT_LTV}}
ICP income range: {{ICP_INCOME_RANGE}}
Competitor price range for similar offers: {{COMPETITOR_PRICES}}

# Constraints
- Each price point must be economically feasible at 3:1 LTV:CAC.
- Note which price point requires a different ICP or different funnel to support.
- Do not recommend a price above what the delivery can back up.

# Output format
| Tier | Price | Buyer type | Positioning signal | Required LTV | Required CAC ceiling | Funnel implication |
|---|---|---|---|---|---|---|

End with: which tier I'd ship first + test plan + kill criteria (what metric tells me this price doesn't work).
```

---

## Prompt 6 — Offer-ladder construction

```
# Role
A monetization-ladder architect. You design the full stack from free lead magnet to top-of-stack mastermind, optimized for ascension velocity and LTV.

# Task
Propose a 5-rung offer ladder for my business. Each rung has a specific price, specific buyer state, specific trigger-to-next-rung, and specific LTV contribution.

# Inputs
Current flagship offer: {{FLAGSHIP_OFFER}}
Current price: {{FLAGSHIP_PRICE}}
Current ICP: {{ICP_SUMMARY}}
What I have today at each rung (or "none"):
  - Lead magnet: {{LEAD_MAGNET}}
  - Tripwire: {{TRIPWIRE}}
  - Core offer: {{CORE_OFFER}}
  - Continuity: {{CONTINUITY}}
  - High-ticket/mastermind: {{HIGH_TICKET}}

# Constraints
- Each rung must be ICP-consistent with the one above.
- No "throw-in" products. Each rung has a distinct job.
- Price gaps between rungs should be psychologically navigable (not $97 → $20K with nothing in between).

# Output format
| Rung | Product | Price | Buyer state | Trigger to next | LTV contribution |
|---|---|---|---|---|---|

End with: the single rung that's missing today that would lift overall LTV fastest + how to ship v1 in 30 days.
```

---

## Prompt 7 — Risk-reversal stack

```
# Role
A specialist in risk-reversal mechanisms beyond standard guarantees — conditional guarantees, future-day performance guarantees, "pay only if we hit X" deals, success-based pricing, earned-fee structures.

# Task
Propose 5 risk-reversal mechanisms other than "money-back guarantee" for my offer. Each should be feasible to implement and legally defensible.

# Inputs
Offer: {{OFFER_ONE_LINER}}
Delivery format: {{DELIVERY_FORMAT}}
Measurable success metric: {{SUCCESS_METRIC}}
Typical customer's starting baseline: {{STARTING_BASELINE}}
Typical timeframe to result: {{TIMEFRAME}}

# Constraints
- Mechanisms must be feasible without creating a fiduciary or securities risk.
- Must be verifiable by both parties.
- Must not encourage buyers to disengage and still claim the guarantee.

# Output format
| # | Mechanism | Customer-facing copy | Verification method | Risk to operator |
|---|---|---|---|---|

End with: which 1–2 I'd ship first, and the conditions I'd include to prevent abuse.
```

---

## Prompt 8 — Offer-fit-to-ICP audit

```
# Role
An audit specialist who reads an offer document and an ICP document side-by-side and flags every mismatch: pricing vs. income range, delivery format vs. decision style, promise vs. sophistication level, effort required vs. time available.

# Task
Audit fit between my current offer and my stated ICP. Surface every mismatch with evidence. Prescribe the change (to offer OR ICP) that would resolve each.

# Inputs
Offer document summary: {{OFFER_SUMMARY}}
ICP document summary: {{ICP_SUMMARY}}
Current close rate: {{CURRENT_CLOSE_RATE}}
Current refund rate: {{CURRENT_REFUND_RATE}}

# Constraints
- Be specific. "Price is wrong" is not an audit finding; "Price is $10K but ICP income range is $60-120K; at 10% of annual income it's too high for a single purchase without financing or heavy risk reversal" is.
- Propose the minimal change to resolve each finding.
- Distinguish offer-side fixes from ICP-side fixes (sometimes you change who you target, not what you sell).

# Output format
| Mismatch | Evidence | Resolution (offer change) | Resolution (ICP change) | Recommended |
|---|---|---|---|---|

End with: the 3 mismatches that most likely explain the current close-rate gap.
```

---
*v1.0 — drop-in prompts for offer construction and pricing. Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
