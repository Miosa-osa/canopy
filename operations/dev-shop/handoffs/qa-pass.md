# QA Pass Handoff Template

> Used when QA approves a PR/feature for final review and deployment.

## Handoff: QA Approval

**From:** qa-engineer  **To:** tech-lead  **Phase:** Test -> Review
**Feature:** {feature name}  **PR:** {PR number}  **Date:** {date}

### Verdict: APPROVED

### Test Results
| Category | Pass | Fail | Skip | Coverage |
|----------|------|------|------|----------|
| Unit | {n} | 0 | {n} | {%} |
| Integration | {n} | 0 | {n} | {%} |
| E2E | {n} | 0 | {n} | -- |
| Manual | {n} | 0 | -- | -- |

### Coverage Change
- Before: {%} -> After: {%} ({+/-}%)

### What Was Tested
- {Test scenario 1}: PASS
- {Test scenario 2}: PASS
- {Edge case tested}: PASS

### Regression Sweep
- {Adjacent feature 1}: No regression
- {Adjacent feature 2}: No regression

### Quality Assessment
- Code correctness: Verified
- Error handling: Verified
- Performance: Within budget
- Accessibility: {Verified / N/A}

### Notes for Reviewer
{Anything the tech-lead should pay extra attention to during final review}

### Signal Quality
- S/N score: {score}  Mode: data  Genre: report
