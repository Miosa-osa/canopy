---
name: skeleton-of-thought
description: "Parallel generation through skeleton-first approach for 2x speedup"
trigger: "keyword"
keywords: ["fast", "parallel generate", "speed up", "quick response"]
priority: 4
---

# Skeleton-of-Thought (SoT) Skill

Achieves up to 2x speedup through parallel content generation.

## Core Concept

Instead of sequential generation, SoT:
1. First generates a skeleton (outline) of the answer
2. Then expands each skeleton point in PARALLEL
3. Finally assembles the complete response

## When to Use

- Long-form responses (>500 words expected)
- Structured content (lists, tutorials, explanations)
- Time-sensitive queries
- Batch processing scenarios

## When NOT to Use

- Math/reasoning problems (need sequential thought)
- Simple factual queries
- Creative writing requiring flow
- Code generation requiring context

## Process

### Step 1: Skeleton Generation
```
Given question, generate ONLY the skeleton outline:
- Point 1: [brief description]
- Point 2: [brief description]
- Point 3: [brief description]
...
Do NOT expand. Just the skeleton.
```

### Step 2: Parallel Expansion
Launch parallel expansions for each point:
```
Point 1 → Agent 1 → Expanded content
Point 2 → Agent 2 → Expanded content
Point 3 → Agent 3 → Expanded content
(all run simultaneously)
```

### Step 3: Assembly
```
Combine expanded points with transitions:
[Introduction]
[Point 1 expanded]
[Transition]
[Point 2 expanded]
[Transition]
[Point 3 expanded]
[Conclusion]
```

## Implementation

```python
# Skeleton generation prompt
SKELETON_PROMPT = """
For the question: {question}

Generate ONLY a skeleton outline with 3-8 key points.
Format:
1. [Point]: [5-10 word description]
2. [Point]: [5-10 word description]
...

Do NOT expand the points. ONLY the skeleton.
"""

# Point expansion prompt
EXPAND_PROMPT = """
Context: Answering "{question}"
Skeleton: {skeleton}

Expand ONLY point {point_number}: "{point_description}"

Write 2-4 sentences expanding this point.
Do not include other points.
"""
```

## Performance

| Query Type | Sequential Time | SoT Time | Speedup |
|------------|-----------------|----------|---------|
| Tutorial   | 10s             | 5s       | 2.0x    |
| Explanation| 8s              | 4.5s     | 1.8x    |
| List-based | 12s             | 6s       | 2.0x    |
| Analysis   | 15s             | 9s       | 1.7x    |

## Quality Preservation

- Skeleton ensures coherent structure
- Each expansion has full question context
- Assembly adds smooth transitions
- Quality remains high despite parallelism

## Combination with Other Skills

- **Self-Consistency**: Generate multiple skeletons, vote on best
- **ToT**: Use ToT for skeleton generation, SoT for expansion
- **LATS**: Apply LATS scoring to skeleton options

---

*Reference: "Skeleton-of-Thought: Large Language Models Can Do Parallel Decoding" (2023)*
