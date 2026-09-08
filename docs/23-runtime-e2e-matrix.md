> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Runtime E2E Matrix — April 20 2026

Test run: `POST /api/v1/runtimes/detect` (server_detect) → `GET /runtimes/:type/auth/status` → `POST /api/v1/sessions {interactive: true}` → WS channel join `terminal:session:<id>` → 4s output wait.

Backend: `:9190`. Detection refresh triggered before test run.

## Results

| Runtime | Name | Installed | Auth State | Spawn HTTP | Spawn Error | WS Channel | Output Bytes (4s) | Verdict |
|---------|------|-----------|------------|-----------|-------------|------------|-------------------|---------|
| `claude-local` | Claude Code | ✓ `/Users/rhl/.local/bin/claude` | cli_login ✓ | 201 | — | ok | 287 | ✓ WORKING |
| `codex-local` | OpenAI Codex CLI | ✓ `/opt/homebrew/bin/codex` | subscription_detect ✓ (auth.json) | 201 | — | ok | 279 | ✓ WORKING |
| `aider-local` | Aider | ✓ `/Users/rhl/.local/bin/aider` | api_key (ANTHROPIC_API_KEY via env) | 201 | — | ok | 3976 | ✓ WORKING |
| `opencode-local` | OpenCode | ✓ `/opt/homebrew/bin/opencode` | api_key (OPENAI_API_KEY via env) | 201 | — | ok | 678 | ✓ WORKING |
| `anthropic-api` | Anthropic API | ✓ (api kind) | api_key (env_var) | 201 | — | rejected (no PTY) | — | ⚠ NOT INTERACTIVE |
| `openai-api` | OpenAI API | ✓ (api kind) | api_key (env_var) | 201 | — | rejected (no PTY) | — | ⚠ NOT INTERACTIVE |
| `groq-api` | Groq API | ✓ (api kind) | api_key (env_var) | 201 | — | rejected (no PTY) | — | ⚠ NOT INTERACTIVE |
| `mistral-api` | Mistral API | ✓ (api kind) | api_key (env_var) | 201 | — | rejected (no PTY) | — | ⚠ NOT INTERACTIVE |
| `gemini-cli` | Google Gemini CLI | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `gemini-local` | Google Gemini (legacy) | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `amp` | Sourcegraph Amp | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `cline` | Cline (Claude Dev) | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `continue-cli` | Continue CLI | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `crush` | Crush (Charm) | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `cursor-local` | Cursor Agent | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `cursor-agent` | Cursor Agent CLI | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `goose` | Goose (Block) | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `gpt-engineer` | GPT Engineer | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `hermes-local` | Hermes | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `opendevin` | OpenDevin | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `pi-local` | Pi | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `smol-developer` | Smol Developer | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `windsurf-local` | Windsurf | ✗ not found | — | — | — | — | — | ⚠ NEEDS INSTALL |
| `ollama` | Ollama | ✗ not found | no auth needed | — | — | — | — | ⚠ NEEDS INSTALL |
| `llamacpp` | llama.cpp | ✗ not found | no auth needed | — | — | — | — | ⚠ NEEDS INSTALL |

## Summary

| Category | Count |
|----------|-------|
| ✓ WORKING | 4 |
| ⚠ NOT INTERACTIVE (API runtime — no TUI) | 4 |
| ⚠ NEEDS INSTALL (binary not on PATH) | 17 |
| ✗ BROKEN | 0 |
| **Total** | **25** |

## Working Runtimes — Detail

### claude-local
- Binary: `/Users/rhl/.local/bin/claude`
- Auth: `cli_login` via `claude auth status` → `"loggedIn": true`
- Spawn args: `claude --dangerously-skip-permissions`
- WS: channel join ok, 287 bytes in 4s (TUI init frame)

### codex-local
- Binary: `/opt/homebrew/bin/codex`
- Auth: subscription detected via `~/.codex/auth.json` (fixed — see bugs section)
- Spawn args: `codex --yes`
- WS: channel join ok, 279 bytes in 4s (TUI init frame)

