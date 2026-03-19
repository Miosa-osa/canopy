# /build

> Detect project type, compile, and report errors with actionable fixes.

## Usage
```
/build [path] [--clean] [--verbose] [--target <env>]
```

## What It Does
Scans the project root for config files (mix.exs, package.json, Cargo.toml, go.mod, Makefile), runs the appropriate build command, captures output, and reports errors with structured diagnostics. Handles monorepos by detecting and building each sub-project.

## Implementation
1. **Detect project type** from config files in priority order.
2. **Check prerequisites** -- verify toolchain installed, deps fetched.
3. **Clean** (if `--clean`) -- remove build artifacts.
4. **Build** -- run the build command, capture stdout/stderr/exit code/duration.
5. **Parse errors** -- extract file paths, line numbers, error types. Suggest fixes.
6. **Report** -- structured build report with errors, warnings, artifacts.

| Config File | Language | Build Command |
|-------------|----------|---------------|
| mix.exs | Elixir | `mix compile` |
| package.json | Node.js | `npm run build` |
| Cargo.toml | Rust | `cargo build` |
| go.mod | Go | `go build ./...` |
| Makefile | Make | `make` |

## Examples
```bash
# Build current project
/build

# Clean build for production
/build --clean --target prod

# Build specific sub-project in monorepo
/build engine/

# Verbose output for debugging build issues
/build --verbose --clean
```
