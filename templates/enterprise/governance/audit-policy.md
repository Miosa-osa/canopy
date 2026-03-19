# Audit Policy

> Defines what is logged, how long it is retained, and how it is reviewed.

---

## What Gets Logged

Every agent action produces an audit entry:

```yaml
audit_entry:
  timestamp: "2026-03-19T14:30:00Z"
  agent_id: "engineer"
  action: "build"
  task_id: "task_01HQ..."
  inputs: ["src/auth.ts"]
  outputs: ["build-report.md"]
  cost_usd: 0.45
  duration_ms: 12500
  result: "success"
  approval_gate: null               # or gate ID if triggered
  approval_status: null              # approved | denied | overridden
```

## Retention

| Data Type | Retention | Storage |
|-----------|-----------|---------|
| Agent actions | 365 days | Audit database |
| Budget transactions | 365 days | Budget ledger |
| Approval decisions | 365 days | Governance log |
| Security reviews | Indefinite | Security archive |
| Incident reports | Indefinite | Incident archive |

## Review Schedule

| Review | Frequency | Owner | Focus |
|--------|-----------|-------|-------|
| Budget review | Weekly | CTO | Spend vs plan, anomalies |
| Audit log review | Monthly | CTO | Patterns, anomalies, compliance |
| Security review | Monthly | Security Lead | Vulnerability trends, compliance |
| Compliance audit | Quarterly | CTO + Security Lead | Framework adherence |

## Red Flags

Automated alerts on:
- Agent cost spike (>2x normal for same task type)
- Unusual hours of activity
- Repeated gate overrides
- Failed security reviews
- Budget reallocation frequency

---

*Trust but verify. Audit everything, review regularly.*
