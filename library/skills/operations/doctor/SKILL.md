# /doctor

> Diagnose and repair system issues -- dependencies, config, engine health.

## Usage
```
/doctor [--fix]
```

## What It Does
Checks that all system components are properly configured and operational. Verifies Elixir/Mix installation, engine compilation, SQLite database, folder structure, and MCP server connectivity. Reports issues with specific remediation steps.

## Implementation
1. **Elixir toolchain** -- verify `elixir --version`, `mix --version`.
2. **Engine compilation** -- `cd engine && mix compile` succeeds.
3. **Dependencies** -- `cd engine && mix deps.get` up to date.
4. **Database** -- SQLite file exists and is readable.
5. **Folder structure** -- all 12 numbered folders exist with context.md.
6. **Search index** -- FTS5 index is populated and queryable.
7. **Rhythm files** -- required workflow files exist.
8. **Config** -- engine config is valid.

With `--fix`: attempt to repair issues automatically (install deps, create missing files, rebuild index).

## Examples
```bash
# Check system health
/doctor

# Check and auto-fix issues
/doctor --fix
```
