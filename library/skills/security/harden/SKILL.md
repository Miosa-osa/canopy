# /harden

> Apply security hardening to a project -- headers, configs, dependencies, and best practices.

## Usage
```
/harden [path] [--focus <headers|deps|auth|all>] [--dry-run]
```

## What It Does
Analyzes the project's current security posture and applies hardening measures: security headers, dependency updates, authentication improvements, input validation, and configuration tightening. Produces a before/after comparison.

## Implementation
1. **Assess current state** -- scan for security headers, dependency versions, auth config, input validation.
2. **Generate hardening plan** -- prioritized list of improvements by impact.
3. **Apply changes** (unless `--dry-run`):
   - **Headers**: add HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy.
   - **Dependencies**: update packages with known CVEs.
   - **Auth**: strengthen password policy, session config, token expiration.
   - **Input**: add validation schemas where missing.
   - **Config**: disable debug mode, hide server info, set secure cookie flags.
4. **Verify** -- run security scan to confirm improvements.
5. **Report** -- before/after security posture comparison.

## Examples
```bash
# Full hardening
/harden

# Dry run to see what would change
/harden --dry-run

# Focus on security headers only
/harden --focus headers

# Focus on dependency updates
/harden --focus deps
```
