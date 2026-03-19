# CI/CD Pipeline Configuration

> Pipeline stages, environments, and rollback procedures. Load when deploying
> or configuring pipelines.

## Environments

| Environment | Purpose | Deploy Trigger | Approval |
|-------------|---------|---------------|----------|
| Development | Local dev + feature testing | Manual | None |
| Staging | Pre-production verification | Auto on merge to `main` | None |
| Production | Live user traffic | Manual after staging verification | tech-lead or devops |

## Pipeline Stages

### On Pull Request

```yaml
stages:
  - lint:
      runs: eslint + prettier check
      blocks: merge
      timeout: 2m

  - typecheck:
      runs: tsc --noEmit
      blocks: merge
      timeout: 3m

  - unit-test:
      runs: vitest run --coverage
      blocks: merge if coverage < 80%
      timeout: 5m

  - integration-test:
      runs: vitest run --config vitest.integration.config.ts
      requires: database service container
      blocks: merge
      timeout: 10m

  - security-scan:
      runs: npm audit + snyk test
      blocks: merge on P0/P1 CVEs
      warns: on P2+ CVEs
      timeout: 5m

  - build:
      runs: docker build
      blocks: merge
      timeout: 5m
```

### On Merge to Main (Deploy to Staging)

```yaml
stages:
  - all-pr-checks:
      runs: full PR pipeline above
      blocks: deploy

  - build-image:
      runs: docker build + push to registry
      tags: sha-{commit_sha}, staging-latest

  - deploy-staging:
      strategy: rolling
      health_check: /api/health
      timeout: 5m

  - staging-smoke:
      runs: playwright test --config smoke.config.ts
      against: staging URL
      timeout: 5m

  - notify:
      sends: deployment summary to Slack
```

### Production Deploy (Manual Trigger)

```yaml
prerequisites:
  - staging deploy successful
  - staging smoke tests pass
  - manual approval from tech-lead or devops

stages:
  - pre-deploy-check:
      validates: staging image matches production target
      checks: no Friday deploy (unless P0 override)

  - deploy-production:
      strategy: rolling (default) | canary | blue-green
      health_check: /api/health
      rollback_on: health check fail OR error rate > 2x baseline
      timeout: 10m

  - post-deploy-monitor:
      duration: 30m
      watches: error rate, latency p95, throughput
      alerts: if metrics deviate > 20% from baseline

  - notify:
      sends: production deployment summary
```

## Rollback Procedure

### Automated Rollback (During Deploy)
Triggered automatically when:
- Health check fails on any new instance
- Error rate exceeds 2x baseline during rollout
- Deployment timeout exceeded

Action: revert to previous image tag, verify health.

### Manual Rollback (Post-Deploy)
```bash
# Identify the previous stable image
docker images --filter "reference=app" --format "{{.Tag}}" | head -5

# Deploy previous image
kubectl set image deployment/app app={registry}/{image}:{previous_tag}

# Verify rollback
kubectl rollout status deployment/app
curl -f https://app.example.com/api/health
```

### Database Rollback
- Forward-only migrations: never edit a deployed migration
- If schema change causes issues: deploy a NEW migration that reverts the change
- Always test migration + rollback migration on staging before production

## Branch Protection Rules

### `main` Branch
- Require PR with at least 1 approval
- Require all CI checks to pass
- No force pushes
- No direct commits
- Require up-to-date branch before merge

## Secrets Management

- CI secrets stored in GitHub Actions secrets (encrypted)
- Application secrets stored in environment-specific secret manager
- Secret rotation: API keys quarterly, tokens monthly
- NEVER commit secrets to the repository
- NEVER log secrets (even in debug mode)
