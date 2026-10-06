# HTTP-OPENAPI-ADAPTER.md — The REST Binding Contract

> **Status:** v3 target per `spec/RUNTIMES.md`. This document specifies the contract. Skeleton files live at `skills/{slug}/adapters/http.openapi.yaml`.

## Purpose

The HTTP/OpenAPI adapter is **the generic REST interface** to any Growth Operating Agency skill. It is the binding that lets a skill be called by:

- **Growth Operating Agency predecessor Next.js** front-end (the creator-facing app calling `/skills/design-offer/execute` from the browser)
- **Arbitrary backends** (Node, Go, Python, PHP — anything that speaks HTTP)
- **Zapier / Make / n8n** bridges when a creator wants a skill wired into their existing automation stack
- **Any future runtime** that has no purpose-built adapter — HTTP is the universal fallback

The HTTP adapter is **Layer 3 encoding** (Technology Interface) per Signal Theory. It contains zero business logic. It is a thin shim that describes the REST surface and forwards to whatever HTTP runtime executes the canonical `SKILL.md` body.

## File Naming

One file per skill, one path:

```
skills/{skill-slug}/adapters/http.openapi.yaml
```

The file is an **OpenAPI 3.1** specification, constrained to 25-50 lines. If it grows past 50, the skill has leaked into the adapter — pull it back into `SKILL.md`.

## Per-Skill Structure

Each `http.openapi.yaml` declares exactly:

