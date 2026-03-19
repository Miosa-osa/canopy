# /debug

> Systematic bug investigation: reproduce, isolate, hypothesize, fix, verify, prevent.

## Usage
```
/debug "<description>" [--bisect] [--trace]
```

## What It Does
Follows a systematic debugging protocol to find and fix bugs. Generates hypotheses ranked by likelihood, tests them methodically, implements a minimal fix, and adds a regression test.

## Implementation
1. **REPRODUCE** -- create consistent reproduction steps from the description.
2. **ISOLATE** -- narrow to the smallest reproduction case. Check recent changes with `git log`.
3. **HYPOTHESIZE** -- form 2-3 specific, testable theories ranked by likelihood.
4. **TEST** -- validate hypotheses systematically, starting with most likely.
5. **FIX** -- implement minimal, targeted fix addressing root cause.
6. **VERIFY** -- confirm fix resolves the issue without regressions.
7. **PREVENT** -- add regression test to prevent recurrence.

If `--bisect`: use `git bisect` to find the commit that introduced the bug.
If `--trace`: add detailed logging to trace execution path.

## Examples
```bash
# Debug a specific issue
/debug "API returns 500 intermittently on /users endpoint"

# Use git bisect to find when bug was introduced
/debug "Search results are empty" --bisect

# Add tracing to understand execution flow
/debug "Session expires too early" --trace
```
