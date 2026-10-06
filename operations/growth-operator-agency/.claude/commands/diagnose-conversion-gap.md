---
description: Funnel teardown — stage-by-stage CVR vs benchmarks, $ leak waterfall, 40/40/20 root-cause (Audience/Offer/Copy/Ops), ranked fix list, recommended next skill. First-pass audit on every new client before asset work begins.
argument-hint: [optional: funnel-data file path, else pulls from company.yaml + _private/{client}/]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

Load + execute `skills/diagnose-conversion-gap/SKILL.md` via the runtime binding at `skills/diagnose-conversion-gap/adapters/claude-code.md`.

## Runtime entry

1. Read `skills/diagnose-conversion-gap/adapters/claude-code.md` (the full runtime contract).
2. Follow its Runtime Behavior section end-to-end.
3. Pass `$ARGUMENTS` through as the funnel data source if provided.

`$ARGUMENTS`

## Inputs

The skill expects a funnel-data source. By convention:
- Filled `company.yaml` (Compartment 8 — Funnel Health) for committed metrics, OR
- A spreadsheet path passed via `$ARGUMENTS` (CSV with leads → applications → calls booked → calls held → offers made → closed-won), OR
- A creator-private dataset under `_private/<client>/` (gitignored).

Expected output: stage-by-stage CVR vs benchmarks, $-leak waterfall, 40/40/20 root-cause classification (Audience / Offer / Copy / Ops), a ranked fix list, and the recommended next skill (e.g. `/show-rate-surgery` if the leak is held-rate driven).

---
*Top-level slash-command binding for /diagnose-conversion-gap v1.0*
