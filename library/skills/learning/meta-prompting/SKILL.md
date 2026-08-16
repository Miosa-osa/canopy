# /meta-prompting

> Optimize prompts through iterative self-improvement.

## Usage
```
/meta-prompting "<prompt>" [--iterations <n>] [--target <score>]
```

## What It Does
Takes a prompt, executes it, scores the result, then uses the LLM to optimize the prompt for better results. Iterates until the quality target is met or max iterations reached. Stores optimized prompts in the skill library for reuse.

## Implementation
1. **Execute** -- run the original prompt, capture output.
2. **Score** -- evaluate result on correctness (40%), completeness (25%), clarity (20%), efficiency (15%).
3. **Optimize** -- generate an improved prompt addressing identified issues.
4. **Re-execute** -- run the improved prompt.
5. **Compare** -- if improved, save as new baseline. If not, revert or try different optimization.
6. **Repeat** -- until target score or max iterations (default: 3).
7. **Store** -- save the best prompt as a reusable template.

Optimization dimensions: clarity enhancement, example addition, instruction refinement, context optimization.

## Examples
```bash
# Optimize a code generation prompt
/meta-prompting "Generate a rate limiter in Go" --target 8

# Optimize a content prompt with more iterations
/meta-prompting "Write a pitch for enterprise clients" --iterations 5

# Optimize a system prompt
/meta-prompting "You are a security auditor..." --target 9
```
