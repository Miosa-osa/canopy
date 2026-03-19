# Deploy

## Command
/deploy <environment> [--branch <branch>] [--strategy rolling|blue-green|canary]

## Purpose
Deploy to target environment with automated verification and rollback capability.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| environment | string | Yes | Target: staging, production |
| --branch | string | No | Branch to deploy. Default: main |
| --strategy | string | No | Deployment strategy. Default: rolling |

## Output
Genre: runbook-execution
Format: Markdown deployment log

Produces:
1. **Pre-Deploy Checklist** -- all prerequisites verified
2. **Deployment Log** -- step-by-step execution with timestamps
3. **Health Check Results** -- endpoint status, error rates, latency
4. **Post-Deploy Verification** -- smoke test results
5. **Rollback Instructions** -- if issues detected

## Agent Activation
- **devops** (wave 1): Deployment execution, monitoring, rollback if needed

## Process
```
1. Verify prerequisites (CI green, staging verified for prod deploys)
2. Block production deploys on Friday/weekend unless P0 hotfix
3. Execute deployment per selected strategy
4. Run health checks on each deployed instance
5. Monitor error rates for 30 minutes post-deploy
6. Auto-rollback if health checks fail
7. Generate deployment report
```

## Examples
```
/deploy staging
/deploy production --strategy canary
/deploy staging --branch feature/new-api
```
