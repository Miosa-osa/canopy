---
name: security-auditor
description: Comprehensive security analysis and vulnerability detection
trigger: security|vulnerability|CVE|OWASP|audit|pentest|harden|compliance|secret|exploit
priority: 1
---

# Security Auditor Skill

## Activation Conditions
This skill activates when:
- Keywords detected: security, vulnerability, CVE, OWASP, audit, pentest, harden, compliance, secret, exploit
- File patterns: `.env*`, `*secret*`, `*credential*`, `Dockerfile`, `*.tf`, `*security*`
- User requests security review, audit, or hardening

## Workflow

### Phase 1: Reconnaissance
Identify the security surface and project characteristics.

```
Actions:
1. Detect project type and languages
2. Identify sensitive file patterns
3. Check for existing security configurations
4. Review .gitignore for security patterns
```

### Phase 2: Static Analysis (SAST)
Run static code analysis for vulnerabilities.

```
Tools:
- Semgrep: Multi-language SAST
- Bandit: Python-specific security
- ESLint security plugin: JavaScript/TypeScript
- Gosec: Go security

Rulesets:
- p/security-audit
- p/owasp-top-ten
- p/secrets
- p/sql-injection
- p/xss
```

### Phase 3: Dependency Analysis (SCA)
Check for vulnerable dependencies.

```
Tools:
- Trivy: Universal vulnerability scanner
- npm audit: Node.js dependencies
- pip-audit: Python dependencies
- OSV-Scanner: Cross-language CVE database

Focus:
- Known CVEs (Critical/High priority)
- Outdated packages
- License compliance
```

### Phase 4: Secret Detection
Find exposed credentials and sensitive data.

```
Tools:
- Gitleaks: Fast secret detection
- TruffleHog: Verified secret scanning

Patterns:
- AWS credentials (AKIA...)
- API keys
- Private keys
- Database connection strings
- JWT tokens
```

### Phase 5: Configuration Review
Analyze security configurations.

```
Checks:
- Security headers (HSTS, CSP, X-Frame-Options)
- CORS configuration
- Cookie security flags
- TLS configuration
- Authentication settings
```

### Phase 6: Reporting
Generate prioritized findings report.

```
Format:
- SARIF for tool integration
- Markdown for human review
- CVSS scoring
- OWASP Top 10 mapping
- CWE correlation
```

## OWASP Top 10 (2021) Coverage

| Category | Checks |
|----------|--------|
| A01 Broken Access Control | Authorization checks, IDOR, CORS |
| A02 Cryptographic Failures | TLS, encryption, key management |
| A03 Injection | SQLi, XSS, Command injection |
| A04 Insecure Design | Threat modeling, secure patterns |
| A05 Security Misconfiguration | Headers, defaults, errors |
| A06 Vulnerable Components | Dependencies, CVEs |
| A07 Auth Failures | Session, passwords, MFA |
| A08 Data Integrity | Signatures, CI/CD security |
| A09 Logging Failures | Audit logs, sensitive data |
| A10 SSRF | URL validation, network segmentation |

## Finding Severity Matrix

| Severity | CVSS | Response Time | Examples |
|----------|------|---------------|----------|
| CRITICAL | 9.0+ | Immediate | RCE, Active exploit, Secrets |
| HIGH | 7.0-8.9 | 24 hours | SQLi, XSS, Auth bypass |
| MEDIUM | 4.0-6.9 | 7 days | Info disclosure, CSRF |
| LOW | 0.1-3.9 | 30 days | Minor misconfig |

## Output Templates

### Finding Report
```json
{
  "finding_id": "SEC-001",
  "severity": "CRITICAL",
  "cvss": 9.8,
  "category": "A03:2021-Injection",
  "cwe": "CWE-89",
  "title": "SQL Injection",
  "location": {
    "file": "src/db/queries.ts",
    "line": 45,
    "column": 12
  },
  "description": "User input directly interpolated in SQL query",
  "evidence": "const query = `SELECT * FROM users WHERE id = ${userId}`",
  "remediation": "Use parameterized queries with prepared statements",
  "references": [
    "https://owasp.org/www-community/attacks/SQL_Injection",
    "https://cwe.mitre.org/data/definitions/89.html"
  ]
}
```

### Summary Report
```markdown
# Security Audit Summary

## Risk Assessment: HIGH

## Findings Overview
| Severity | Count | Categories |
|----------|-------|------------|
| Critical | 2 | A03, A06 |
| High | 5 | A01, A02, A07 |
| Medium | 8 | A05, A09 |
| Low | 3 | A05 |

## Critical Issues (Immediate Action)
1. SQL Injection in user input handling
2. Hardcoded AWS credentials

## Recommendations
1. Fix critical issues within 24 hours
2. Update vulnerable dependencies
3. Add security headers
4. Implement proper secret management
```

## Agent Coordination

### Dispatches To
- `@dependency-analyzer`: Deep SCA analysis
- `@code-reviewer`: Security-focused code review
- `@devops-engineer`: Infrastructure security

### Escalates To
- Human security team for critical findings
- Legal/compliance for regulatory issues

### Reports To
- `@master-orchestrator`: Status updates
- Session memory: Store patterns and decisions

## Self-Learning Integration

After completing security audits:
1. Save new vulnerability patterns to memory
2. Record false positive patterns for future filtering
3. Document remediation approaches that worked
4. Update baseline configurations

```
/mem-save pattern "SQL injection pattern in TypeScript template literals"
/mem-save solution "Remediated XSS by switching to React's built-in escaping"
/mem-save decision "Adopted parameterized queries project-wide"
```
