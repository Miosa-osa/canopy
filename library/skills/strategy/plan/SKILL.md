# /plan

> Create a structured execution plan with objectives, non-negotiables, and time blocks.

## Usage
```
/plan "<objective>" [--horizon <days|week|month>] [--for <person>]
```

## What It Does
Produces a structured plan using the plan genre skeleton: objective, non-negotiables (top 3), time blocks, dependencies, and success criteria. Assembles relevant context before planning. Outputs to the appropriate file (rhythm/week-plan.md for weekly, custom for project-specific).

## Implementation
1. **Assemble context** -- `/assemble` relevant topic context.
2. **Define objective** -- single clear sentence of what the plan achieves.
3. **Identify non-negotiables** -- top 3 things that must happen, no exceptions.
4. **Allocate time blocks** -- map tasks to available time slots.
5. **Map dependencies** -- who/what we're waiting on.
6. **Set success criteria** -- how we measure completion.
7. **Write plan** -- output in plan genre skeleton format.

## Examples
```bash
# Plan the week
/plan "Ship AI Masters pricing page" --horizon week

# Plan a project sprint
/plan "Platform MVP launch" --horizon month

# Plan for a specific person
/plan "Bennett's content calendar" --for "Bennett" --horizon week
```
