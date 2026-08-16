# /secret-scan

> Detect exposed credentials, API keys, and sensitive data in the codebase.

## Usage
```
/secret-scan [path] [--git-history] [--fix]
```

## What It Does
Scans the codebase (and optionally git history) for exposed secrets: AWS credentials, API keys, private keys, database connection strings, JWT tokens, and other sensitive data. Reports findings with exact file locations and remediation steps.

## Implementation
1. **Scan current files** -- regex patterns for common secret formats:
   - AWS: `AKIA[0-9A-Z]{16}`
   - Generic API key: `[a-zA-Z0-9]{32,}` in assignment context
   - Private keys: `-----BEGIN (RSA|EC|DSA) PRIVATE KEY-----`
   - Connection strings: `postgres://`, `mongodb://`, `redis://` with credentials
   - JWT: `eyJ[A-Za-z0-9-_]+\.eyJ[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+`
2. **Scan git history** (if `--git-history`) -- check previous commits for secrets that were later removed.
3. **Check .gitignore** -- verify .env, credential files, and key files are ignored.
4. **Report** -- location, secret type, severity, and remediation.
5. **Fix** (if `--fix`) -- add entries to .gitignore, suggest secret rotation.

## Examples
```bash
# Scan current codebase
/secret-scan

# Include git history
/secret-scan --git-history

# Scan and auto-fix .gitignore
/secret-scan --fix

# Scan specific directory
/secret-scan config/
```
