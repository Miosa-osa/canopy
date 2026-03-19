# Build

## Command
/build <feature_name> [--agent frontend|backend|both]

## Purpose
Implement a feature or fix according to the approved spec.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| feature_name | string | Yes | Feature or fix to build |
| --agent | string | No | Which dev agent to activate. Default: both |

## Output
Genre: code + spec
Format: Implementation files + test files + PR description

Produces:
1. **Implementation** -- code changes per spec
2. **Tests** -- unit + integration tests for changed behavior
3. **PR Description** -- what changed, why, how to test, rollback notes

## Agent Activation
- **frontend-dev** (wave 1): UI implementation if feature has frontend component
- **backend-dev** (wave 1): API/business logic if feature has backend component
- Both agents work in parallel when both are needed

## Process
```
1. Load spec for the feature (error if no spec exists)
2. Activate appropriate dev agent(s)
3. Implement changes per spec
4. Write tests (unit + integration minimum)
5. Verify tests pass locally
6. Generate PR description
7. Submit for QA review
```

## Examples
```
/build "user-profile-page"
/build "add-search-endpoint" --agent backend
/build "dashboard-redesign" --agent frontend
```
