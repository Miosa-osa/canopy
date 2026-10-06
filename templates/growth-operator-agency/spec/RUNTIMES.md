# RUNTIMES.md — Adapter Contract per Runtime

> **Runtime-agnostic guarantee.** Every skill written in this workspace works unchanged on any runtime that reads markdown + YAML. Runtime-specific implementation lives in `skills/{slug}/adapters/{runtime}.md` — never in SKILL.md body.

## Supported Runtimes (v1 scope)

| Runtime | Adapter status | Purpose |
|---|---|---|
| **slash-command runtime** | ✅ v1 primary | Slash commands via `.claude/commands/` |
| **workspace manifests** | ✅ v1 primary | Native workspace protocol compliance |
| **Codex (OpenAI)** | 🟡 v2 | Bulk code generation |
| **Cursor** | 🟡 v2 | Editor-embedded |
| **OpenClaw** | 🟡 v2 | Multi-channel gateway |
| **HTTP / OpenAPI** | 🟡 v3 | Generic REST bridge |
| **Generic LLM (ChatGPT/Ollama)** | ✅ always | Copy-paste SKILL.md as system prompt |

## The Adapter Contract

Each skill folder contains:
```
skills/{skill-slug}/
├── SKILL.md                    ← runtime-agnostic canonical
├── reference/                   ← layer 2 knowledge
├── examples/                    ← calibration outputs
├── evidence/                    ← blind-output-test + failure-modes
└── adapters/
    ├── claude-code.md           ← the slash-command runtime binding
    ├── manifest.yaml              ← workspace manifests binding
    ├── codex.md                 ← (future)
    ├── cursor.md                ← (future)
    ├── openclaw.yaml            ← (future)
    └── http.openapi.yaml        ← (future) REST API spec
```

## Adapter Responsibilities

An adapter is a **thin binding file** that translates the runtime-agnostic SKILL.md into something a specific runtime can execute. It should be **≤25 lines** in most cases. If your adapter exceeds 50 lines, the skill logic has leaked into the adapter — pull it back into SKILL.md.

## slash-command runtime Adapter (`adapters/claude-code.md`)

### Format
slash-command runtime reads slash commands from `.claude/commands/{command-name}.md`. The adapter points to SKILL.md and injects runtime-specific instructions.

### Template
```markdown
---
description: [one-line description for slash-command palette]
argument-hint: [optional args like "<topic>"]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /{skill-slug}

Read and execute the skill at `skills/{skill-slug}/SKILL.md`.

## Runtime-specific behavior
- Use Read tool to load company.yaml for context
- Write output to `output/{skill-slug}/{timestamp}.md`
- Use Edit tool for any revisions
- Commit output to evidence folder when passing Blind Output Test

## Arguments passed
$ARGUMENTS
```

### Example: `/research` command
Located at `.claude/commands/research.md` — binds to `skills/research/SKILL.md`.

## workspace manifests Adapter (`adapters/manifest.yaml`)

### Format
the workspace manifest discovers skills via `skills/*/SKILL.md` pattern. The adapter is a YAML file declaring runtime metadata.

### Template
```yaml
skill_id: "{skill-slug}"
skill_path: "skills/{skill-slug}/SKILL.md"
tier: structured_ai       # deterministic | structured_ai | reasoning_ai | generative_ai
category: "foundations"        # matches department
temperature_gate: warm         # cold (requires approval) | warm (standard) | hot (autonomous)
required_tables: []            # database tables this skill reads/writes
role_affinity: ["foundations-head", "icp-builder"]
execution_mode: interactive    # interactive | batch | streaming
evidence_gate:
  - blind_output_test_passed
  - signal_score >= 0.8
```

### Fields explained
- `tier` — The reliability tier mapping. `deterministic` = pure code, `structured_ai` = AI with schema output, `reasoning_ai` = AI with step-by-step reasoning, `generative_ai` = open-ended.
- `temperature_gate` — Governance binding. `cold` requires human approval per execution.
- `evidence_gate` — Conditions that must be true before output is considered "done".

## Generic LLM Adapter (always available)

If no adapter exists, any LLM can run the skill by:
1. User copies entire `SKILL.md` into the conversation as a system prompt
2. User pastes relevant `company.yaml` compartments as context
3. User invokes the skill by following the Process section
4. LLM produces output matching the Output Format

This is the **portability guarantee**. Every SKILL.md must work this way.

## What Belongs in SKILL.md vs Adapter

### SKILL.md (runtime-agnostic)
- Role / system prompt
- Decision Logic (the WHY)
- Tacit Principles (judgment rules)
- Process / numbered steps
- Output Format (exact deliverable structure)
- Important Rules (hard constraints)
- Context requirements
- Verification checklist

### adapter.{runtime} (runtime-specific)
- Tool bindings (which tools this runtime provides)
- File paths (where to read inputs, write outputs)
- Command palette entry (description + args)
- Runtime-specific optimizations (caching, streaming, batching)
- Database schema if runtime uses a DB
- Environment variables or API keys references

## Enforcement

- SKILL.md **must not** reference any specific runtime. No "use the Read tool" — just "read the compartment values."
- SKILL.md **must not** assume specific file paths. It describes inputs abstractly ("the creator's ICP compartment"), adapters resolve to concrete paths.
- Adapter files **must not** contain methodology or decision logic. If they do, pull it back into SKILL.md.

## Adding a New Runtime

To add a new runtime (e.g., Perplexity Agents or a future platform):

1. Write a new adapter file `adapters/{runtime}.{ext}` per skill
2. Write a runtime-level binding doc in this file (a new section below)
3. Test with one skill (recommend `/research` as first)
4. Validate output passes the same quality gates
5. Promote to v2+ support status

## The Cost-Everlasting Principle

**Runtime concerns change. Methodology doesn't.** The the offer architect 7-Phase Offer Building System will be valid in 2035. The slash-command API may not be. By forcing methodology into SKILL.md and runtime concerns into adapters, this workspace outlives any specific runtime.

This is operationalized INV-10. Runtime-agnosticism is how the workspace outlives every specific runtime it runs on.

## Sources

- the workspace manifest `architecture/adapters.md`
- Signal Theory — the 3-Layer Encoding Model (Layer 3 Technology Interface = adapters)
- the Encoded Founder methodology — "The encoded expertise is the asset. The runtime is disposable infrastructure."

---
*v1.0 — 2026-04-19*
