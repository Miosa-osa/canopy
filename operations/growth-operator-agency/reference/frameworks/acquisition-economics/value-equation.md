# Value Equation - the acquisition economist Operator Version

> **Source:** the acquisition economist, a high-value offer canon + *a high-value offer canon Implementation Guide* (21-day build)
> **Companion:** `reference/frameworks/primitives/value-equation.md` (operator-agnostic primitive)

This file is the the acquisition economist-specific encoding. The primitive file covers the equation as a general tool; this file covers how the acquisition economist *operates* on each variable, including the Implementation Guide's specific dial-settings.

## The Equation

```
            Dream Outcome  ×  Perceived Likelihood of Achievement
Value  =  ───────────────────────────────────────────────────────
                Time Delay  ×  Effort & Sacrifice
```

Two things create value (numerator, multiplicative). Two things destroy value (denominator, also multiplicative). Because the equation is geometric, **the weakest variable dominates the whole**. If Effort is infinite, no amount of Dream Outcome saves the offer.

## Dialing Dream Outcome (numerator)

the acquisition economist's Implementation Guide Step 3 forces one specific exercise: "Help [avatar] achieve [specific outcome] so they can [deeper benefit/status gain]." Two clauses. The first clause is the metric. The second clause is the identity shift.

Examples from the Guide:
- "Busy executives over 40 who want to lose 20+ pounds without giving up business dinners"
- "Local service businesses doing $500K-$2M who struggle to hire quality employees"

The operator-level move: stop writing outcomes like "grow your business." Write outcomes with a number, a timeframe, and a constraint ("without giving up X"). The constraint signals that you understand the real-life friction - which itself boosts Perceived Likelihood.

## Dialing Perceived Likelihood (numerator)

This is the variable most operators misdiagnose. Operators assume "credibility" fixes it. It doesn't - the real levers are:

1. **Specificity of proof for people like them.** Not generic social proof; isomorphic case studies (same starting situation → same outcome via same process).
2. **A named mechanism.** The proprietary method that makes your version different.
3. **A guarantee structured as risk reversal.** Implementation Guide Step 8 lists five guarantee types: Unconditional, Conditional, Service, Anti-Guarantee, Performance. Strongest appropriate = winner.
4. **Pre-handling the top 10 objections inside the offer itself** (via bonuses - see grand-slam-offer.md).

The Implementation Guide's test: "Would you pay this price for this value?" and "Can you say it without cracking a smile?" If yes - Perceived Likelihood is probably high enough for that price point.

## Dialing Time Delay (denominator - minimize)

Guide Step 4 maps Time Problems separately from Effort Problems. Common Time Problems:
- Total time from purchase to first outcome
- Setup/onboarding time
- Learning curve before first win

Minimization moves:
- **Engineer the phase-1 quick win.** Something they experience in the first 7 days so the money-doubt dies early.
- **Pre-built assets.** Templates, scripts, checklists - anything that removes setup time.
- **Done-for-you components.** The highest-leverage Time reducer; expensive to deliver but moves the whole ratio.
- **Predictable timeline milestones.** "Day 7 - first call. Day 30 - first result. Day 90 - stable outcome." Time is less painful when it's scheduled.

## Dialing Effort & Sacrifice (denominator - minimize)

This is where most offers are built to lose. Guide Step 4 categorizes Effort Problems as:
- Skill requirements ("they need to know how to...")
- Time commitment per week
- Things they have to stop doing
- Social/emotional cost (ego blow, public failure risk, learning curve)

Minimization moves:
- **Done-for-you > done-with-you > do-it-yourself.** The Guide's Delivery Cube (Step 6). DFY is the Effort-destroyer; DIY is the Effort-maximizer.
- **Template library.** Anything that reduces figure-it-out cost.
- **Private community for emotional/social risk.** Isolates the "looking stupid" cost.
- **Remove pre-requisites.** If the offer needs skill X, build skill X into a bonus.

## The Scoring Discipline

Score each variable 1-10. Multiply.

| Score | Meaning |
|---|---|
| <50 | Weak. Revise or shelve. |
| 50-150 | Competitive. Can scale. |
| 150-500 | Grand Slam threshold. Scale hard. |
| >500 | Category-defining. Rare. |

The high-value stacked offer definition requires ≥150. The Implementation Guide Step 12 pricing rule aligns: "Price should be 10-20% of total value stack."

## the acquisition economist-Specific Repositioning Protocol

When an offer underperforms, the acquisition economist's Guide says to diagnose which of the four variables is actually broken, not to add more bonuses. The Troubleshooting Guide is explicit:

| Symptom | Variable at fault | Fix |
|---|---|---|
| Prospects aren't excited | Dream Outcome too generic | Tighten avatar, increase outcome specificity |
| Price objections are common | Perceived Likelihood low OR Effort high | Strengthen guarantee; add bonuses that reduce Effort |
| Not enough leads | Usually hook/naming problem (not offer) | Improve M-A-G-I-C naming, add urgency |
| Customers don't get results | Effort too high - they can't execute | Simplify delivery; add implementation support |

## The Order-of-Operations Rule

Most operators attack the numerator. The higher-leverage move:

1. **Diagnose which variable is weakest** (1-10 scoring, honest).
2. **If the weakest is in the denominator** - fix that first, even if the numerator looks unfinished. A 10×10 / 1×1 offer (100) beats a 10×10 / 5×5 offer (4).
3. **Only after the denominator is tight** - amplify the numerator. A 10×10 / 1×1 offer that becomes a 10×10 / 1×1 *with bigger Dream Outcome* becomes a 20×10 / 1×1 = 200.

This is the inverse of how most operators intuitively work. The Implementation Guide forces the right order by running Phase 4 (Guarantee, Scarcity/Urgency, Bonuses - all denominator-side) before Phase 5 (Pricing).

## Anti-Patterns (from the Guide and Closing Playbook)

- **Making Dream Outcome unrealistic.** "Make $100K/month in your first week" - drops Perceived Likelihood to zero, kills the whole equation.
- **Stacking bonuses without objection-targeting.** Each bonus should counter one specific objection. Generic bonuses ("lifetime access") don't move the equation.
- **Reducing Effort by removing substance.** If "we'll do it for you" means "you get nothing," Perceived Likelihood collapses.
- **Guarantee without risk reversal.** "30-day money back" is weak. "Keep working with you until you get the result" is strong.
- **Pricing below value-signal.** Cheap prices = not-serious signal. The Closing Playbook rule: "The more expensive it is, the easier it is to sell because you're dealing with better people."

## Skill Bindings

- `/design-offer` - entire skill runs the Value Equation scoring exercise.
- `/offer-repositioning` - diagnose weakest variable.
- `/guarantee-copy` - lever on Perceived Likelihood.
- `/name-mechanism` - direct lever on Perceived Likelihood.
- `/build-vsl` - every VSL amplifies all 4 variables.

## Source

- the acquisition economist, *a high-value offer canon Implementation Guide* - Phase 2 Steps 3-5 (Dream Outcome, Problems List, Solutions), Phase 4 Steps 8-11 (Guarantee, Scarcity, Bonuses, Naming), Phase 5 Step 12 (Pricing).
- the acquisition economist, a high-value offer canon (book, 2021).
- `reference/frameworks/primitives/value-equation.md` - generic primitive.
- `reference/frameworks/offer-architecture/grand-slam-offer.md` - how the equation assembles into a full offer.

---
*v1.0 - 2026-04-19. the acquisition economist-specific operator encoding of the Value Equation.*
