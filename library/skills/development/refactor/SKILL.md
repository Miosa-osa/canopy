# /refactor

> Restructure code for clarity and maintainability without changing behavior.

## Usage
```
/refactor <target> [--strategy <strategy>] [--safe]
```

## What It Does
Analyzes the target code, identifies improvement opportunities, plans a safe refactoring sequence, executes it, and verifies no behavior changes. Runs tests before and after every transformation.

## Implementation
1. **Analyze** -- read the target code, identify code smells (long functions, deep nesting, duplication, poor naming, high coupling).
2. **Plan** -- propose refactoring strategy: extract function, rename, decompose, inline, introduce pattern.
3. **Baseline** -- run tests to establish green state. If tests fail, stop.
4. **Execute** -- apply refactorings one at a time. Run tests after each.
5. **Verify** -- confirm all tests still pass, behavior unchanged.
6. **Report** -- diff summary, complexity reduction metrics, before/after.

Strategies: `extract`, `rename`, `decompose`, `simplify`, `decouple`, `auto` (detect best).

## Examples
```bash
# Auto-detect and refactor
/refactor lib/optimal_engine/intake.ex

# Extract functions from a long module
/refactor lib/app.ex --strategy extract

# Safe mode: smaller steps, test after every change
/refactor lib/complex_module.ex --safe
```
