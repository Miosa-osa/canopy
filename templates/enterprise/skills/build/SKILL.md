# /build

> Build, compile, and test. Engineer-owned.

## Usage
```
/build [path] [--clean] [--test] [--verbose]
```

## What It Does
Detects project type, runs the build pipeline, captures errors, and reports results
with structured diagnostics. Optionally runs tests after build.

## Implementation
1. **Detect** — Identify project type from config files.
2. **Clean** — Remove build artifacts if `--clean`.
3. **Build** — Run build command, capture stdout/stderr/exit code.
4. **Test** — Run test suite if `--test`.
5. **Report** — Structured build report with errors, warnings, artifacts.

## Examples
```bash
/build
/build --clean --test
/build engine/ --verbose
```
