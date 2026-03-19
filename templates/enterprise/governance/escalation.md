# Escalation Protocol

> Defines when and how issues escalate up the org chart.

---

## Escalation Triggers

| Condition | Escalate To | Action |
|-----------|------------|--------|
| Agent fails 3 consecutive tasks | Team Lead | Investigate root cause, retrain or reconfigure |
| Budget exceeds 90% | CTO | Pause non-critical work, assess remaining priorities |
| Security vulnerability detected | Security Lead + CTO | Immediate review, incident workflow if severity high |
| Cross-team conflict | CTO | Mediate, make binding decision |
| Task blocked > 24 hours | Team Lead | Unblock or reassign |
| Compliance violation | CTO + Security Lead | Stop work, assess impact, remediate |
| External delivery failure | CTO | Review, correct, re-deliver with apology if needed |

## Escalation Flow

```
Issue detected
  ↓
Level 1: Agent attempts self-resolution (1 attempt)
  ↓ (failed)
Level 2: Team Lead intervenes (2 attempts)
  ↓ (failed)
Level 3: CTO resolves (final authority)
  ↓
Post-resolution: Document in escalation log, update runbooks if pattern
```

## De-escalation

Once resolved, the issue owner documents:
1. What triggered the escalation
2. What resolved it
3. What prevents recurrence
4. Whether a runbook update is needed

---

*Every escalation is a learning opportunity. Document and prevent.*
