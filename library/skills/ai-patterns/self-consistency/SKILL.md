---
name: self-consistency
description: "Sample multiple paths, select most consistent - +17.9% on GSM8K"
trigger: "math, logic puzzles, fact-based reasoning, high-stakes decisions"
priority: 3
dynamic: false
created: "2026-01-26"
---

# Self-Consistency (CoT-SC) Pattern

Sample multiple reasoning paths and select the most consistent answer. Achieved **+17.9% on GSM8K**, **+12.2% on AQuA**.

## Activation

Use for:
- Problems with fixed answer sets (math, multiple choice)
- When single-path reasoning is unreliable
- High-stakes decisions requiring confidence
- Factual queries where accuracy is critical

## Process

### 1. Sample Diverse Paths
Generate N (typically 5-10) reasoning paths with higher temperature.

### 2. Extract Final Answers
Parse the conclusive answer from each path.

### 3. Majority Vote
Select the most frequent answer across all paths.

## Implementation

```python
def self_consistency(prompt, question, num_samples=5):
    answers = []
    for _ in range(num_samples):
        response = reason_with_cot(prompt, question)
        answer = extract_final_answer(response)
        answers.append(answer)
    
    # Majority vote
    from collections import Counter
    return Counter(answers).most_common(1)[0][0]
```

## When NOT to Use

- Free-form generation (no fixed answers)
- Time-critical tasks (adds latency from multiple samples)
- Simple queries (overkill)
- Creative tasks (want diversity, not consensus)

## Universal Self-Consistency

For open-ended tasks without fixed answers:

```
"Here are several responses to the same question:
[Response 1]
[Response 2]
[Response 3]

Determine which elements are most consistent across these responses
and synthesize the most reliable answer."
```

## Integration

- Use with @test-automator for test case generation
- Combine with reflection for verified answers
- Log consistency scores to learning engine

---

*Based on Google Research - arXiv:2203.11171*
