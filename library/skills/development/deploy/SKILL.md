# /deploy

> Build, validate, and deploy to target environment.

## Usage
```
/deploy <environment> [--dry-run] [--skip-tests] [--rollback]
```

## What It Does
Orchestrates the full deployment pipeline: build, test, validate, push, and verify. Supports staging and production environments with appropriate safeguards. Dry-run mode shows what would happen without executing.

## Implementation
1. **Pre-flight checks** -- verify branch, clean working tree, all tests pass.
2. **Build** -- compile for target environment with production optimizations.
3. **Validate** -- run smoke tests against the build artifact.
4. **Deploy** -- push to target (Docker registry, Fly.io, AWS, etc.).
5. **Health check** -- verify the deployment is healthy (HTTP checks, log monitoring).
6. **Rollback** (if `--rollback` or health check fails) -- revert to previous version.

## Examples
```bash
# Deploy to staging
/deploy staging

# Dry run to see what would happen
/deploy production --dry-run

# Rollback production to previous version
/deploy production --rollback

# Skip tests (use with caution)
/deploy staging --skip-tests
```
