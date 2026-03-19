# /lint

> Run linters and formatters, report issues, auto-fix where possible.

## Usage
```
/lint [path] [--fix] [--strict] [--format <format>]
```

## What It Does
Detects the project language and runs appropriate linters and formatters. Reports style violations, potential bugs, and security issues. With `--fix`, auto-corrects fixable issues.

## Implementation
1. **Detect project type** and available linters.
2. **Run linters** in order:
   - Elixir: `mix format --check-formatted` + `mix credo --strict`
   - TypeScript/JS: `eslint` + `prettier --check`
   - Go: `golangci-lint run`
   - Python: `ruff check` + `black --check`
   - Rust: `cargo clippy`
3. **Parse output** -- extract file, line, rule, severity, message.
4. **Auto-fix** (if `--fix`) -- run formatters and auto-fixable rules.
5. **Report** -- categorized by severity (error, warning, info).

## Examples
```bash
# Check for lint issues
/lint

# Auto-fix all fixable issues
/lint --fix

# Strict mode (warnings become errors)
/lint --strict

# Lint specific directory
/lint lib/optimal_engine/
```
