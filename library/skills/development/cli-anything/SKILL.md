---
name: cli-anything
description: >
  Transform any GUI application into an agent-controllable CLI. 7-phase
  pipeline: analyze the GUI, design CLI commands, implement adapters,
  plan tests, write tests, document, and publish. Produces a standalone
  CLI tool that wraps GUI functionality for automation.
  Triggers on: "cli anything", "gui to cli", "make cli", "wrap gui", "automate application"
---

# /cli-anything

> Transform any GUI application into an agent-controllable CLI.

## Purpose

Take a GUI application (desktop app, web UI, or any interactive program) and produce a fully functional CLI wrapper that exposes its capabilities as scriptable commands. The 7-phase pipeline analyzes the application's interface, designs an ergonomic command structure, implements the adapter layer, writes comprehensive tests, generates documentation, and packages for distribution. The output is a standalone CLI tool that agents or humans can use to automate what previously required manual GUI interaction.

## Usage

```bash
# Analyze a desktop application
/cli-anything --app "Figma" --platform macos

# Transform a web application
/cli-anything --app "Jira" --url "https://myorg.atlassian.net" --auth oauth2

# Target specific GUI features only
/cli-anything --app "Photoshop" --features "resize,crop,export,batch"

# Skip to implementation (analysis already done)
/cli-anything --from analysis/figma-cli-design.md --phase implement

# Dry run — show planned CLI structure
/cli-anything --app "Slack" --dry-run
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--app` | string | required | Application name or path to analyze |
| `--platform` | enum | auto-detect | Target platform: `macos`, `linux`, `windows`, `web` |
| `--url` | string | — | URL for web applications |
| `--auth` | enum | — | Auth method: `oauth2`, `api-key`, `cookie`, `none` |
| `--features` | string | `all` | Comma-separated list of features to wrap |
| `--from` | string | — | Resume from existing analysis document |
| `--phase` | enum | `analyze` | Start from phase: `analyze`, `design`, `implement`, `test`, `document`, `publish` |
| `--dry-run` | flag | false | Show planned CLI structure without building |
| `--output` | string | `./<app>-cli/` | Output directory for the CLI project |
| `--language` | enum | `python` | Implementation language: `python`, `typescript`, `go`, `rust` |

## Workflow

### Phase 1: Analyze
Examine the GUI application. Identify all user-facing actions, input fields, navigation flows, and state transitions. Map the GUI's information architecture. Inventory available APIs, accessibility trees, or automation hooks. Output: feature inventory + interaction map.

### Phase 2: Design
Design the CLI command structure. Map GUI actions to CLI commands and subcommands. Follow POSIX conventions. Design flag names, argument ordering, and output formats. Ensure composability (pipe-friendly output). Output: command tree + flag specifications.

### Phase 3: Implement
Build the CLI adapter layer. For each command: implement the bridge to the application (via API, accessibility API, AppleScript, browser automation, or native bindings). Handle authentication, session management, and error translation. Output: working CLI source code.

### Phase 4: Plan Tests
Design the test strategy. Identify which commands can be tested with mocks vs. require integration. Define fixture data and expected outputs. Output: test plan document.

### Phase 5: Write Tests
Implement tests from the plan. Unit tests for command parsing and output formatting. Integration tests for API calls with recorded fixtures. E2E tests for critical flows. Output: test suite.

### Phase 6: Document
Generate CLI documentation: man page, `--help` text for every command, usage examples, and a quick-start guide. Include common automation recipes. Output: docs directory.

### Phase 7: Publish
Package the CLI for distribution. Create install script, add to package registry if applicable, and generate a release with changelog. Output: distributable package.

## Examples

### Transforming Figma into a CLI
```
/cli-anything --app "Figma" --platform web --auth oauth2 --features "export,inspect,components"

## Phase 2: CLI Design — figma-cli

figma-cli export <file-key> [--format png|svg|pdf] [--scale 2x] [--output ./]
figma-cli inspect <file-key> <node-id> [--property color|font|spacing|all]
figma-cli components list <file-key> [--filter "Button*"]
figma-cli components export <file-key> <component-name> [--format svg]
figma-cli auth login [--token <pat>]
figma-cli auth status

## Phase 3: Implementation
- Auth adapter: OAuth2 PKCE flow → token storage in keychain
- Export adapter: Figma REST API /v1/images endpoint
- Inspect adapter: Figma REST API /v1/files/:key/nodes
- Output: JSON by default, `--format table` for human reading
```

## Output

```markdown
## CLI-Anything Report — <app>

### Feature Inventory
- N GUI actions mapped
- N commands designed
- N implemented and tested

### Command Tree
<app>-cli
├── auth (login, logout, status)
├── <feature-1> (subcommands...)
├── <feature-2> (subcommands...)
└── config (set, get, list)

### Test Results
- Unit: N passed
- Integration: N passed
- E2E: N passed

### Distribution
- Package: <app>-cli v1.0.0
- Install: `pip install <app>-cli` | `npm install -g <app>-cli`
```

## Dependencies

- Application access (API keys, OAuth credentials, or local install)
- `/build` — Building the CLI package
- `/test` — Running the generated test suite
- `/commit` — Versioning the CLI source
- Platform-specific automation tools (AppleScript, accessibility APIs, Playwright)
