# Debug

## Command
/debug <issue_description> [--logs <path>] [--severity P0|P1|P2|P3]

## Purpose
Systematic debugging pipeline: reproduce, isolate, hypothesize, test, fix, verify, prevent.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| issue_description | string | Yes | Bug description or error message |
| --logs | string | No | Path to relevant log file |
| --severity | string | No | Issue severity. Default: P2 |

## Output
Genre: bug-report + fix
Format: Markdown diagnosis + code fix + regression test

Produces:
1. **Reproduction** -- exact steps and environment
2. **Root Cause Analysis** -- what went wrong and why
3. **Fix** -- code changes with explanation
4. **Regression Test** -- test that catches this specific bug
5. **Prevention** -- what to add to prevent recurrence

## Agent Activation
1. **backend-dev** or **frontend-dev** (wave 1): depending on bug location
2. **qa-engineer** (wave 2): verify fix and add regression test

## Process
```
1. Reproduce the issue (get exact steps)
2. Isolate the cause (narrow scope, check recent changes)
3. Form 2-3 hypotheses ranked by likelihood
4. Test most likely hypothesis first
5. Implement fix (root cause, not symptom)
6. QA verifies fix and adds regression test
7. Document prevention measures
```

## Examples
```
/debug "users endpoint returns 500 for names with unicode"
/debug "dashboard loads blank on Safari" --severity P1
/debug "order total calculation off by 1 cent" --logs logs/orders.log
```
