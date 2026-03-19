# /deploy

> Deploy to target environment. Engineer-owned.

## Usage
```
/deploy [--env <staging|production>] [--dry-run] [--rollback]
```

## What It Does
Runs the deployment pipeline for the target environment. Includes pre-deploy checks,
deployment execution, post-deploy verification, and rollback capability.

## Implementation
1. **Pre-check** — Verify build passes, tests green, no blockers.
2. **Deploy** — Execute deployment to target environment.
3. **Verify** — Health checks, smoke tests on deployed environment.
4. **Report** — Deployment summary with status, duration, any issues.
5. **Rollback** — If `--rollback`, revert to previous version.

## Examples
```bash
/deploy --env staging
/deploy --env production --dry-run
/deploy --rollback --env production
```