### aider-local
- Binary: `/Users/rhl/.local/bin/aider`
- Auth: reads `ANTHROPIC_API_KEY` from system env at spawn time — no Canopy-managed credential needed
- Spawn args: `aider` (no default args)
- WS: channel join ok, 3976 bytes in 4s (full TUI init with model listing)

### opencode-local
- Binary: `/opt/homebrew/bin/opencode`
- Auth: reads `OPENAI_API_KEY` from system env at spawn time
- Spawn args: `opencode` (no default args)
- WS: channel join ok, 678 bytes in 4s (TUI splash screen)

## API Runtimes — Behavior Note

`anthropic-api`, `openai-api`, `groq-api`, `mistral-api` all get `installed: true` from the detector (correct — no binary needed). The `POST /sessions` endpoint returns 201 with a `channel_topic`. When the WS joins, `SpawnPipeline` reaches `:resolve_command` and fails with `{:no_binary_path, type}` because `binary_path` is nil for api-kind runtimes. The channel rejects with `pty_start_failed`. This is **correct behavior** — these runtimes are not TUI CLIs. They are accessed via adapter pattern (headless mode), not interactive terminal.

## Bugs Found and Fixed

### Bug 1 — `codex-local` auth profile: wrong credential file path + invalid CLI detect command

**Severity:** MEDIUM — causes `/runtimes/codex-local/auth/status` to hang (blocks HTTP connection) and shows `subscription_detected: false` even when user is logged in.

**Root cause:** `seeds.exs` had two errors in the `codex-local` auth profile:
1. `subscription_detect.check_path` was `~/.codex/credentials.json` — codex stores credentials at `~/.codex/auth.json`
2. `cli_login.detect_command` was `codex auth status` — codex has no `auth status` subcommand; the command exits with an error but also appears to hang under beam's `System.cmd`, saturating the HTTP connection pool

**Fix applied:**
- `seeds.exs`: corrected `check_path` to `~/.codex/auth.json`, removed the invalid `cli_login` block, updated `methods` to `["subscription_detect", "api_key"]`
- DB: patched live via psql — `auth_profile` column updated immediately without restart

**File changed:** `/Users/rhl/Desktop/OptimalOS/CanopyOS/canopy/backend/priv/repo/seeds.exs` (lines 33–49)

**Verification:** After DB patch, `subscription_detected` resolves to `true` (file exists at `~/.codex/auth.json`), and the hanging `cli_login` detection path is no longer invoked.

## Install Commands for Missing Runtimes

| Runtime | Install |
|---------|---------|
| `gemini-cli` / `gemini-local` | `npm install -g @google/generative-ai-google-cloud-sdk` or via Google Cloud SDK |
| `amp` | `npm install -g @sourcegraph/amp` |
| `goose` | `brew install block-goose-cli` |
| `aider-local` | ✓ already installed |
| `crush` | `brew install charmbracelet/tap/crush` |
| `cursor-local` / `cursor-agent` | Cursor desktop app required — no standalone CLI |
| `continue-cli` | VS Code / JetBrains extension — no standalone CLI |
| `cline` | VS Code extension — no standalone CLI |
| `opendevin` | `pip install opendevin` or Docker |
| `gpt-engineer` | `pip install gpt-engineer` |
| `smol-developer` | `pip install smol-dev` |
| `windsurf-local` | Windsurf desktop app required |
| `hermes-local` | Not a widely-distributed CLI — seed may be aspirational |
| `pi-local` | Not a widely-distributed CLI — seed may be aspirational |
| `ollama` | `brew install ollama` |
| `llamacpp` | `brew install llama.cpp` |

## Test Harness

Script: `/tmp/runtime-e2e-test.mjs`
Rerunnable: yes — creates new sessions per run, no cleanup needed (sessions are idempotent)
Dependencies: Node.js v24, `ws@8.20.0` (global), backend on `:9190`
