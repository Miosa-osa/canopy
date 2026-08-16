---
name: synthetic-data
description: >
  Generate diverse synthetic test inputs via dimension-based tuple generation.
  Defines variation dimensions, enumerates combinations, filters for relevance,
  and produces labeled test cases. For LLM eval pipelines, training data
  augmentation, and stress testing.
  Triggers on: "synthetic data", "generate test data", "test inputs", "data generation", "augment data"
---

# /synthetic-data

> Generate diverse synthetic test inputs through dimension-based combinatorics.

## Purpose

Generate synthetic test inputs by defining variation dimensions (topic, difficulty, format, length, persona, edge case type, etc.), computing the combinatorial product, filtering for meaningful combinations, and producing labeled test cases. Ensures eval datasets cover the full capability surface rather than clustering around easy cases. Supports seeded generation for reproducibility.

## Usage

```bash
# Generate from dimension spec
/synthetic-data --dimensions dimensions.yaml --count 200

# Quick generation with inline dimensions
/synthetic-data --dim "topic:math,science,history" --dim "difficulty:easy,medium,hard" --count 50

# Generate to fill gaps identified by eval-audit
/synthetic-data --gaps eval-audit-report.md --count 100

# Generate with constraints
/synthetic-data --dimensions dims.yaml --count 200 --constraint "not (topic=math and difficulty=easy)"

# Append to existing dataset
/synthetic-data --dimensions dims.yaml --count 50 --append evals/dataset.jsonl

# Reproducible generation
/synthetic-data --dimensions dims.yaml --count 200 --seed 42
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--dimensions` | string | — | Path to YAML dimension specification file |
| `--dim` | string[] | — | Inline dimension definition (repeatable): `"name:val1,val2,val3"` |
| `--count` | int | `100` | Number of test cases to generate |
| `--gaps` | string | — | Path to eval-audit report to fill identified gaps |
| `--constraint` | string | — | Boolean expression to exclude combinations |
| `--append` | string | — | Append to existing dataset file |
| `--seed` | int | random | Random seed for reproducible generation |
| `--output` | string | `synthetic-data.jsonl` | Output file path |
| `--format` | enum | `jsonl` | Output format: `jsonl`, `yaml`, `csv`, `json` |
| `--with-labels` | flag | false | Generate expected output labels alongside inputs |
| `--validate` | flag | false | Run deduplication and quality checks on output |

## Workflow

1. **Define dimensions** — Load or parse dimension definitions. Each dimension has a name and a set of possible values. Examples: `topic: [math, science, coding]`, `difficulty: [easy, medium, hard]`, `style: [formal, casual, terse]`.
2. **Enumerate space** — Compute the full combinatorial product of all dimensions. For 4 dimensions with 3 values each: 81 possible tuples.
3. **Filter** — Apply constraints to remove invalid or uninteresting combinations. Remove duplicates against existing datasets if `--append` is set.
4. **Sample** — If the enumerated space exceeds `--count`, sample uniformly across dimensions to maintain diversity. Use stratified sampling to avoid dimension collapse.
5. **Generate** — For each selected tuple, generate a concrete test input. The tuple defines the parameters; the LLM produces a natural input matching those parameters.
6. **Label** — If `--with-labels` is set, generate expected outputs for each input. Mark confidence level on each label.
7. **Validate** — If `--validate` is set, check for: near-duplicate inputs, dimension coverage uniformity, label consistency, and format correctness.
8. **Output** — Write the synthetic dataset in the specified format. Include metadata: dimensions used, coverage statistics, generation seed.

## Examples

### Dimension specification file
```yaml
# dimensions.yaml
dimensions:
  topic:
    values: [math, science, history, coding, creative-writing]
    weight: 1.0
  difficulty:
    values: [easy, medium, hard, adversarial]
    weight: 1.2  # slightly oversample harder cases
  format:
    values: [question, instruction, conversation, document]
  length:
    values: [short, medium, long]
  edge_case:
    values: [none, ambiguous-input, multilingual, typos, contradictory]
    weight: 0.8
```

### Generation run
```
/synthetic-data --dimensions dimensions.yaml --count 50 --seed 42 --with-labels

## Synthetic Data Generation

- Dimension space: 5 x 4 x 4 x 3 x 5 = 1,200 possible tuples
- Requested: 50 samples
- Sampling: stratified across all dimensions
- Seed: 42

### Coverage Report
| Dimension | Values | Min samples | Max samples | Uniformity |
|-----------|--------|-------------|-------------|------------|
| topic | 5 | 9 | 11 | 0.96 |
| difficulty | 4 | 11 | 14 | 0.94 |
| format | 4 | 11 | 14 | 0.95 |
| length | 3 | 15 | 18 | 0.97 |
| edge_case | 5 | 8 | 12 | 0.91 |

### Sample outputs
{"id": "syn-001", "dims": {"topic": "math", "difficulty": "hard", "format": "question", "length": "short", "edge_case": "ambiguous-input"}, "input": "What's the value of x if x^2 = -1?", "expected": "No real solution; x = ±i in complex numbers"}
```

## Output

```jsonl
{"id": "syn-001", "dims": {...}, "input": "...", "expected": "...", "confidence": 0.95}
{"id": "syn-002", "dims": {...}, "input": "...", "expected": "...", "confidence": 0.90}
```

## Dependencies

- Dimension specification (YAML file or inline `--dim` flags)
- `/eval-audit` — Upstream skill that identifies coverage gaps
- `/judge-prompt` — Downstream if labels need validation
- LLM access for generating natural test inputs from dimension tuples
