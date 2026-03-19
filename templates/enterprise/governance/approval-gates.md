# Approval Gates

> Defines what actions require human or executive approval before proceeding.

---

## Gate Definitions

| Gate | Trigger | Approver | SLA |
|------|---------|----------|-----|
| Budget Gate | Task estimated > $5 | CTO | Same session |
| External Gate | Output going to external receiver | CTO | Same session |
| Security Gate | Change touches auth/data/infra | Security Lead | 1 business day |
| Architecture Gate | New system/service/integration | CTO + Eng Lead | 2 business days |
| Compliance Gate | Regulatory-impacted change | Security Lead + CTO | 2 business days |

## Process

```
Agent proposes action
  ↓
Check: does any gate apply?
  ├── No gates → proceed
  └── Gate(s) triggered
      ↓
      Notify approver(s)
      ↓
      Approver reviews and decides: APPROVE | DENY | MODIFY
      ↓
      ├── APPROVE → proceed with audit log entry
      ├── DENY → task blocked, reason documented
      └── MODIFY → revise scope, re-submit
```

## Override Protocol

In emergencies (P0 incidents), the CTO can override any gate with documented justification.
All overrides are flagged in the monthly audit review.

---

*No gate skipping. No exceptions outside the override protocol.*
