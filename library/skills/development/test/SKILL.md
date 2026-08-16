# /test

> Run test suite, report coverage, flag failures with diagnostics.

## Usage
```
/test [path] [--watch] [--coverage] [--filter <pattern>] [--fail-fast] [--seed <n>]
```

## What It Does
Detects the test framework, runs the suite, collects coverage data, identifies failures with root cause analysis, and reports results in a structured format. Diagnoses each failure by reading both the test and the code under test.

## Implementation
1. **Detect test framework** from project config (ExUnit, Vitest, Jest, Go test, pytest).
2. **Prepare environment** -- ensure test DB exists, migrations run, test deps installed.
3. **Run tests** with appropriate flags. Capture stdout, stderr, exit code, duration.
4. **Parse results** -- total, passed, failed, skipped. Per-failure: file, line, assertion, expected vs actual.
5. **Diagnose failures** -- read test source + code under test, identify root cause, suggest fix.
6. **Coverage analysis** (if `--coverage`) -- identify files below 80%, list uncovered branches, suggest tests to write.

## Examples
```bash
# Run full test suite
/test

# Run specific file with coverage
/test test/engine_test.exs --coverage

# Run tests matching pattern
/test --filter "user authentication"

# Watch mode during development
/test --watch --fail-fast
```
