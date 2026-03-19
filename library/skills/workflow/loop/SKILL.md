# /loop

> Run an iterative refinement loop until a quality threshold is met.

## Usage
```
/loop "<task>" --until "<condition>" [--max-iterations <n>]
```

## What It Does
Executes a task repeatedly, evaluating the output against a quality condition after each iteration. Continues refining until the condition is met or max iterations reached. Each iteration builds on the previous output. Useful for progressive improvement of content, code, or designs.

## Implementation
1. **Initial execution** -- run the task, produce first output.
2. **Evaluate** -- check output against the condition (quality score, test pass, criteria met).
3. **Refine** -- if condition not met, identify gaps and re-execute with improvements.
4. **Repeat** -- continue until condition met or max iterations (default: 5).
5. **Report** -- iteration log showing progression and final output.

## Examples
```bash
# Refine until tests pass
/loop "fix failing tests in auth module" --until "all tests pass" --max-iterations 3

# Refine content quality
/loop "write pitch for AI Masters" --until "S/N score > 0.8"

# Iterative optimization
/loop "optimize query performance" --until "p99 < 200ms" --max-iterations 5
```
