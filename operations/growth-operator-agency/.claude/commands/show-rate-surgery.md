---
description: Fix booked-to-show conversion on an application funnel. Ingests baseline metrics, outputs 4-intervention stack (SMS cadence / window tightening / quality filter / deposit). Target lift to 70%+ show rate. Direct revenue lever on application-funnels with show rates below benchmark.
argument-hint: [optional: current show rate, e.g. "43%" or "0.43"]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

Load + execute `skills/show-rate-surgery/SKILL.md` via the runtime binding at `skills/show-rate-surgery/adapters/claude-code.md`.

## Runtime entry

1. Read `skills/show-rate-surgery/adapters/claude-code.md` (the full runtime contract).
2. Follow its Runtime Behavior section end-to-end.
3. Pass `$ARGUMENTS` through as the baseline show rate if provided.

`$ARGUMENTS`

## Inputs

- Current show rate (booked → held) — from `company.yaml` Compartment 8 or passed via `$ARGUMENTS`.
- Booked-call volume per month — establishes dollar leverage of any show-rate lift.
- Average order value — used to compute the dollar delta from a held-rate improvement.

Benchmarks: organic application funnels typically show 50–60% baseline; paid funnels 30–45%. Target after intervention stack: 70%+.

---
*Top-level slash-command binding for /show-rate-surgery v1.0*
