# Spec

## Command
/spec <feature_name> [--depth brief|full]

## Purpose
Generate a technical specification for a feature or system change.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| feature_name | string | Yes | Feature to spec |
| --depth | string | No | Spec depth: brief (1-page) or full (complete). Default: full |

## Output
Genre: spec
Format: Markdown technical specification

Produces:
1. **Goal** -- what and why
2. **Requirements** -- numbered with acceptance criteria
3. **Constraints** -- what's off the table
4. **Architecture** -- system design, affected services, API contracts
5. **Test Plan** -- what to test, edge cases
6. **Rollback Plan** -- how to undo if needed

## Agent Activation
1. **tech-lead** (wave 1): Requirements, constraints, acceptance criteria
2. **architect** (wave 1): System design, API contracts, data model

## Process
```
1. Tech-lead defines requirements and constraints
2. Architect designs system integration and API contracts
3. Combined into single spec document per tech-lead's template
4. Tech-lead reviews and approves final spec
```

## Examples
```
/spec "user-search-feature"
/spec "api-rate-limiting" --depth brief
```
