---
name: error-analysis
description: >
  Guided analysis of LLM traces to categorize and pattern-match failures.
  Reads execution traces, classifies failure modes, detects recurring patterns,
  and produces actionable taxonomy of errors. For diagnosing why an LLM system
  fails and where to focus improvement effort.
  Triggers on: "error analysis", "analyze failures", "failure patterns", "trace analysis", "debug eval"
---

# /error-analysis

> Categorize LLM failures by reading traces and detecting patterns.

## Purpose

Guide through systematic analysis of LLM execution traces (eval results, agent logs, or production errors) to categorize failure modes, detect recurring patterns, and quantify their frequency. Produces an error taxonomy with root cause hypotheses and prioritized fix recommendations. Turns a pile of failures into an actionable improvement roadmap.

## Usage

```bash
# Analyze eval results
/error-analysis --traces evals/results/run-42/

# Analyze with existing taxonomy (extend it)
/error-analysis --traces evals/results/ --taxonomy errors/taxonomy.yaml

# Focus on specific failure type
/error-analysis --traces evals/results/ --filter "score < 0.5"

# Analyze agent execution logs
/error-analysis --traces logs/agent-runs/ --format agent-trace

# Compare error patterns between two runs
/error-analysis --traces evals/results/run-42/ --compare evals/results/run-41/

# Sample from large trace sets
/error-analysis --traces evals/results/ --sample 100
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--traces` | string | required | Path to trace files or results directory |
| `--taxonomy` | string | — | Existing error taxonomy to extend |
| `--filter` | string | — | Expression to filter traces (e.g., `"score < 0.5"`) |
| `--format` | enum | `auto` | Trace format: `auto`, `eval-result`, `agent-trace`, `jsonl`, `log` |
| `--compare` | string | — | Second trace set for differential analysis |
| `--sample` | int | all | Random sample size for large trace sets |
| `--min-pattern` | int | `3` | Minimum occurrences to qualify as a pattern |
| `--output` | string | stdout | Write analysis to file |
| `--depth` | enum | `standard` | Analysis depth: `quick`, `standard`, `deep` |

## Workflow

1. **Ingest** — Load trace files. Parse format (eval JSON, agent logs, JSONL). Extract: input, output, expected output, score, metadata, and intermediate steps if available.
2. **Filter** — Apply `--filter` to select the failure subset. Separate clean passes from failures. Report failure rate.
3. **Read traces** — For each failure, read the full trace. Identify the point of divergence: where did the output deviate from expected? What was the last correct step?
4. **Classify** — Assign each failure to a category. Start with common LLM failure modes: instruction following, factual error, reasoning error, format violation, refusal, hallucination, context loss, tool misuse. Create new categories as needed.
5. **Pattern detection** — Across classified failures, detect recurring patterns: common input characteristics that trigger failures, specific prompt sections that confuse the model, systematic biases, capability gaps.
6. **Quantify** — Count occurrences per category and pattern. Calculate failure rates, conditional probabilities (P(failure | pattern)), and trend direction if comparing runs.
7. **Root cause** — For each pattern, hypothesize root causes: prompt ambiguity, missing examples, capability limitation, data distribution gap, context window overflow, tool schema issue.
8. **Recommend** — Prioritize fixes by impact (frequency x severity). Map each recommendation to a specific action: prompt edit, example addition, guardrail, fine-tuning signal, or architecture change.

## Examples

### Eval failure analysis
```
/error-analysis --traces evals/results/run-42/ --filter "score < 0.5"

## Error Analysis — run-42

### Overview
- Total traces: 500
- Failures (score < 0.5): 73 (14.6%)
- Categories identified: 5
- Patterns detected: 3

### Error Taxonomy
| Category | Count | % of Failures | Example |
|----------|-------|--------------|---------|
| Reasoning error | 28 | 38.4% | Multi-step math with carrying |
| Format violation | 19 | 26.0% | JSON output missing required field |
| Instruction ignored | 14 | 19.2% | "Do not explain" instruction skipped |
| Hallucination | 8 | 11.0% | Cited nonexistent API endpoint |
| Context loss | 4 | 5.5% | Forgot constraint from early in prompt |

### Pattern: Multi-step reasoning with >3 dependencies
- Frequency: 22/28 reasoning errors (78.6%)
- Trigger: Input requires chaining 4+ intermediate results
- Root cause: Model loses track of intermediate values
- Fix: Add scratchpad instruction or chain-of-thought enforcement

### Recommended Actions
1. [HIGH] Add explicit scratchpad section to prompt — addresses 28 reasoning errors
2. [HIGH] Add JSON schema validation as output guard — catches 19 format violations
3. [MEDIUM] Strengthen "do not explain" instruction with examples — addresses 14 violations
```

## Output

```markdown
## Error Analysis Report

### Summary
- Traces analyzed: N
- Failure rate: N%
- Categories: N
- Patterns: N

### Error Taxonomy
| Category | Count | % | Trend |
|----------|-------|---|-------|
| ... | ... | ... | ... |

### Detected Patterns
#### Pattern 1: <name>
- Frequency: N (N% of category)
- Trigger: <description>
- Root cause: <hypothesis>
- Confidence: high | medium | low

### Recommended Actions
| Priority | Action | Addresses | Expected Impact |
|----------|--------|-----------|-----------------|
| 1 | ... | N failures | ... |

### Differential (if --compare used)
| Category | Run A | Run B | Delta |
|----------|-------|-------|-------|
| ... | ... | ... | ... |
```

## Dependencies

- Trace files (eval results, agent logs, or JSONL records)
- `/eval-audit` — Upstream audit that may trigger this skill
- `/judge-prompt` — Downstream if failures require judge redesign
- `/synthetic-data` — Downstream if failures reveal data gaps
