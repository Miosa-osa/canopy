---
name: tree-of-thoughts
description: "Multi-path reasoning with evaluation and backtracking - 74% success on complex tasks"
trigger: "complex reasoning, planning, multi-step problems"
priority: 2
dynamic: false
created: "2026-01-26"
---

# Tree of Thoughts (ToT) Pattern

Multi-path reasoning that explores, evaluates, and backtracks. Achieved **74% success rate** on Game of 24 vs 4% with standard CoT.

## Activation

Triggers on:
- Problems requiring non-trivial planning
- Decision trees with multiple valid paths
- Complex debugging with multiple hypotheses
- Creative tasks with evaluation criteria

## Process

### Phase 1: Decompose
Break problem into intermediate steps that can be evaluated independently.

### Phase 2: Generate (Branch)
At each step, generate 3 candidate "thoughts" (reasoning paths):

```
STEP N:
├─ Thought A: [approach 1]
├─ Thought B: [approach 2]
└─ Thought C: [approach 3]
```

### Phase 3: Evaluate
Score each thought (0-10) on:
- Progress toward goal
- Feasibility
- Reversibility if wrong

### Phase 4: Search Strategy
- **BFS**: Explore all branches at depth N before N+1 (shallow trees)
- **DFS**: Follow promising paths deeper (deep trees)
- **Beam Search**: Keep top-K paths at each level

### Phase 5: Backtrack
If path scores drop below threshold (5/10), backtrack to last good node.

## Zero-Shot ToT Prompt

Use this simple prompt for ToT without explicit tree construction:

```
"Imagine three different experts are answering this question.
All experts will write down 1 step of their thinking, then share it with the group.
Then all experts will go on to the next step.
If any expert realizes they're wrong at any point, they leave.
Continue until consensus."
```

## Integration

- Works with @architect for system design decisions
- Pairs with @debugger for multi-hypothesis testing
- Feed final path to learning engine for pattern storage

---

*Based on Princeton/DeepMind research - arXiv:2305.10601*
