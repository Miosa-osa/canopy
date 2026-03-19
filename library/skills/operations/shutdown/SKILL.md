# /shutdown

> End-of-day capture -- save state, log energy, seed tomorrow.

## Usage
```
/shutdown
```

## What It Does
Runs the end-of-day shutdown sequence: captures all open threads, logs energy levels, updates signal files with day's progress, and seeds tomorrow's priorities. Ensures nothing is lost between sessions.

## Implementation
1. Review `rhythm/today.md` -- what was planned vs what happened.
2. Capture open threads -- incomplete tasks, pending decisions, waiting-on items.
3. Update signal files -- mark completed items, add new signals from the day.
4. Log energy -- append to `rhythm/energy.md` with time, level, notes.
5. Seed tomorrow -- update `rhythm/week-plan.md` with carryover items.
6. Run `cd engine && mix optimal.index` to reindex any new files.

## Examples
```bash
# Run full shutdown sequence
/shutdown
```
