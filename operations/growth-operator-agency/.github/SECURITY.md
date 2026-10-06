# Security

## Data contract — INV-11

Growth Operating Agency is structured around a hard split between **template structure** (shippable) and **encoded creator content** (never shippable).

| Layer | What lives there | Safe to commit? |
|---|---|---|
| `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `spec/`, `skills/*/SKILL.md`, `agents/`, `reference/` | Heuresis-authored template structure | Yes |
| `company.yaml` (template form, all fields empty) | Empty scaffold | Yes |
| `company.yaml` (filled with creator values) | Creator IP | **No** |
| `_private/*  # auto-created on first use` | Creator research, notes, drafts | **No** |
| `output/*` | Generated artifacts per creator | **No** |
| `.env` / `.env.local` | Credentials | **No** |
| `.env.template` | Variable names only, no values | Yes |

The `.gitignore` enforces this split automatically. Do not remove the `.gitignore` entries under "Creator-encoded private data" or "Credentials" without explicit approval.

## Credentials

- Copy `.env.template` to `.env.local` before filling values.
- Never commit a file that contains a real API key, access token, database password, or OAuth secret.
- Rotate any credential that touches this repository if it is ever mistakenly committed, even after the commit is deleted — Git history retains removed values.
- Store long-lived secrets in the creator's preferred secret manager (1Password, Doppler, Infisical, AWS Secrets Manager). The `.env.local` file is a developer-ergonomic local copy, not the source of truth.

## When forking the template for a new creator

1. Reset `company.yaml` to its empty-template form before initializing the new workspace.
2. Start `_private/` empty (only `.gitkeep`).
3. Start `output/` empty (only `.gitkeep`).
4. Verify `.gitignore` is present and unchanged.
5. Run `git log` against the new workspace to confirm no creator data has been accidentally pulled in from a prior fork.

## Reporting a vulnerability

If a security issue is discovered in this template — for example, a skill that leaks context it should not, an adapter that exposes a credential, or a `.gitignore` gap — write to **security@heuresis.ai** with a reproduction and the severity you believe applies.

Do not open a public issue for security reports. Internal triage happens first.

## Supply chain

- This template has no runtime dependencies. It is markdown and YAML.
- When a runtime (slash-command runtime, the workspace manifest, Codex, Cursor, OpenClaw, custom HTTP adapter) loads the workspace, the runtime's own security posture applies on top.
- MCP servers referenced in `reference/canonical/spec/INTEGRATIONS.md` should be audited before production use. Heuresis does not own or guarantee third-party MCPs.

---

*Growth Operating Agency — a Heuresis workspace template.*
