---
name: judge-prompt
description: >
  Design binary pass/fail LLM-as-Judge evaluators. Structured prompt
  engineering for evaluation: criteria definition, rubric construction,
  few-shot calibration, and bias mitigation. Produces a ready-to-deploy
  judge prompt with scoring instructions.
  Triggers on: "judge prompt", "llm judge", "evaluator prompt", "scoring prompt", "grading rubric"
---

# /judge-prompt

> Design binary pass/fail LLM-as-Judge evaluation prompts.

## Purpose

Create a rigorous LLM-as-Judge prompt that evaluates model outputs with binary pass/fail decisions. Walks through criteria definition, rubric construction, few-shot example selection, bias mitigation, and prompt assembly. The output is a self-contained judge prompt ready for deployment in an eval pipeline, with built-in guardrails against common judge biases (position, verbosity, self-preference).

## Usage

```bash
# Interactive judge design
/judge-prompt --task "summarization quality"

# From criteria spec
/judge-prompt --criteria criteria.yaml --examples examples.jsonl

# Design judge for specific eval
/judge-prompt --eval evals/code-review/ --task "code correctness"

# Add bias mitigation
/judge-prompt --task "helpfulness" --mitigate position,verbosity

# Generate judge with calibration examples
/judge-prompt --task "factual accuracy" --calibrate labels/human-ratings.jsonl
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--task` | string | required | What the judge evaluates (e.g., "summarization quality") |
| `--criteria` | string | — | Path to YAML criteria specification |
| `--examples` | string | — | Path to JSONL file with labeled examples for few-shot |
| `--eval` | string | — | Path to eval directory for context |
| `--mitigate` | string | `all` | Biases to mitigate: `position`, `verbosity`, `self-preference`, `all`, `none` |
| `--calibrate` | string | — | Human labels file for calibration examples |
| `--output` | string | `judge-prompt.md` | Output path for the judge prompt |
| `--format` | enum | `markdown` | Output format: `markdown`, `yaml`, `json` |
| `--style` | enum | `binary` | Judgment style: `binary` (pass/fail), `likert` (1-5), `comparative` (A vs B) |

## Workflow

1. **Define task** — Clarify what the judge evaluates. What does "good" look like? What are the failure modes? What is the minimum quality bar for a pass?
2. **Criteria specification** — Break the task into 2-5 concrete, observable criteria. Each criterion must be: specific (not vague), binary-testable (can answer yes/no), independent (not redundant with others). Example: for summarization — completeness, accuracy, conciseness, coherence.
3. **Rubric construction** — For each criterion, write explicit pass and fail descriptions with boundary examples. Define what a borderline case looks like and which side it falls on. Eliminate ambiguity.
4. **Few-shot examples** — Select 3-5 calibration examples: 1-2 clear passes, 1-2 clear fails, and 1 borderline case with explanation. If `--calibrate` is provided, select examples aligned with human labels.
5. **Bias mitigation** — Add structural safeguards. Position bias: randomize presentation order or require evaluation before seeing alternatives. Verbosity bias: instruct to judge content not length. Self-preference: use a different model family for judging.
6. **Prompt assembly** — Compile the judge prompt with: role definition, task description, criteria with rubric, few-shot examples, output format specification (structured JSON with verdict + reasoning), and bias mitigation instructions.
7. **Validation check** — Self-test the prompt against the few-shot examples. Verify it produces correct verdicts. Flag any inconsistencies.

## Examples

### Designing a summarization judge
```
/judge-prompt --task "summarization quality" --mitigate all

## Judge Prompt — Summarization Quality

### Criteria
1. **Completeness**: Summary captures all key points from the source
2. **Accuracy**: No facts are distorted, added, or misrepresented
3. **Conciseness**: No unnecessary repetition or filler
4. **Coherence**: Summary reads naturally as standalone text

### Rubric
| Criterion | PASS | FAIL | Borderline |
|-----------|------|------|------------|
| Completeness | All main points present | Missing ≥1 key point | Minor supporting detail missing → PASS |
| Accuracy | All facts match source | Any factual error | Imprecise wording without meaning change → PASS |
| Conciseness | No redundancy | Repeats same point 2+ times | Slightly verbose but no repetition → PASS |
| Coherence | Flows naturally | Disjointed or contradictory | Awkward transition → PASS if meaning clear |

### Verdict Rule
- PASS: All 4 criteria pass
- FAIL: Any criterion fails

### Generated Prompt
```
You are an evaluation judge. Assess the following summary against its source document.

[Criteria and rubric inserted here...]

Evaluate each criterion independently. Output your judgment as:
{"verdict": "pass" | "fail", "criteria": {"completeness": bool, "accuracy": bool, "conciseness": bool, "coherence": bool}, "reasoning": "one sentence explanation"}

IMPORTANT: Judge the content, not the style. A shorter summary that captures all key points is equally valid as a longer one. Do not penalize conciseness. Do not reward verbosity.
```

## Output

```markdown
## Judge Prompt — <task>

### Criteria
1. <criterion>: <description>
...

### Rubric
| Criterion | PASS | FAIL | Borderline → |
|-----------|------|------|--------------|
| ... | ... | ... | ... |

### Few-Shot Examples
#### Example 1 (PASS): ...
#### Example 2 (FAIL): ...
#### Example 3 (BORDERLINE → PASS): ...

### Bias Mitigations
- <mitigation strategy>

### Prompt (ready to deploy)
```text
[Complete prompt text]
```

### Validation
- Few-shot self-test: N/N correct
```

## Dependencies

- Task definition (provided via `--task` or `--criteria`)
- `/validate-evaluator` — Downstream calibration against human labels
- `/synthetic-data` — Upstream if test cases are needed for calibration
- `/error-analysis` — Downstream if judge performance needs debugging
