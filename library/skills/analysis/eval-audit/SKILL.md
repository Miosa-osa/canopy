---
name: eval-audit
description: >
  Audit an LLM evaluation pipeline for correctness, coverage, and reliability.
  6 diagnostic areas with structured Check/Finding output. Produces prioritized
  findings by severity and recommends next skills to run. Catches common eval
  pitfalls before they corrupt your metrics.
  Triggers on: "eval audit", "audit evals", "evaluation audit", "check eval pipeline", "eval health"
---

# /eval-audit

> Audit an LLM evaluation pipeline for correctness and reliability.

## Purpose

Systematically audit an LLM evaluation pipeline across 6 diagnostic areas: data quality, metric validity, judge reliability, coverage gaps, statistical rigor, and pipeline integrity. Each area produces structured Check/Finding pairs with severity ratings. The audit catches common eval pitfalls — label leakage, metric gaming, distribution mismatch, underpowered samples, and judge bias — before they corrupt decision-making. Outputs prioritized recommendations and suggests follow-up skills.

## Usage

```bash
# Full audit of an eval pipeline
/eval-audit --pipeline evals/

# Audit specific diagnostic area
/eval-audit --pipeline evals/ --area judge-reliability

# Audit with custom severity threshold
/eval-audit --pipeline evals/ --min-severity major

# Audit from eval config file
/eval-audit --config evals/config.yaml

# Quick scan (skip deep statistical checks)
/eval-audit --pipeline evals/ --quick
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--pipeline` | string | required | Path to evaluation pipeline directory |
| `--config` | string | — | Path to eval config file (alternative to `--pipeline`) |
| `--area` | enum | `all` | Diagnostic area: `data`, `metrics`, `judges`, `coverage`, `statistics`, `integrity`, `all` |
| `--min-severity` | enum | `minor` | Minimum severity to report: `critical`, `major`, `minor` |
| `--quick` | flag | false | Quick scan (skip computationally expensive checks) |
| `--output` | string | stdout | Write report to file |
| `--format` | enum | `markdown` | Output format: `markdown`, `json` |

## Workflow

1. **Inventory** — Scan the pipeline directory. Identify eval datasets, metric definitions, judge prompts, scoring scripts, and result files. Build a pipeline map.
2. **Data Quality** — Check eval datasets for: label balance, duplicate entries, data leakage from training, stale or outdated examples, ambiguous ground truth, insufficient diversity.
3. **Metric Validity** — Check metrics for: alignment with actual goals (Goodhart's Law), gaming susceptibility, sensitivity to edge cases, proper aggregation (micro vs macro), confidence intervals.
4. **Judge Reliability** — Check LLM judges for: position bias, verbosity bias, self-preference, prompt sensitivity, inter-rater agreement, calibration against human labels.
5. **Coverage Gaps** — Check for: untested capabilities, missing edge cases, distribution mismatch between eval and production, capability dimensions not represented.
6. **Statistical Rigor** — Check for: sufficient sample sizes, proper significance testing, multiple comparison correction, effect size reporting, reproducibility.
7. **Pipeline Integrity** — Check for: deterministic execution, version pinning, result caching correctness, data pipeline bugs, reporting accuracy.
8. **Prioritize** — Rank all findings by severity and impact. Group related findings. Recommend next skills to address issues.

## Examples

### Full pipeline audit
```
/eval-audit --pipeline evals/summarization/

## Eval Audit — evals/summarization/

### Area 1: Data Quality
| Check | Finding | Severity |
|-------|---------|----------|
| Label balance | 73% positive, 27% negative — skewed | MAJOR |
| Duplicates | 12 duplicate entries found (4.8%) | MINOR |
| Staleness | 40% of examples from pre-2024 data | MAJOR |
| Leakage | No leakage detected | PASS |

### Area 3: Judge Reliability
| Check | Finding | Severity |
|-------|---------|----------|
| Position bias | Judge prefers response A 61% of the time | CRITICAL |
| Verbosity bias | Longer responses scored 0.8 points higher on average | MAJOR |
| Human agreement | Cohen's kappa = 0.42 (moderate) — below 0.6 threshold | MAJOR |

### Recommendations
1. [CRITICAL] Fix position bias — use `/validate-evaluator` to calibrate
2. [MAJOR] Rebalance dataset — use `/synthetic-data` to generate minority class
3. [MAJOR] Update stale examples — 40% of eval data predates current model behavior
```

## Output

```markdown
## Eval Audit Report

### Pipeline: <path>
### Date: <date>
### Overall Health: RED | YELLOW | GREEN

### Findings Summary
- Critical: N
- Major: N
- Minor: N
- Passing checks: N

### [Diagnostic Area Sections with Check/Finding tables...]

### Recommended Next Skills
1. `/validate-evaluator` — Calibrate judge against human labels
2. `/synthetic-data` — Generate balanced eval data
3. `/error-analysis` — Deep-dive on failure patterns

### Priority Actions
1. [Action + owner + deadline suggestion]
2. ...
```

## Dependencies

- Eval pipeline files (datasets, prompts, scripts, results)
- `/validate-evaluator` — Recommended follow-up for judge issues
- `/synthetic-data` — Recommended follow-up for data gaps
- `/error-analysis` — Recommended follow-up for failure patterns
- Statistical libraries for significance testing (when not in `--quick` mode)
