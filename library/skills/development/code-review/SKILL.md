---
name: code-review
description: >
  Branch code review with structured scoring against project guidelines.
  Produces categorized findings with severity levels and LLM-generated fix
  prompts. Quality gate: only posts review to PR if score meets threshold.
  Triggers on: "code review", "review branch", "review PR", "review changes", "score code"
---

# /code-review

> Structured code review with scoring, findings, and auto-generated fix prompts.

## Purpose

Review all changes on a branch (or between two refs) against project coding guidelines. Produce a scored report with categorized findings, severity levels, and actionable fix prompts that an LLM can execute directly. Supports a quality gate: if the score meets the threshold, post the review as a PR comment. If below threshold, return findings to the developer for iteration.

## Usage

```bash
# Review current branch against main
/code-review

# Review a specific branch
/code-review --branch feature/auth-refactor

# Review with custom threshold
/code-review --branch feature/auth-refactor --gate 9

# Review and post to PR if passing
/code-review --pr 42 --post-if-passing

# Review against specific guidelines
/code-review --guidelines .cursor/rules/elixir.md

# Output as JSON for CI integration
/code-review --format json
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--branch` | string | current branch | Branch to review |
| `--base` | string | `main` | Base branch to diff against |
| `--pr` | int | — | Pull request number to review |
| `--gate` | int | `8` | Minimum score (1-10) to pass quality gate |
| `--post-if-passing` | flag | false | Post review as PR comment if score >= gate |
| `--guidelines` | string | auto-detect | Path to coding guidelines file |
| `--format` | enum | `markdown` | Output format: `markdown`, `json` |
| `--severity` | enum | `all` | Filter findings: `all`, `critical`, `major`, `minor` |
| `--fix-prompts` | flag | true | Generate LLM fix prompts for each finding |
| `--max-files` | int | `50` | Maximum files to review (largest diff first) |

## Workflow

1. **Diff** — Compute the full diff between `--base` and `--branch`. Identify all changed files, additions, deletions, and modifications.
2. **Load guidelines** — Read project coding guidelines (from `--guidelines`, `CLAUDE.md`, `.cursor/rules/`, or language-specific defaults). Extract the rules to check against.
3. **Categorize changes** — Group changed files by type: logic, tests, config, docs, migrations. Prioritize logic and test files for deep review.
4. **Review each file** — For every changed file, check against guidelines. Look for: correctness, security, performance, maintainability, test coverage, style, naming, error handling.
5. **Score** — Assign a score from 1-10 based on findings. Deductions: critical (-3), major (-1.5), minor (-0.5). Floor at 1. Start at 10 and subtract.
6. **Generate fix prompts** — For each finding, produce a self-contained prompt that an LLM can use to fix the issue. Include file path, line range, what's wrong, and what the fix should look like.
7. **Gate check** — Compare final score against `--gate`. If passing and `--post-if-passing` is set, format and post as PR comment.
8. **Report** — Output the full review with score, findings, fix prompts, and pass/fail status.

## Examples

### Standard branch review
```
/code-review --branch feature/user-auth

## Code Review — feature/user-auth

### Score: 7/10 — BELOW GATE (8)

### Findings
| # | Severity | File | Line | Issue |
|---|----------|------|------|-------|
| 1 | CRITICAL | lib/auth/session.ex | 45 | Token stored in plain text without encryption |
| 2 | MAJOR | lib/auth/login.ex | 23 | Missing rate limiting on login endpoint |
| 3 | MAJOR | test/auth_test.exs | — | No tests for token expiration edge case |
| 4 | MINOR | lib/auth/session.ex | 12 | Variable name `t` should be descriptive |

### Fix Prompts
#### Finding #1 — Token encryption
> In `lib/auth/session.ex` line 45, the session token is stored as plain text.
> Encrypt it using `Plug.Crypto.encrypt/3` before storage and decrypt on read.
> Reference: project guideline §Security — "All tokens at rest must be encrypted."
```

## Output

```markdown
## Code Review — <branch>

### Score: N/10 — PASS | BELOW GATE

### Summary
- Files reviewed: N
- Findings: N critical, N major, N minor
- Guidelines checked: N rules

### Findings
| # | Severity | File | Line | Issue |
|---|----------|------|------|-------|
| 1 | ... | ... | ... | ... |

### Fix Prompts
#### Finding #N — Title
> Actionable LLM prompt to fix the issue...

### Verdict
PASS — Ready to merge | FAIL — Address N findings before merge
```

## Dependencies

- Git (diff between refs)
- Project guidelines file (auto-detected or specified)
- `/create-pr` — Optional integration for posting reviews
- GitHub CLI (`gh`) — For PR comment posting
