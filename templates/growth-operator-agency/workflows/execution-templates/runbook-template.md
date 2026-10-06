# Runbook Template

## Purpose
Runbook for an operational procedure — what to do when X happens or when X needs to happen on cadence. Runbooks are for repeatable operational responses; SOPs are for repeatable value-producing work. A runbook reads like a flight checklist, not an essay.

## When to Use Runbooks
- Any recurring operational response (e.g., "launch day tech readiness")
- Any alert that fires with a defined response (e.g., "show-rate drops below 55%")
- Any critical handoff between people or systems (e.g., "new hire Day 1")
- Any procedure whose failure is expensive enough that it shouldn't be remembered

## Runbook Structure

### Header
```
RUNBOOK: {title}
Owner: {role or name}
Version: {n}
Last reviewed: {date}
Review cadence: {quarterly | monthly}
Triggers: {what starts this runbook}
Outcome: {what is true when complete}
```

### 1. Triggers
Specific, measurable conditions that start the runbook. Not "when something feels off" — concrete signals.
- Trigger 1: `{metric/event}` hits `{threshold}`
- Trigger 2: ...

### 2. Prerequisites / Access
What must be in place before starting.
- Access to `{system}` as `{role}`
- Credentials: `{where stored}`
- Tools: `{list}`
- On-call: `{escalation contact}`

### 3. Step-by-Step Procedure
Numbered, atomic steps. Each step has: action, expected result, failure mode.

**Step 1.** `{action}`
- **Do**: `{exact action}`
- **Expect**: `{observable result}`
- **If fails**: `{alternative or escalation}`

**Step 2.** `{action}`
- Do: ...
- Expect: ...
- If fails: ...

(Continue for all steps.)

### 4. Verification
How to confirm the runbook achieved its outcome. Specific, testable checks.
- [ ] Check 1: `{what}` = `{expected value}`
- [ ] Check 2: ...

### 5. Rollback (if applicable)
If the procedure needs to be undone, how.
- Step 1: ...
- Step 2: ...

### 6. Escalation
When and to whom to escalate.
- If step `{n}` fails → escalate to `{role}` within `{time}`
- If runbook takes > `{time}` → page `{role}`

### 7. Changelog
| Date | Version | Change | Author |
|---|---|---|---|
| `{date}` | v1.0 | Initial | `{name}` |

## Fillable Template
```
RUNBOOK: {title}
Owner: {role}
Version: 1.0
Last reviewed: {date}
Review cadence: {cadence}
Triggers: {conditions}
Outcome: {success state}

PREREQUISITES
- ...

PROCEDURE

Step 1. {action}
Do: ...
Expect: ...
If fails: ...

Step 2. {action}
...

VERIFICATION
[ ] ...

ROLLBACK
...

ESCALATION
- If ... then ...

CHANGELOG
| {date} | v1.0 | initial | {name} |
```

## Sample Filled Runbook
```
RUNBOOK: Launch Day 0 Tech Readiness Check
Owner: Ops Director
Version: 1.2
Last reviewed: 2026-04-19
Review cadence: before every launch
Triggers: T-minus 4 hours before cart-open on launch day 0
Outcome: All systems green, launch can proceed on time

PREREQUISITES
- Stripe admin access (primary + failover processor)
- ESP admin (Customer.io)
- CDN dashboard (Cloudflare)
- Analytics (GA4 + Mixpanel + server-side attribution)
- Access to SMS provider (Twilio)
- #launch-ops Slack channel access

PROCEDURE

Step 1. Payment verification
Do: Run test purchase with real card on primary processor. Refund. Repeat on failover.
Expect: Both charges appear in Stripe + failover dashboards within 60s; refunds process within 5 min.
If fails: Check API keys, webhook endpoints. If > 10 min to resolve, page ops lead.

Step 2. Checkout page load
Do: Open checkout page in incognito + mobile + desktop. Check Core Web Vitals via Lighthouse.
Expect: LCP < 2.5s, CLS < 0.1, TBT < 300ms.
If fails: Check CDN cache status. Purge if stale. If still failing, engage engineering.

Step 3. Tracking pixel + server-side
Do: Add ?utm_test=launch to a landing URL. Visit. Purchase test.
Expect: Pixel fires (check Facebook Events Manager), server-side event fires (check tag manager), GA4 captures, Mixpanel captures. All 4 match.
If fails: Identify which layer failed. If FB pixel fails, pause FB ads until fixed.

Step 4. Email sequence triggers
Do: Submit test lead to opt-in form. Confirm Day-0 email arrives within 3 min.
Expect: Email received, links click through correctly, no spam folder.
If fails: Check sending IP reputation, SPF/DKIM/DMARC. Warm up if needed (may delay launch).

Step 5. SMS triggers
Do: Submit test lead with phone number. Confirm SMS confirmation sent.
Expect: SMS received within 90s.
If fails: Check Twilio balance + short-code status. If short-code flagged, switch to long-code immediately.

Step 6. Abandon-cart (SCA) sequence
Do: Start checkout but don't complete. Wait 60 min.
Expect: First SCA email arrives 60 min after abandon.
If fails: Check ESP automation trigger logic. Repair or disable and manually monitor abandons.

Step 7. Scarcity timer
Do: Visit order page, refresh 5 times, check timer.
Expect: Timer does not reset on refresh; counts down consistently.
If fails: Timer is fake — fix immediately. False scarcity is a trust violation.

Step 8. Analytics dashboard
Do: Open live dashboard. Confirm visitors/sales counters update in real-time as test purchases land.
Expect: Counters update within 60s.
If fails: Debug tracking chain. Revenue counter delay > 5 min is a launch-day blocker.

VERIFICATION
[ ] All 8 steps passed
[ ] No pending warnings in any system status page
[ ] Test purchases refunded
[ ] Go/no-go confirmed by launch commander

ROLLBACK
If any step fails after 30 min of debugging, delay launch by 2 hours. Communicate to audience via pre-drafted "slight delay" email. Do not proceed on yellow.

ESCALATION
- Step 1 fail > 10 min → ops lead paged
- Step 3 fail > 15 min → engineering + founder paged
- Any step fail > 30 min → delay launch, execute hour-delay comms

CHANGELOG
| 2026-02-10 | v1.0 | initial | Syed |
| 2026-03-15 | v1.1 | added failover processor check | Syed |
| 2026-04-19 | v1.2 | added server-side tracking verification | Syed |
```

## Runbook Quality Bar
- Every step atomic and testable
- Every step has failure mode + escalation
- Runbook reviewed on cadence — stale runbooks are worse than no runbooks
- Runbook tested in a dry-run before first real use
- Owner named — unowned runbook rots

## Anti-patterns (block these)
- Prose runbooks ("you should kind of check...") — use numbered, atomic steps
- Runbooks without verification — you don't know if the runbook worked
- Runbooks without escalation paths — on-call becomes a dead-end
- Stale runbooks (not reviewed in > 6 months) — quietly wrong
- Runbook describes 3 branching paths in prose — split into 3 runbooks

## Cross-references
- Templates: `workflows/execution-templates/post-mortem-template.md`, `workflows/execution-templates/rfc-decision-template.md`
- Skills: `skills/build-sop/` (SOPs vs runbooks distinction)
- Knowledge: `reference/knowledge/scale.md`, `reference/knowledge/launch.md`

---
*v1.0 — 2026-04-19.*
