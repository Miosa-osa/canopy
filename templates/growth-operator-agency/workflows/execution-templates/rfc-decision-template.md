# RFC Decision Template

## Purpose
Request for Comments / decision document. Used when a decision is: (a) expensive to reverse, (b) affects multiple departments, or (c) introduces a new pattern. Forces written thinking before commitment and creates a durable record.

## When to Use
- Pricing change (any SKU)
- New department, team, or hire ≥ senior
- New tech stack component (CRM, ESP, landing page, analytics)
- Positioning or category shift
- Major offer architecture change
- Any decision reversing a prior RFC

## When NOT to Use
- Day-to-day execution choices (use standup/weekly review)
- Reversible experiments < 1 week
- Tactical copy / creative choices (just ship and measure)

## Document Structure

### Header
```
RFC-{YYYY}-{NN}: {title}
Author: {name}
Status: {draft | in-review | approved | rejected | superseded}
Date: {YYYY-MM-DD}
Deciders: {names with sign-off authority}
Review by: {YYYY-MM-DD}
```

### 1. Context
2–3 paragraphs. What is the current state? Why are we considering a change now? What triggered this RFC?

### 2. Problem
One sentence stating the problem precisely. If you cannot state the problem in one sentence, you do not understand it yet.

### 3. Options Considered
At least 3 options (meeting brainstorming standard). For each:
- **Option A: {name}**
  - Description
  - Pros
  - Cons
  - Cost / effort (time + dollars)
  - Risk
- **Option B: ...**
- **Option C: ...**

### 4. Recommendation
Which option, and why. Include the trade-offs you are explicitly accepting.

### 5. Success Metric
How we will know it worked. One or two quantifiable metrics with targets + measurement window.

### 6. Rollback Plan
If this doesn't work, how do we reverse? Cost and timeline of rollback.

### 7. Decision Log
| Date | Decider | Decision | Comment |
|---|---|---|---|
| `{date}` | `{name}` | approve / reject / block | `{reason}` |

### 8. Implementation Plan
Top-level tasks with owner + date.
- Task — owner — date
- ...

## Fillable Template
```
RFC-{YYYY}-{NN}: {title}
Author: {name}
Status: draft
Date: {date}
Deciders: {names}
Review by: {date}

CONTEXT
{2-3 paragraphs}

PROBLEM
{one sentence}

OPTIONS

Option A: {name}
- Description: ...
- Pros: ...
- Cons: ...
- Cost: {$ + time}
- Risk: ...

Option B: {name}
...

Option C: {name}
...

RECOMMENDATION
{option + rationale + accepted trade-offs}

SUCCESS METRIC
{metric 1}: target {n} by {date}
{metric 2}: target {n} by {date}

ROLLBACK PLAN
{how} — cost: {$} — timeline: {n} days

DECISION LOG
{table}

IMPLEMENTATION
- {task} — {owner} — {date}
- ...
```

## Sample Filled RFC
```
RFC-2026-07: Migrate ESP from Mailchimp to Customer.io
Author: {AUTHOR}
Status: in-review
Date: 2026-04-19
Deciders: {APPROVER}, {AUTHOR}
Review by: 2026-04-26

CONTEXT
We currently run 5 email sequences across 14,000 subscribers on Mailchimp. As we add behavioral nurture (post-VSL-watch, post-cart-abandon) and SMS, our automation logic is outgrowing Mailchimp's branching. Three consecutive launches have required manual fixes because automation conditions don't support the combinatorial rules we need.

PROBLEM
Our automation platform cannot express the behavioral branching logic our nurture and launch pipelines require, causing manual fixes on every launch.

OPTIONS

Option A: Stay on Mailchimp, add custom scripts to bridge gaps
- Description: Keep existing tool, write custom glue code to fill branching gaps
- Pros: No migration cost, team already trained
- Cons: Adds technical debt, fragile at scale, still no clean SMS integration
- Cost: 40 dev hours + ongoing maintenance
- Risk: Medium — breaks on platform updates

Option B: Migrate to Customer.io
- Description: Full migration of sequences, lists, automations, tags
- Pros: Behavioral logic native, SMS + email in one platform, better deliverability
- Cons: Migration cost, 2-4 week transition with deliverability warming
- Cost: $15K migration + $800/mo (up from $400/mo on Mailchimp)
- Risk: Medium — deliverability dip during warm-up

Option C: ActiveCampaign (alternative)
- Description: Migrate to ActiveCampaign which has similar capabilities
- Pros: Known product, moderate pricing
- Cons: SMS is a 3rd-party add-on, less clean for product-triggered events
- Cost: $8K migration + $500/mo
- Risk: Medium — same warm-up risk, weaker behavioral layer

RECOMMENDATION
Option B — Customer.io.

Rationale: Our nurture pipeline explicitly depends on behavioral branching (post-VSL-watch, post-call-no-show, post-purchase-upsell) that will only get more complex. Customer.io's native product-event model plus integrated SMS eliminates two integrations. The higher monthly cost is recouped within 3 launches at current recovery rates.

Trade-off accepted: 2-4 week deliverability warm-up during which launch cadence may be reduced. We will pre-warm the new IP with a re-engagement campaign to our most-engaged 30% of the list before launch use.

SUCCESS METRIC
- Launch-cycle manual-fix count: target 0 (was 3+) by RFC+90 days
- Email CVR during launch: target maintained ≥ current baseline (35% open rate) through migration

ROLLBACK PLAN
Dual-run both platforms for 30 days. If deliverability fails or CVR drops >15% for 2 weeks, revert to Mailchimp. Cost: $800 (dual-run month). Timeline: 2 days to switch domain auth back.

DECISION LOG
2026-04-19 | Syed | proposed
2026-04-22 | Alex | approve with pre-warm gate
2026-04-22 | Syed | approved — implement

IMPLEMENTATION
- Vendor contract signed — Syed — 2026-04-25
- Domain auth (SPF/DKIM/DMARC) added to Customer.io — Syed — 2026-04-28
- Re-engagement pre-warm campaign — Syed — 2026-05-05
- Sequences migrated — Syed — 2026-05-15
- Dual-run launch (next cycle) — Alex/Syed — 2026-06-01
```

## Anti-patterns (block these)
- RFCs for tactical choices (inflates decision cost)
- RFCs with 1 option presented ("should we do X?") — always min 3 options
- RFCs with no rollback plan — every expensive decision needs one
- RFCs with no success metric — no way to know if we were right
- Skipping RFCs for irreversible decisions — creates unrecoverable risk

## Cross-references
- Post-mortem: `workflows/execution-templates/post-mortem-template.md`
- QBR: `workflows/execution-templates/client-qbr-template.md`
- Hiring: `skills/hiring-brief/`

---
*v1.0 — 2026-04-19.*
