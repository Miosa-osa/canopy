# /pipeline

> Define and execute a multi-step pipeline with sequential or parallel stages.

## Usage
```
/pipeline "<name>" --steps "<step1, step2, step3>" [--parallel] [--dry-run]
```

## What It Does
Creates and executes a pipeline of ordered steps where each step's output feeds into the next. Supports sequential execution (default) and parallel execution for independent steps. Tracks progress, handles failures with retry/skip options, and produces a final report.

## Implementation
1. **Parse steps** -- break the pipeline into ordered stages.
2. **Resolve dependencies** -- determine which steps can run in parallel.
3. **Execute** -- run each step, capture output, pass to next step.
4. **Handle failures** -- retry (1x), skip (if non-critical), or abort (if critical).
5. **Report** -- pipeline summary with per-step status, duration, and artifacts.

With `--dry-run`: show the execution plan without running anything.

## Examples
```bash
# Define a CI/CD pipeline
/pipeline "deploy" --steps "lint, test, build, deploy"

# Run parallel independent steps
/pipeline "audit" --steps "security-scan, lint, test" --parallel

# Dry run to preview
/pipeline "release" --steps "test, build, tag, push, deploy" --dry-run
```
