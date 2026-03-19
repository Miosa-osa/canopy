---
name: lats
description: "Language Agent Tree Search - Monte Carlo planning - 92.7% on HumanEval"
trigger: "complex planning, code generation, decision-making under uncertainty"
priority: 1
dynamic: false
created: "2026-01-26"
---

# LATS (Language Agent Tree Search)

Monte Carlo Tree Search combined with LLM reasoning. Achieved **92.7% pass@1** on HumanEval (SOTA).

## Activation

Use for:
- Complex multi-step planning
- Code generation with tests
- Decision-making with feedback loops
- Tasks where environment provides signals (tests, builds, APIs)

## Core Algorithm

```
while not solved and budget > 0:
    1. SELECT:      Pick best node using UCT formula
    2. EXPAND:      Generate N candidate actions
    3. SIMULATE:    Execute actions, get environment feedback
    4. REFLECT:     Self-evaluate trajectory quality
    5. BACKPROPAGATE: Update scores up the tree
```

## Key Components

### Selection (UCT Formula)
```
UCT(node) = exploitation + C * sqrt(ln(N) / n)
          = avg_score    + exploration_bonus

Where:
- C = exploration constant (typically 1.41)
- N = parent visit count
- n = node visit count
```

### Expansion
Generate top-5 candidate actions in parallel using the Task tool.

### Reflection Prompt
```
"Given this trajectory and outcome:
Trajectory: [actions taken]
Result: [success/failure + details]

Rate this approach 1-10 and explain:
1. What worked well?
2. What went wrong?
3. How could it be improved?"
```

### Backpropagation
```python
def backpropagate(node, score):
    while node:
        node.visits += 1
        node.total_score += score
        node = node.parent
```

## Integration with OSA

LATS is activated by @master-orchestrator when:
- Task complexity is "complex" or "critical"
- Multiple valid solution paths exist
- Environment provides feedback (tests, builds)
- High accuracy is more important than speed

## Cost Consideration

LATS is compute-intensive (5-10x more LLM calls). Reserve for:
- High-value tasks
- When accuracy > cost
- As escalation from simpler methods

---

*Based on ICML 2024 research - arXiv:2310.04406*
