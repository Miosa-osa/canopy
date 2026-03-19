# Runbooks

> Standard operating procedures for common tasks. Agents follow these
> step-by-step. Humans update them when procedures change.

---

## Runbook: Incident Response

**Trigger**: System alert, user report, or security detection
**Owner**: CTO + Security Lead

1. **Detect** — Confirm the incident is real (not false positive)
2. **Classify** — Severity: P0 (critical), P1 (high), P2 (medium), P3 (low)
3. **Communicate** — Notify relevant team lead(s) and CTO
4. **Contain** — Stop the bleeding (rollback, disable feature, block access)
5. **Investigate** — Root cause analysis with evidence
6. **Resolve** — Fix the root cause, verify fix
7. **Postmortem** — Document: timeline, root cause, impact, prevention

## Runbook: New Feature Deployment

**Trigger**: Feature approved and code reviewed
**Owner**: Engineering Lead

1. Deploy to staging environment
2. Run full test suite on staging
3. Security Lead reviews if auth/data/infra impacted
4. Smoke test critical paths manually
5. Deploy to production with monitoring active
6. Verify health checks pass
7. Monitor for 30 minutes post-deploy
8. Report deployment status to CTO

## Runbook: Budget Reallocation

**Trigger**: Team needs more budget than allocated
**Owner**: CTO

1. Requesting team lead submits justification (what for, how much, from where)
2. CTO reviews: is this the right priority?
3. Source team lead confirms they can absorb the reduction
4. CTO approves and updates budgets/team-allocations.yaml
5. Audit log entry created

## Runbook: Agent Reconfiguration

**Trigger**: Agent underperforming or role change needed
**Owner**: Team Lead

1. Document the issue (what's failing, how often, impact)
2. Review agent definition for gaps in rules or process
3. Propose changes to agent config
4. CTO approves changes
5. Update agent file, run validation
6. Monitor for 1 week to verify improvement

---

*Runbooks are living documents. Update after every incident or process improvement.*
