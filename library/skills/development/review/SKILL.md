# /review

> Thorough code review across correctness, security, performance, and maintainability.

## Usage
```
/review [path|PR#] [--focus <area>] [--strict]
```

## What It Does
Reviews code changes across 5 dimensions: correctness, security, performance, maintainability, and testing. Produces a structured verdict with categorized findings (critical, major, minor).

## Implementation
1. **Load changes** -- read diff from file, directory, or PR.
2. **Correctness check** -- logic errors, edge cases, error handling, null checks.
3. **Security check** -- input validation, injection prevention, auth, secrets in code.
4. **Performance check** -- N+1 queries, unnecessary re-renders, memory leaks, algorithm efficiency.
5. **Maintainability check** -- naming, single responsibility, abstraction level, DRY.
6. **Testing check** -- test existence, edge case coverage, mock appropriateness.
7. **Report** -- verdict (APPROVED / CHANGES REQUESTED / BLOCKED) with categorized findings.

## Examples
```bash
# Review current changes
/review

# Review a specific file
/review lib/optimal_engine/session.ex

# Review a PR
/review 42

# Focus on security only
/review --focus security
```
