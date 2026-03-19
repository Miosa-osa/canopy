# Compliance Requirements

> Regulatory and framework compliance requirements for this operation.

---

## Active Frameworks

| Framework | Scope | Owner | Status |
|-----------|-------|-------|--------|
| SOC2 Type II | All systems handling customer data | Security Lead | {{STATUS}} |
| GDPR | EU customer data processing | Security Lead | {{STATUS}} |
| {{FRAMEWORK}} | {{SCOPE}} | {{OWNER}} | {{STATUS}} |

## SOC2 Requirements

### Trust Service Criteria

| Criteria | Description | How We Comply |
|----------|-------------|---------------|
| Security | System protected against unauthorized access | Auth, RBAC, encryption, audit logs |
| Availability | System available per SLA | Monitoring, incident response, redundancy |
| Confidentiality | Data protected per classification | Encryption at rest/transit, access control |
| Processing Integrity | Processing accurate and authorized | Input validation, testing, review gates |
| Privacy | PII handled per privacy notice | Data minimization, consent, deletion |

## GDPR Requirements

| Requirement | Implementation |
|-------------|---------------|
| Lawful basis | Document processing purpose per data type |
| Data minimization | Collect only what's needed |
| Right to access | API endpoint for data export |
| Right to deletion | Data deletion pipeline within 30 days |
| Breach notification | 72-hour notification protocol |
| DPO | {{DPO_NAME}} or designated role |

## Compliance Checklist (Quarterly)

- [ ] All SOC2 controls verified
- [ ] GDPR data processing register updated
- [ ] Security incident log reviewed
- [ ] Third-party vendor compliance verified
- [ ] Employee/agent access reviews completed
- [ ] Audit trail integrity verified

---

*Compliance is not optional. Security Lead owns verification, CTO owns accountability.*
