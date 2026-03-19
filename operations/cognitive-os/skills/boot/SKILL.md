# /boot

Daily boot sequence — loads operating context for the day.

## What It Does
1. Loads L0 always-loaded context (all context.md abstracts)
2. Reads rhythm/today.md for daily plan
3. Reads week-plan.md for weekly priorities
4. Checks current cognitive mode
5. Runs quick health check
6. Reports: top 3 priorities, current mode, any critical health issues

## Usage
```
/boot                           # Full boot sequence
/boot --quick                   # Skip health check
```

## Engine Commands Used
```bash
cd engine && mix optimal.l0
cd engine && mix optimal.health
```

## Files Loaded
- `rhythm/today.md` — Daily working file
- `rhythm/energy.md` — Energy levels
- `week-plan.md` — Weekly execution plan
- All `*/context.md` L0 abstracts via engine

## When to Use
- Every day at session start (~3pm)
- After a long break from the system
- When you need to re-orient
