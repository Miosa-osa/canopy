# Test

## Command
/test [scope] [--type unit|integration|e2e|all] [--coverage]

## Purpose
Run test suite with optional scope filtering and coverage reporting.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| scope | string | No | File, directory, or module to test. Default: all |
| --type | string | No | Test type filter. Default: all |
| --coverage | flag | No | Generate coverage report |

## Output
Genre: report
Format: Markdown test results + coverage summary

Produces:
1. **Test Results** -- pass/fail counts by category
2. **Failed Test Details** -- specific failures with error messages
3. **Coverage Report** (if --coverage): statement, branch, function, line percentages
4. **Quality Gate Status** -- PASS if meets thresholds, FAIL with specifics

## Agent Activation
- **qa-engineer** (wave 1): Analyzes results, assesses quality gate compliance

## Process
```
1. Run specified test suite
2. Collect results and coverage data
3. QA engineer evaluates against quality thresholds
4. Generate structured report
5. Flag any coverage decreases from baseline
```

## Examples
```
/test
/test src/services/ --type unit --coverage
/test --type integration
/test src/api/users.test.ts
```
