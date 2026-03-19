# Review

## Command
/review <pr_or_branch> [--focus security|performance|all]

## Purpose
Code review with severity-rated findings and approval/rejection verdict.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| pr_or_branch | string | Yes | PR number or branch name to review |
| --focus | string | No | Review focus area. Default: all |

## Output
Genre: review
Format: Markdown review with severity ratings

Produces:
1. **Summary** -- overall assessment and verdict
2. **Findings** -- BLOCKER / MAJOR / MINOR / NIT categorized issues
3. **Security Check** -- specific security review findings
4. **Performance Check** -- performance impact assessment
5. **Test Coverage** -- new/changed code test coverage
6. **Verdict** -- APPROVED / NEEDS WORK / ESCALATED

## Agent Activation
1. **qa-engineer** (wave 1): Quality and test coverage review
2. **tech-lead** (wave 1): Architecture, code quality, final approval authority

## Process
```
1. Read diff for the PR/branch
2. QA engineer reviews test coverage and quality
3. Tech-lead reviews architecture, correctness, standards
4. Both agents produce findings with severity
5. Merge findings into single review document
6. Generate verdict (tech-lead has final authority)
```

## Examples
```
/review 42
/review feature/user-search
/review 42 --focus security
```
