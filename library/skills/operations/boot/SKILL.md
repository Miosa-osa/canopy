# /boot

> Initialize daily operating session -- load context, generate today's plan.

## Usage
```
/boot [--quiet]
```

## What It Does
Runs the daily boot sequence: loads the week plan, generates today's working file, checks for overdue items, loads L0 context cache, and sets the operating mode. This is the first thing to run when the operator starts their day.

## Implementation
1. Load `rhythm/week-plan.md` -- current week's priorities and time blocks.
2. Generate `rhythm/today.md` -- today's schedule extracted from week plan.
3. Check `rhythm/energy.md` -- review yesterday's energy log.
4. Load L0 cache -- `cd engine && mix optimal.l0` for always-loaded context.
5. Scan signal files for overdue action items.
6. Report: today's non-negotiables, scheduled calls, energy recommendations.

If `--quiet`: skip the verbose output, just generate today.md.

## Examples
```bash
# Full boot sequence
/boot

# Quick boot without verbose output
/boot --quiet
```
