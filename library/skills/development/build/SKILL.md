---
name: build
description: "Detect project type, compile, and report errors with actionable fixes. Auto-detects toolchain from config files (mix.exs, package.json, Cargo.toml, go.mod, Makefile), runs the appropriate build command, captures output, and returns structured diagnostics with suggested fixes. Handles monorepos by detecting and building each sub-project. Use when you need to compile a project, diagnose build failures, or verify a clean build before deploy."
user-invocable: true
triggers:
  - build
  - compile
  - make
  - build project
  - clean build
  - build errors
---

# /build

> Detect project type, compile, and report errors with actionable fixes.

## Usage

```bash
/build [path] [--clean] [--verbose] [--target <env>]
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `path` | string | `.` | Project root or sub-project path |
| `--clean` | flag | false | Remove build artifacts before building |
| `--verbose` | flag | false | Show full build output for debugging |
| `--target` | string | `dev` | Build environment: `dev`, `prod`, `test` |

## Workflow

1. **Detect project type** from config files in priority order.
2. **Check prerequisites** — verify toolchain installed, deps fetched.
3. **Clean** (if `--clean`) — remove build artifacts.
4. **Build** — run the build command, capture stdout/stderr/exit code/duration.
5. **Parse errors** — extract file paths, line numbers, error types. Suggest fixes.
6. **Report** — structured build report with errors, warnings, artifacts.

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

## Output

```markdown
## Build Report

- **Project**: my-app (Elixir)
- **Command**: `mix compile`
- **Duration**: 4.2s
- **Result**: FAILED (2 errors, 1 warning)

### Errors
1. `lib/parser.ex:42` — undefined function `String.trim_leading/2` → Use `String.trim_leading/1` with a trim pattern
2. `lib/router.ex:18` — module `Plug.Router` is not available → Run `mix deps.get`

### Warnings
1. `lib/utils.ex:7` — variable `result` is unused

### Suggested Fixes
- Run `mix deps.get` to fetch missing dependencies
- Fix function call at `lib/parser.ex:42`
```
