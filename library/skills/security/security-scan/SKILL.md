# /security-scan

> Run comprehensive security audit: SAST, SCA, secret detection, config review.

## Usage
```
/security-scan [path] [--focus <owasp-category>] [--severity <critical|high|medium|low>]
```

## What It Does
Runs a multi-phase security audit covering static analysis (SAST), dependency scanning (SCA), secret detection, and configuration review. Maps findings to OWASP Top 10 categories with CVSS scoring. Produces a prioritized report with remediation guidance.

## Implementation

### Phase 1: Reconnaissance
Detect project type, languages, sensitive file patterns, existing security configs.

### Phase 2: Static Analysis (SAST)
- Semgrep with security-audit + owasp-top-ten rulesets
- Language-specific scanners (Bandit for Python, gosec for Go, ESLint security for JS/TS)

### Phase 3: Dependency Analysis (SCA)
- Trivy for universal vulnerability scanning
- Language-specific: npm audit, pip-audit, mix audit
- Focus: known CVEs (Critical/High), outdated packages, license compliance

### Phase 4: Secret Detection
- Gitleaks for fast scanning
- Patterns: AWS credentials, API keys, private keys, connection strings, JWTs

### Phase 5: Configuration Review
Security headers, CORS, cookie flags, TLS config, auth settings.

### Phase 6: Report
Prioritized findings with CVSS scores, OWASP mapping, CWE correlation, and remediation steps.

## Examples
```bash
# Full security scan
/security-scan

# Scan specific directory
/security-scan lib/

# Focus on injection vulnerabilities
/security-scan --focus A03

# Only show critical and high findings
/security-scan --severity high
```
