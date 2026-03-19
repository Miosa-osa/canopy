# Bug Fix Workflow

> Fast-track pipeline for production bugs. Shortened cycle optimized for speed.

## Overview

```
Triage -> Fix -> Test -> Deploy
```

Bypasses Spec and Design phases. Goes directly from triage to implementation.

---

## Severity-Based SLA

| Severity | Triage | Fix | Test | Deploy | Total SLA |
|----------|--------|-----|------|--------|-----------|
| P0 - Critical | 5 min | 2 hours | 30 min | 30 min | 3 hours |
| P1 - High | 15 min | 4 hours | 1 hour | 1 hour | 6 hours |
| P2 - Medium | 1 hour | 1 day | 4 hours | 4 hours | 2 days |
| P3 - Low | 1 day | 1 sprint | Next QA cycle | Next deploy | Current sprint |

---

## Phases

### Phase 1: Triage

- **Owner**: tech-lead
- **Goal**: Confirm severity, assign to appropriate dev, define scope of fix
- **Evidence gate**: Severity confirmed, root cause hypothesized, owner assigned
- **Agents activated**:
  - Wave 1: tech-lead (severity assessment, assignment)
- **Max duration**: per SLA above

### Phase 2: Fix

- **Owner**: frontend-dev or backend-dev (based on bug location)
- **Goal**: Fix the root cause, not the symptom. Write regression test.
- **Evidence gate**: Fix implemented, regression test written, existing tests pass
- **Agents activated**:
  - Wave 1: assigned dev (fix + regression test)
- **Max duration**: per SLA above

### Phase 3: Test

- **Owner**: qa-engineer
- **Goal**: Verify the fix works and nothing else broke
- **Evidence gate**: Bug verified fixed, regression test passes, no regressions
- **Max retries**: 2 (shortened loop for urgency)
- **Agents activated**:
  - Wave 1: qa-engineer (verify fix, regression sweep)

### Phase 4: Deploy

- **Owner**: devops
- **Goal**: Deploy fix to production
- **Evidence gate**: Deployment successful, bug confirmed resolved in production
- **Agents activated**:
  - Wave 1: devops (deploy, verify, monitor)
- **Note**: P0 hotfixes may skip staging if tech-lead approves. Document the exception.

---

## P0 Emergency Protocol

For P0 (service down, data loss, security breach):

1. **Mitigate first**: Rollback, scale, or isolate. Don't debug while users are impacted.
2. **Fix after mitigation**: Once bleeding stops, root-cause and fix properly.
3. **Staging skip allowed**: tech-lead can approve direct-to-production for P0 only.
4. **Post-incident**: Incident report required within 24 hours (per devops template).
