---
name: meta-prompting
description: "Self-improving prompts through meta-level optimization"
trigger: "keyword"
keywords: ["optimize prompt", "improve prompt", "better results", "refine"]
priority: 5
---

# Meta-Prompting Skill

Uses the LLM to optimize its own prompts for better results.

## Core Concept

Meta-prompting treats the LLM as both:
1. **Executor**: Runs the actual task
2. **Optimizer**: Improves the prompt for next iteration

## When to Use

- Repeated similar tasks
- Suboptimal initial results
- Learning new task patterns
- Building prompt libraries

## Meta-Prompt Structure

```
You are a prompt optimization expert.

ORIGINAL PROMPT:
{original_prompt}

RESULT QUALITY: {quality_score}/10
ISSUES IDENTIFIED:
{issues}

Generate an improved version of this prompt that:
1. Addresses the identified issues
2. Maintains the core intent
3. Adds clarity where needed
4. Includes examples if helpful

IMPROVED PROMPT:
```

## Optimization Dimensions

### 1. Clarity Enhancement
- Remove ambiguity
- Add specific constraints
- Define expected format

### 2. Example Addition
- Few-shot examples for pattern matching
- Edge case examples
- Format demonstrations

### 3. Instruction Refinement
- Break complex instructions into steps
- Add verification checkpoints
- Include success criteria

### 4. Context Optimization
- Remove irrelevant context
- Highlight critical information
- Structure for attention patterns

## Iterative Improvement Loop

```
Round 1: Execute original prompt
         ↓
         Score result (0-10)
         ↓
Round 2: Meta-optimize prompt
         ↓
         Execute improved prompt
         ↓
         Score result
         ↓
         If improved: Save as new baseline
         If not: Revert or try different optimization
         ↓
Repeat until convergence or max iterations (3-5)
```

## Prompt Scoring Criteria

| Dimension | Weight | Evaluation |
|-----------|--------|------------|
| Correctness | 40% | Does output match expected? |
| Completeness | 25% | All requirements addressed? |
| Clarity | 20% | Output is clear and useful? |
| Efficiency | 15% | Minimal tokens for result? |

## Meta-Prompt Templates

### For Task Prompts
```
Analyze this task prompt and suggest 3 improvements:
{prompt}

Consider:
- Is the goal clear?
- Are constraints explicit?
- Would examples help?
- Is the format specified?
```

### For System Prompts
```
Review this system prompt for an AI assistant:
{prompt}

Optimize for:
- Role clarity
- Behavioral consistency
- Edge case handling
- Output quality
```

### For Chain-of-Thought
```
This CoT prompt produces inconsistent reasoning:
{prompt}

Restructure to:
- Guide step-by-step thinking
- Include verification steps
- Handle common errors
```

## Storing Optimized Prompts

Save successful prompts to the skill library:
```json
{
  "task_type": "code_review",
  "original_prompt": "...",
  "optimized_prompt": "...",
  "improvement": "+2.3 quality score",
  "iterations": 3,
  "date": "2026-01-26"
}
```

## Integration

- **Learning Engine**: Store optimized prompts as patterns
- **Memory System**: Recall best prompts for task types
- **Skill Library**: Versioned prompt templates

---

*Reference: "Large Language Models as Optimizers" (OPRO, 2023)*
