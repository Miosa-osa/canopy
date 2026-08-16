---
name: validate-evaluator
description: >
  Calibrate LLM-as-Judge evaluators against human labels. Computes TPR, TNR,
  precision, recall, F1, and Cohen's kappa. Detects systematic biases and
  recommends prompt corrections. Produces a calibration report with confidence
  intervals.
  Triggers on: "validate evaluator", "calibrate judge", "judge accuracy", "evaluator validation", "judge metrics"
---

# /validate-evaluator

> Calibrate LLM judges against human labels with statistical rigor.

## Purpose

Validate that an LLM-as-Judge evaluator agrees with human judgments. Run the judge against a human-labeled dataset, compute classification metrics (TPR, TNR, precision, recall, F1, Cohen's kappa), detect systematic biases, and produce actionable correction recommendations. The calibration report tells you whether to trust the judge, where it disagrees with humans, and how to fix it.

## Usage

```bash
# Validate judge against human labels
/validate-evaluator --judge judge-prompt.md --labels human-labels.jsonl

# Validate with confidence intervals
/validate-evaluator --judge judge-prompt.md --labels human-labels.jsonl --bootstrap 1000

# Compare two judges
/validate-evaluator --judge judge-v1.md --judge-b judge-v2.md --labels human-labels.jsonl

# Validate specific bias type
/validate-evaluator --judge judge-prompt.md --labels human-labels.jsonl --check-bias position

# Quick validation (skip bootstrap)
/validate-evaluator --judge judge-prompt.md --labels human-labels.jsonl --quick
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--judge` | string | required | Path to judge prompt file |
| `--judge-b` | string | — | Second judge prompt for comparison |
| `--labels` | string | required | Path to human-labeled dataset (JSONL) |
| `--bootstrap` | int | `0` | Bootstrap iterations for confidence intervals |
| `--check-bias` | string | `all` | Bias checks: `position`, `verbosity`, `length`, `all`, `none` |
| `--quick` | flag | false | Skip bootstrap and deep bias analysis |
| `--threshold` | float | `0.7` | Minimum acceptable Cohen's kappa |
| `--output` | string | stdout | Write report to file |
| `--format` | enum | `markdown` | Output format: `markdown`, `json` |
| `--sample` | int | all | Sample size from labels (for large datasets) |

## Workflow

1. **Load** — Parse the judge prompt and human-labeled dataset. Validate format: each label entry must have input, output, and human verdict (pass/fail). Report dataset statistics.
2. **Run judge** — Execute the judge prompt against every item in the labeled dataset. Record the judge's verdict, reasoning, and latency for each item.
3. **Confusion matrix** — Build the 2x2 confusion matrix: true positives, true negatives, false positives, false negatives. Compute: TPR (sensitivity), TNR (specificity), precision, recall, F1, accuracy, and Cohen's kappa.
4. **Confidence intervals** — If `--bootstrap` > 0, resample with replacement and recompute metrics for each sample. Report 95% confidence intervals for all metrics.
5. **Disagreement analysis** — For every item where judge and human disagree: extract the input, both verdicts, and the judge's reasoning. Classify the disagreement type: judge too strict, judge too lenient, ambiguous case, or judge error.
6. **Bias detection** — Test for systematic biases. Position bias: does the judge favor the first/second option? Verbosity bias: does the judge favor longer outputs? Length bias: does accuracy vary with input length?
7. **Correction recommendations** — For each detected bias or disagreement pattern, suggest a specific prompt modification. Include before/after examples.
8. **Verdict** — Is the judge reliable enough to deploy? Compare kappa against `--threshold`. Recommend: deploy, deploy with caveats, or revise.

## Examples

### Standard calibration
```
/validate-evaluator --judge judge-prompt.md --labels human-labels.jsonl --bootstrap 500

## Evaluator Validation Report

### Dataset
- Total items: 200
- Human pass rate: 62.0%
- Judge pass rate: 67.5%

### Classification Metrics
| Metric | Value | 95% CI |
|--------|-------|--------|
| Accuracy | 0.835 | [0.78, 0.88] |
| Precision | 0.867 | [0.81, 0.92] |
| Recall | 0.879 | [0.82, 0.93] |
| F1 | 0.873 | [0.82, 0.92] |
| TPR | 0.879 | [0.82, 0.93] |
| TNR | 0.763 | [0.68, 0.84] |
| Cohen's kappa | 0.648 | [0.56, 0.73] |

### Confusion Matrix
|  | Human: Pass | Human: Fail |
|--|-------------|-------------|
| Judge: Pass | 109 (TP) | 18 (FP) |
| Judge: Fail | 15 (FN) | 58 (TN) |

### Bias Detection
| Bias Type | Test | Result | Severity |
|-----------|------|--------|----------|
| Position | Chi-squared | p=0.03, judge prefers position A | MAJOR |
| Verbosity | Correlation | r=0.31, moderate positive bias | MINOR |
| Length | ANOVA | p=0.42, no significant effect | PASS |

### Verdict: REVISE (kappa 0.648 < threshold 0.70)

### Corrections
1. Position bias: Add "Evaluate the response without regard to presentation order"
2. Verbosity bias: Add "A concise correct answer is better than a verbose correct answer"
```

## Output

```markdown
## Evaluator Validation Report

### Dataset Statistics
### Classification Metrics (with CI if bootstrapped)
### Confusion Matrix
### Disagreement Analysis (top N cases)
### Bias Detection Results
### Verdict: DEPLOY | DEPLOY WITH CAVEATS | REVISE
### Recommended Corrections
```

## Dependencies

- Judge prompt file (from `/judge-prompt`)
- Human-labeled dataset (JSONL with input, output, human verdict)
- LLM access for running the judge
- `/judge-prompt` — Upstream skill for creating/revising the judge
- `/error-analysis` — Upstream if systematic failures triggered this validation
- Statistical libraries for bootstrap and significance testing
