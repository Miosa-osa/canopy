# /brainstorm

> Generate 3-5 approaches with pros, cons, and a reasoned recommendation.

## Usage
```
/brainstorm "<problem>" [--options <n>] [--constraint "<constraint>"]
```

## What It Does
Takes a problem or decision, generates multiple distinct approaches, evaluates each on pros/cons/effort, and provides a reasoned recommendation. Forces structured thinking before jumping to implementation.

## Implementation
1. **Clarify** -- restate the problem as a clear question.
2. **Explore** -- generate N approaches (default: 3, max: 5). Each must be genuinely different, not variations of the same idea.
3. **Evaluate** -- for each approach, list pros, cons, effort estimate, risk level.
4. **Decide** -- recommend the best approach with clear reasoning.
5. **Plan** -- break the recommended approach into concrete next steps.

## Examples
```bash
# Brainstorm a technical decision
/brainstorm "How should we handle auth in the platform?"

# Brainstorm with more options
/brainstorm "Revenue model for OS Accelerator" --options 5

# Brainstorm with constraints
/brainstorm "Hiring a frontend dev" --constraint "budget under $8K/mo"
```
