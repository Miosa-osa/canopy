---
name: harden
description: "Apply security hardening to a project — headers, configs, dependencies, and best practices. Scans current security posture and applies measures: HSTS, CSP, X-Frame-Options headers; dependency CVE updates; auth strengthening; input validation; config tightening. Produces a before/after comparison. Use when preparing a project for production deploy or after a security audit flags issues."
user-invocable: true
triggers:
  - harden
  - security hardening
  - secure project
  - add security headers
  - fix vulnerabilities
  - harden server
---

# /harden

> Apply security hardening to a project — headers, configs, dependencies, and best practices.

## Usage

```bash
/harden [path] [--focus <headers|deps|auth|all>] [--dry-run]
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `path` | string | `.` | Project root to harden |
| `--focus` | enum | `all` | Hardening scope: `headers`, `deps`, `auth`, `all` |
| `--dry-run` | flag | false | Show hardening plan without applying changes |

## Workflow

1. **Assess current state** — detect project framework and scan each domain:
   - **Headers**: grep response middleware/plugs for HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy.
   - **Dependencies**: run `mix audit` (Elixir), `npm audit` (Node), `cargo audit` (Rust), or `pip-audit` (Python) to list known CVEs.
   - **Auth**: check password hashing algorithm and rounds, session timeout settings, CSRF protection, token expiration.
   - **Input**: check for validation on user-facing endpoints (Ecto changesets, Zod schemas, JSON Schema, etc.).
   - **Config**: check for debug mode, exposed server headers, cookie flags (Secure, HttpOnly, SameSite).
2. **Generate hardening plan** — prioritized list of improvements by severity (critical CVEs first, then missing headers, then config).
3. **Apply changes** (unless `--dry-run`):
   - **Headers**: add missing security headers in the appropriate middleware layer.
   - **Dependencies**: update vulnerable packages to patched versions; flag any that require major version bumps.
   - **Auth**: strengthen hashing rounds, add session timeout, enable CSRF if missing.
   - **Input**: add validation schemas on unvalidated endpoints.
   - **Config**: disable debug mode, suppress server version header, set secure cookie flags.
4. **Verify** — re-run the same audit commands from step 1. If issues remain, review and re-apply fixes.
5. **Report** — before/after security posture comparison with specific changes listed.

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

## Output

```markdown
## Security Hardening Report

- **Project**: my-app (Phoenix + SvelteKit)
- **Mode**: Applied (not dry-run)

### Before/After

| Category | Before | After | Changes |
|----------|--------|-------|---------|
| Headers | 1/6 | 6/6 | +HSTS, +CSP, +X-Frame, +X-Content-Type, +Referrer-Policy |
| Dependencies | 3 CVEs | 0 CVEs | Updated plug_cowboy, phoenix_html, jose |
| Auth | Weak | Strong | Session timeout 30min, bcrypt rounds 12→14, CSRF enabled |
| Config | Debug on | Hardened | Debug off, server header hidden, secure cookies |

### Critical Fixes Applied
1. **CVE-2025-1234** in `plug_cowboy` 2.6.0 → 2.7.1 (request smuggling)
2. **Missing CSP header** → Added strict policy blocking inline scripts
3. **Session cookie** missing `Secure` and `SameSite=Strict` flags
```