- One `info` block (title, version, `x-skill-source: ../SKILL.md`)
- One POST path: `/skills/{skill-slug}/execute`
- One `components/schemas/Input` — the inputs the skill requires (derived from the skill's frontmatter `required_compartments` + Prerequisites)
- One `components/schemas/Output` — the response envelope (below)
- One `components/securitySchemes` block declaring auth

## Auth Convention

The default is **bearer token with `X-Growth-OS-Key` as the header name**. This binds to whatever the runtime executor accepts (API key, JWT, OAuth2 access token — the header transports the credential). OAuth2 flows are declared as a secondary security scheme where the downstream runtime supports it (e.g., when routing through a platform gateway).

```yaml
securitySchemes:
  GrowthOSKey:
    type: apiKey
    in: header
    name: X-Growth-OS-Key
```

All skill endpoints require this scheme. 401 is returned when the header is missing or invalid; 403 is returned when the key is valid but the key's scope does not permit this skill (INV-8 Platform-Specific Restraint — a key scoped to "marketing-assist" cannot invoke `/design-offer`).

## Request Envelope

Every skill receives the same envelope shape:

```json
{
  "skill": "design-offer",
  "inputs": { "offer_name": "...", "price_anchor": 9997, "...": "..." },
  "context_profile_id": "growth-os-2026-04-19",
  "options": { "stream": false, "variant": "A", "dry_run": false }
}
```

- `skill` — string, must match the path segment (server enforces)
- `inputs` — object conforming to the skill's `Input` schema (frontmatter-derived)
- `context_profile_id` — string, references a stored `company.yaml` snapshot the runtime loads as context (multi-tenant isolation)
- `options` — object: `stream` (boolean, enables SSE for long skills), `variant` (string, where the skill has variants — VSL A/B/C/D/E, webinar 1-6, launch 1-5), `dry_run` (boolean, returns what would be generated without persisting)

## Response Envelope

Every skill returns the same envelope shape:

```json
{
  "artifact_ref": "output/design-offer/2026-04-19-offer-doc.md",
  "status": "passed|held|failed",
  "quality_score": 0.87,
  "signal_theory_tuple": {
    "mode": "linguistic",
    "genre": "offer-doc",
    "type": "inform",
    "format": "markdown",
    "structure": "w-offer-doc-12-section"
  },
  "cost_tokens": 42831,
  "evidence_ref": "skills/design-offer/evidence/runs/2026-04-19-run.md"
}
```

- `artifact_ref` — relative path or URI to the generated artifact (markdown file, script, doc)
- `status` — `passed` (evidence gate green), `held` (gate failed, fix-paths included), `failed` (runtime error)
- `quality_score` — S/N Ratio per INV-13, 0.0-1.0
- `signal_theory_tuple` — the 5-tuple per INV-12, copied from the skill's frontmatter `signal:` block
- `cost_tokens` — total tokens consumed by the run (for chargeback / budget telemetry)
- `evidence_ref` — path to the per-run evidence document (confidence tags, source counts, blind-output-test status)

## Streaming Semantics

Long-running skills (`/research`, `/build-vsl`, `/plan-launch`) support **Server-Sent Events (SSE)** when `options.stream: true`. The content-type switches to `text/event-stream` and events follow:

```
event: phase
data: {"phase":"load-dependencies","at":"2026-04-19T13:20:10Z"}

event: partial
data: {"section":3,"content":"..."}

event: done
data: {"artifact_ref":"...","status":"passed","quality_score":0.87,...}
```

Skills with interactive mode (`execution_mode: interactive` in the frontmatter) surface the same response envelope at `event: done`. Non-streaming clients receive a single JSON response.

## Error Codes

| Code | Meaning |
|---|---|
| **400** | Bad inputs — `inputs` fails the skill's Input schema, or required fields missing |
| **401** | Missing or invalid `X-Growth-OS-Key` header |
| **403** | Valid key, but scope does not permit this skill (INV-8 violation) |
| **422** | Quality gate failed — run completed but did not pass `evidence_gate` conditions; body contains `held` status + fix-paths |
| **429** | Rate-limited — caller must back off per `Retry-After` header |
| **500** | Runtime error — unexpected exception during skill execution |

Error body shape:

```json
{
  "error": "quality_gate_failed",
  "detail": "LTV:CAC ratio 2.1 below 3.0 threshold",
  "fix_paths": ["raise_price", "reduce_cac", "add_continuity"],
  "evidence_ref": "skills/design-offer/evidence/runs/2026-04-19-held.md"
}
```

## Cross-Reference to Other Adapters

The HTTP adapter, the slash-command at `.claude/commands/{skill}.md`, and the manifest binding at `adapters/manifest.yaml` are **three ports onto the same skill**. They are not three skills. The `SKILL.md` body is the single source of truth. The adapters only differ in **how the runtime is invoked and how inputs/outputs are transported**:

- `adapters/claude-code.md` — slash command, tool-based I/O, local filesystem
- `adapters/manifest.yaml` — runtime tier registration, progressive disclosure, sandboxed execution
- `adapters/http.openapi.yaml` — REST endpoint, JSON envelope, HTTP transport

A change to methodology lives in `SKILL.md` and is instantly reflected across all three adapters. A change to transport lives in one adapter file and does not touch the others. This is the INV-10 Runtime-Agnostic File Contract operationalized at Layer 3.

## Implementation Notes

The HTTP adapter file **does not implement the skill**. It is a contract file that:

1. Declares the REST surface (path, method, request schema, response schema, auth)
2. References the canonical SKILL.md via `x-skill-source: ../SKILL.md`
3. Is consumed by whatever HTTP runtime actually executes (a Next.js route, a Go handler, an AWS Lambda, a the workspace manifest-fronted endpoint)

The downstream HTTP runtime reads `SKILL.md`, loads the referenced `company.yaml` context profile, executes the skill's Process section, writes the artifact, and returns the envelope. The adapter is purely descriptive. Business logic stays in `SKILL.md`.

This is why the adapter stays at 25-50 lines. Any line count growth indicates skill logic leaking into transport — stop, pull it back into `SKILL.md`.

## Worked Example — `/design-offer`

```yaml
openapi: 3.1.0
info:
  title: design-offer
  version: 1.0.0
  x-skill-source: ../SKILL.md
  x-signal-tuple:
    mode: linguistic
    genre: offer-doc
    type: inform
    format: markdown
    structure: w-offer-doc-12-section
servers:
  - url: https://{host}/api/v1
    variables:
      host: { default: growth-os.local }
security:
  - GrowthOSKey: []
paths:
  /skills/design-offer/execute:
    post:
      summary: Execute design-offer skill (12-section Offer Document)
      x-evidence-gate: [economics_ltv_cac_gte_3, value_equation_score_gte_150, blind_output_test_passed]
      x-streaming: supported
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/Input' }
      responses:
        '200': { description: Passed, content: { application/json: { schema: { $ref: '#/components/schemas/Output' } } } }
        '422': { description: Held (quality gate failed) }
        '401': { description: Unauthorized }
        '403': { description: Scope violation (INV-8) }
components:
  securitySchemes:
    GrowthOSKey: { type: apiKey, in: header, name: X-Growth-OS-Key }
  schemas:
    Input:
      type: object
      required: [skill, inputs, context_profile_id]
      properties:
        skill: { type: string, const: design-offer }
        inputs:
          type: object
          required: [audience_intelligence_system_score, offer_architecture_score, creator_identity_matrix_score]
          properties:
            offer_name: { type: string }
            price_anchor: { type: number }
            audience_intelligence_system_score: { type: number, minimum: 70 }
            offer_architecture_score: { type: number, minimum: 20 }
            creator_identity_matrix_score: { type: number, minimum: 40 }
        context_profile_id: { type: string }
        options:
          type: object
          properties: { stream: { type: boolean, default: false }, dry_run: { type: boolean, default: false } }
    Output:
      type: object
      required: [artifact_ref, status, quality_score, signal_theory_tuple]
      properties:
        artifact_ref: { type: string }
        status: { type: string, enum: [passed, held, failed] }
        quality_score: { type: number, minimum: 0, maximum: 1 }
        signal_theory_tuple:
          type: object
          properties:
            mode: { type: string }
            genre: { type: string }
            type: { type: string }
            format: { type: string }
            structure: { type: string }
        cost_tokens: { type: integer }
        evidence_ref: { type: string }
```

## Sources

- `spec/RUNTIMES.md` — Adapter Contract per Runtime
- `protocol/skill-and-agent-system.md` Part 3 — Cross-Runtime Compatibility
- OpenAPI Specification 3.1.0 — <https://spec.openapis.org/oas/v3.1.0>
- INV-8 Platform-Specific Restraint, INV-10 Runtime-Agnostic File Contract, INV-12 Signal 5-Tuple, INV-13 S/N Quality Gate

---
*v1.0 — 2026-04-19. The HTTP adapter is the universal REST surface. Business logic stays in SKILL.md; transport stays here.*
