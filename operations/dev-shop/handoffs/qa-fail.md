# QA Fail Handoff Template

> Used when QA rejects a PR/feature and returns it to the developer.

## Handoff: QA Rejection

**From:** qa-engineer  **To:** {dev-agent-id}  **Phase:** Test -> Build (retry)
**Feature:** {feature name}  **PR:** {PR number}  **Date:** {date}
**Retry:** {n} of 3

### Verdict: NEEDS WORK

### Issues Found

#### Issue 1: {Short Description}
- **Severity**: {BLOCKER / MAJOR / MINOR}
- **Steps to reproduce**:
  1. {step}
  2. {step}
  3. {step}
- **Expected**: {what should happen}
- **Actual**: {what actually happened}
- **Evidence**: {screenshot, log, error message}
- **Suggested fix**: {if obvious}

#### Issue 2: {Short Description}
{Same format}

### Test Results
| Category | Pass | Fail | Skip |
|----------|------|------|------|
| Unit | {n} | {n} | {n} |
| Integration | {n} | {n} | {n} |
| Manual | {n} | {n} | -- |

### What Passed
- {Scenarios that worked correctly}

### What Failed
- {Specific test or scenario}: {failure detail}

### Fix Priority
{Ordered list of what to fix first}
1. {Issue} -- BLOCKER: must fix before re-review
2. {Issue} -- MAJOR: should fix
3. {Issue} -- MINOR: fix or justify

### Re-Review Conditions
{What must be true before QA will re-review}
- [ ] Issue 1 resolved with test
- [ ] Issue 2 resolved with test
- [ ] All existing tests still pass
- [ ] Coverage has not decreased

### Signal Quality
- S/N score: {score}  Mode: data  Genre: report

### Escalation Warning
{If retry 3 of 3}: **Next failure escalates to tech-lead for resolution.**
