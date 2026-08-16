---
name: autoresearch
description: >
  Autonomous iterative improvement loop. Agent modifies code, verifies against
  metrics, keeps improvements or reverts failures, and repeats. Uses git as
  memory — each change is committed, measured, and kept or discarded. Runs
  until a target metric is hit or max iterations reached.
  Triggers on: "autoresearch", "auto improve", "iterative improvement", "autonomous loop", "hill climb"
---

# /autoresearch

> Autonomous code improvement through iterative experiment-and-measure cycles.

## Purpose

Run an autonomous loop that improves code against a measurable metric. Each iteration: the agent analyzes current performance, hypothesizes an improvement, implements it, commits it, runs the metric, and decides keep-or-revert. Git history becomes the experiment log. The loop continues until the target is met, max iterations are exhausted, or no progress is made for N consecutive rounds.

## Usage

```bash
# Basic — improve test pass rate
/autoresearch --metric "mix test --cover" --target 95

# Improve benchmark performance
/autoresearch --metric "cargo bench --output json" --target "p99 < 10ms" --max-iter 20

# Improve code quality score
/autoresearch --metric "npx eslint . --format json | jq '.errorCount'" --target 0

# Dry run — show plan without executing
/autoresearch --metric "pytest" --target "all pass" --dry-run

# Resume a previous session
/autoresearch --resume

# Limit scope to specific files
/autoresearch --metric "mix test test/parser_test.exs" --target "0 failures" --scope "lib/parser.ex"
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--metric` | string | required | Command that produces a measurable result |
| `--target` | string | required | Success condition (number, comparison, or keyword) |
| `--max-iter` | int | `10` | Maximum improvement iterations |
| `--stall-limit` | int | `3` | Stop after N consecutive iterations with no improvement |
| `--scope` | string | `.` | Files or directories the agent may modify |
| `--dry-run` | flag | false | Show the improvement plan without executing |
| `--resume` | flag | false | Resume from last autoresearch session |
| `--branch` | string | `autoresearch/<timestamp>` | Git branch name for the experiment |
| `--commit-each` | flag | true | Commit each successful iteration |
| `--verbose` | flag | false | Show full metric output each iteration |

## Workflow

1. **Baseline** — Run the metric command on current code. Record the baseline score. Create a new git branch.
2. **Analyze** — Read the metric output and the scoped source files. Identify the highest-impact area for improvement.
3. **Hypothesize** — Form a single, testable change hypothesis. Write it to the commit message.
4. **Implement** — Make the code change. Keep changes small and focused (one logical modification per iteration).
5. **Measure** — Run the metric command again. Parse the result.
6. **Decide** — Compare to previous best score. If improved or equal: `git commit` with hypothesis + result. If worse: `git checkout -- .` to revert.
7. **Log** — Record iteration number, hypothesis, before/after scores, and keep/revert decision.
8. **Repeat** — Return to step 2 unless: target met, max iterations reached, or stall limit hit.
9. **Report** — Summarize all iterations, net improvement, and final state. Optionally squash commits.

## Examples

### Improving test coverage
```
/autoresearch --metric "mix test --cover | grep 'Total:'" --target 90 --scope "lib/"

## Autoresearch — Session ar-20260320-1
| Iter | Hypothesis | Before | After | Decision |
|------|-----------|--------|-------|----------|
| 1 | Add missing tests for Parser.parse_header/1 edge cases | 72.3% | 78.1% | KEEP |
| 2 | Cover error branches in Validator.check/2 | 78.1% | 83.4% | KEEP |
| 3 | Add property tests for Encoder module | 83.4% | 82.9% | REVERT |
| 4 | Test Encoder.encode/1 boundary inputs directly | 83.4% | 88.7% | KEEP |
| 5 | Cover remaining uncovered functions in Formatter | 88.7% | 91.2% | KEEP |

Result: TARGET MET (91.2% >= 90%)
Branch: autoresearch/20260320-143022 (5 commits, 2 reverted)
```

## Output

```markdown
## Autoresearch Complete

- **Branch**: autoresearch/20260320-143022
- **Iterations**: 7 (5 kept, 2 reverted)
- **Baseline**: 72.3%
- **Final**: 91.2%
- **Target**: 90% — MET
- **Net improvement**: +18.9%

### Iteration Log
| # | Hypothesis | Score | Delta | Decision |
|---|-----------|-------|-------|----------|
| 1 | ... | 78.1% | +5.8 | KEEP |
| ... | ... | ... | ... | ... |

### Recommended Next Steps
- Merge branch or cherry-pick successful commits
- Run full test suite to confirm no regressions
```

## Dependencies

- Git (branching, committing, reverting)
- A runnable metric command that produces parseable output
- `/commit` — Used for each successful iteration
- File system access to scoped source files
