# Verification Layer — Self-Validating Workspaces

> Every workspace can verify itself. The verification layer adds executable contracts
> that check whether a workspace matches its own specifications — agents exist, skills
> are complete, reference files are present, and specs haven't drifted from reality.
>
> **Design principle:** Verification is opt-in, file-based, and runtime-agnostic.
> A workspace without `spec/contracts/` works exactly as before. A workspace WITH
> contracts gains the ability to answer: "Am I structurally sound right now?"

---

## Why Verification

Workspaces rot. An agent references a skill that got renamed. A SYSTEM.md lists
five agents but only four exist. A spec declares a procedure that no skill implements.
A reference file goes stale while the context it describes has changed.

Without verification, these failures are silent. The agent hits a missing file at
runtime, hallucinates around it, and produces degraded output. Nobody notices until
the output quality drops enough to trigger a human investigation.

The verification layer makes structural integrity **checkable on demand**:

```
Without verification:
  Agent boots → discovers missing skill → hallucinates → bad output → human notices (maybe)

With verification:
  /verify runs → contract fails → "skills.qualify missing SKILL.md" → fix before execution
```

This is not testing in the traditional sense. There is no code under test. These are
**structural contracts** — assertions about the shape, completeness, and consistency
of the workspace itself.

---

## Directory Structure

```
workspace/
├── SYSTEM.md
├── agents/
├── skills/
├── reference/
├── spec/                              ← Executable specifications (existing)
│   ├── PROCEDURES.md                  ← Action/query bindings
│   ├── WORKFLOW.md                    ← FSM definitions
│   ├── MODULES.md                     ← DAG topology
│   ├── contracts/                     ← NEW: Verification contracts
│   │   ├── workspace.spec.md          ← Workspace completeness contract
│   │   ├── {module}.spec.md           ← Per-module contracts (optional)
│   │   └── state.json                 ← Verification state (generated)
│   └── decisions/                     ← NEW: Architecture Decision Records
│       ├── 001-fsm-pipeline-states.md
│       └── 002-meddpicc-qualification.md
└── company.yaml
```

Contracts live alongside the existing spec files. They extend the spec layer
without modifying it. A workspace can have PROCEDURES.md + WORKFLOW.md + MODULES.md
with no contracts (behavior as before), or add contracts for self-validation.

---

## Spec File Format

Each `.spec.md` file follows a structured format with fenced code blocks that use
typed language identifiers for machine parsing.

### Complete Example

```markdown
# Workspace Completeness

Verifies that the workspace follows the Workspace Protocol and all
declared components exist on disk.

## Meta
` ` `spec-meta
id: workspace.completeness
kind: policy
status: active
summary: Verifies workspace follows the Workspace Protocol
surface:
  - SYSTEM.md
  - agents/*.md
  - skills/*/SKILL.md
  - reference/*.md
  - company.yaml
` ` `

## Requirements
` ` `spec-requirements
- id: workspace.system_md_exists
  statement: The workspace shall have a SYSTEM.md at root
  priority: must
  stability: stable

- id: workspace.agents_declared
  statement: Every agent listed in SYSTEM.md shall exist as agents/{id}.md
  priority: must
  stability: stable

- id: workspace.skills_discoverable
  statement: Every skill referenced in SYSTEM.md shall exist as skills/{name}/SKILL.md
  priority: must
  stability: stable

- id: workspace.agents_valid
  statement: Every agent file shall have YAML frontmatter with name, role, and signal fields
  priority: should
  stability: stable

- id: workspace.company_yaml_exists
  statement: The workspace shall have a company.yaml at root
  priority: should
  stability: evolving
` ` `

## Verification
` ` `spec-verification
- kind: source_file
  target: SYSTEM.md
  covers:
    - workspace.system_md_exists

- kind: glob_match
  target: agents/*.md
  expected_min: 1
  covers:
    - workspace.agents_declared

- kind: glob_match
  target: skills/*/SKILL.md
  expected_min: 1
  covers:
    - workspace.skills_discoverable

- kind: frontmatter_check
  target: agents/*.md
  required_fields: [name, role, signal]
  covers:
    - workspace.agents_valid

- kind: source_file
  target: company.yaml
  covers:
    - workspace.company_yaml_exists
` ` `
```

### Block Types

| Block | Language ID | Purpose |
|-------|------------|---------|
| Meta | `spec-meta` | Identity, kind, status, surface area |
| Requirements | `spec-requirements` | What MUST be true (RFC 2119 language) |
| Verification | `spec-verification` | How to CHECK each requirement |

---

## Meta Block

```yaml
id: <dotted.identifier>      # Unique within the workspace
kind: policy | contract | constraint | invariant
status: active | draft | deprecated
summary: <one-line description>
surface:                      # Files this spec touches (for drift detection)
  - SYSTEM.md
  - agents/*.md
```

### Kind taxonomy

| Kind | Semantics | Example |
|------|-----------|---------|
| **policy** | Workspace-level structural rules | "Every agent must have frontmatter" |
| **contract** | Interface agreement between modules | "Pipeline module exposes /pipeline skill" |
| **constraint** | Boundary condition that must hold | "No more than 8 agents per workspace" |
| **invariant** | Condition that must hold at ALL times | "company.yaml budget >= sum of agent budgets" |

---

## Requirements Block

Each requirement is a YAML list item:

```yaml
- id: <dotted.identifier>        # Unique, referenced by verification block
  statement: <RFC 2119 language>  # Uses shall/must/should/may
  priority: must | should | may   # RFC 2119 priority
  stability: stable | evolving | experimental
```

### Priority semantics (RFC 2119)

| Priority | Meaning | Verification failure |
|----------|---------|---------------------|
| **must** | Absolute requirement. Workspace is broken without it. | ERROR — blocks execution |
| **should** | Strong recommendation. Workspace works but is degraded. | WARNING — flagged but not blocking |
| **may** | Optional enhancement. Nice to have. | INFO — noted but silent by default |

### Stability semantics

| Stability | Meaning | Drift tolerance |
|-----------|---------|----------------|
| **stable** | Settled requirement. Changes are rare. | Low — drift is almost certainly a bug |
| **evolving** | Requirement is expected to change. | Medium — drift may be intentional |
| **experimental** | Requirement is being tested. | High — drift is expected |

---

## Verification Block

Each verification entry maps a check method to one or more requirements:

```yaml
- kind: <verification_kind>
  target: <what to check>
  covers:
    - <requirement_id>
    - <requirement_id>
```

### Verification kinds

| Kind | What it does | Target format |
|------|-------------|---------------|
| `source_file` | Checks file exists | File path (relative to workspace root) |
| `glob_match` | Checks glob returns results | Glob pattern + `expected_min` / `expected_max` |
| `frontmatter_check` | Validates YAML frontmatter fields | Glob pattern + `required_fields` list |
| `content_match` | Checks file contains pattern | File path + `pattern` (regex) |
| `command` | Runs shell command, checks exit code | Shell command string |
| `cross_reference` | Checks X references Y | `source` glob + `target` glob + `link_field` |
| `schema_validate` | Validates against YAML/JSON schema | File path + `schema` (inline or path) |

### Verification strength levels

Every verification result carries a strength level:

| Level | Meaning | How achieved |
|-------|---------|-------------|
| **claimed** | Someone asserts coverage. No proof. | Manual annotation in the spec |
| **linked** | A file exists that references the requirement ID. | `source_file` or `glob_match` passes |
| **executed** | A command ran and produced a passing result. | `command` kind with exit code 0 |

The strength level determines confidence in the verification result:

```
claimed  →  "We say it's covered"          (weakest — trust but verify)
linked   →  "The file exists and matches"  (medium — structural proof)
executed →  "The check ran and passed"     (strongest — behavioral proof)
```

A healthy workspace has most `must` requirements at `linked` or `executed` strength.
A workspace with many `claimed` requirements is structurally opaque — it might work,
but you can't prove it.

---

## Drift Detection

Drift occurs when workspace files change but the spec doesn't update, or vice versa.
The verification layer detects drift by comparing the `surface` declaration in the
meta block against actual file modification times.

### How drift is detected

1. **Surface tracking**: Each spec declares its `surface` — the files it covers.
2. **State file**: `spec/contracts/state.json` records the last verification timestamp
   and file hashes for each surface file.
3. **Drift check**: On each verification run, compare current file hashes against
   stored state. If surface files changed since last verification, flag drift.

### state.json format

```json
{
  "last_verified": "2026-03-20T10:30:00Z",
  "specs": {
    "workspace.completeness": {
      "last_pass": "2026-03-20T10:30:00Z",
      "results": {
        "workspace.system_md_exists": { "status": "pass", "strength": "linked" },
        "workspace.agents_declared": { "status": "pass", "strength": "linked" },
        "workspace.skills_discoverable": { "status": "fail", "strength": "linked" }
      },
      "surface_hashes": {
        "SYSTEM.md": "sha256:a1b2c3...",
        "agents/closer.md": "sha256:d4e5f6..."
      }
    }
  }
}
```

### Drift categories

| Category | Trigger | Severity |
|----------|---------|----------|
| **Surface drift** | A surface file changed since last verification | Medium — re-verify |
| **Spec drift** | A spec file changed but wasn't re-verified | Low — normal during editing |
| **Phantom requirement** | Requirement ID referenced but not in any spec | High — broken reference |
| **Orphan verification** | Verification covers a requirement ID that doesn't exist | High — dead check |
| **Missing coverage** | Requirement exists but no verification covers it | Medium — unchecked requirement |

---

## Architecture Decision Records (ADRs)

ADRs capture durable architectural decisions for a workspace. They live in
`spec/decisions/` and follow a lightweight format.

### ADR format

```markdown
# ADR-{NNN}: {Title}

## Status
{proposed | accepted | deprecated | superseded by ADR-NNN}

## Context
What forces are at play. What problem prompted this decision.

## Decision
What we decided and why.

## Consequences
What follows from this decision — positive, negative, and neutral.
```

### ADR lifecycle

```
proposed → accepted → [deprecated | superseded]
```

- **proposed**: Under discussion. Not yet binding.
- **accepted**: Binding decision. Workspace should conform.
- **deprecated**: No longer applies. Kept for historical context.
- **superseded**: Replaced by a newer ADR. Link to the successor.

### ADR verification

ADRs can be referenced in spec requirements:

```yaml
- id: pipeline.fsm_states
  statement: All pipeline states shall be defined in WORKFLOW.md as FSM nodes
  priority: must
  stability: stable
  rationale: ADR-001
```

The `rationale` field links the requirement to the decision that motivated it.
This creates traceability from "what must be true" back to "why we decided this."

---

## Verification Execution Model

### Running verification

Verification is triggered by a workspace skill or CLI command:

```
/verify                          # Run all contracts
/verify workspace                # Run workspace.spec.md only
/verify --strength linked        # Only checks at linked+ strength
/verify --priority must          # Only must-priority requirements
/verify --drift                  # Only check for drift, don't re-verify
```

### Verification output

```
WORKSPACE VERIFICATION — sales-engine
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

workspace.completeness (policy, active)
  ✓ workspace.system_md_exists          [linked]   SYSTEM.md exists
  ✓ workspace.agents_declared           [linked]   5/5 agents found
  ✗ workspace.skills_discoverable       [linked]   4/5 skills have SKILL.md
    └─ MISSING: skills/battlecard/SKILL.md
  ✓ workspace.agents_valid              [linked]   5/5 agents have required frontmatter
  ✓ workspace.company_yaml_exists       [linked]   company.yaml exists

pipeline.contract (contract, active)
  ✓ pipeline.stages_defined             [executed]  7 stages in WORKFLOW.md
  ✓ pipeline.handoffs_declared          [linked]    handoffs/ directory present
  ~ pipeline.metrics_tracked            [claimed]   No verification defined

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RESULT: 7 pass, 1 fail, 1 claimed
DRIFT:  SYSTEM.md modified since last verification (2h ago)
ACTION: Fix skills/battlecard/SKILL.md, re-verify
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | All `must` requirements pass |
| 1 | One or more `must` requirements fail |
| 2 | Spec parse error (malformed contract) |

`should` and `may` failures produce warnings but do not affect exit code.

---

## Module-Level Contracts

Beyond workspace-level contracts, each module (defined in MODULES.md) can have
its own spec:

```
spec/contracts/
├── workspace.spec.md          ← Workspace completeness
├── pipeline.spec.md           ← Pipeline module contract
├── qualification.spec.md      ← Qualification module contract
└── state.json                 ← Generated verification state
```

Module contracts follow the same format but scope their surface area to the
module's components:

```yaml
# In pipeline.spec.md meta block
surface:
  - spec/WORKFLOW.md
  - skills/pipeline/SKILL.md
  - handoffs/pipeline-*.md
```

This enables **incremental verification** — check only the module you changed,
not the entire workspace.

---

## Composing Verification with the Spec Layer

The verification layer integrates with the existing spec layer (PROCEDURES.md,
WORKFLOW.md, MODULES.md) without modifying it:

```
MODULES.md declares topology  →  module.spec.md verifies it matches reality
WORKFLOW.md declares FSMs      →  workflow.spec.md verifies states are reachable
PROCEDURES.md declares bindings →  procedures.spec.md verifies skills implement them
```

### Cross-layer verification examples

| What to verify | Contract kind | How |
|---------------|---------------|-----|
| Every procedure has a skill | `cross_reference` | PROCEDURES.md action names vs skills/*/SKILL.md |
| Every FSM state has transitions | `content_match` | WORKFLOW.md state blocks contain `transitions:` |
| Module dependencies exist | `cross_reference` | MODULES.md `depends_on` vs actual module files |
| Agent skills are real | `cross_reference` | Agent frontmatter `skills:` vs skills/ directory |

---

## Governance Integration

Verification contracts connect to the governance layer (architecture/governance.md):

- **Board approval** can require verification pass before deployment
- **Audit logging** records verification results
- **Escalation** triggers when `must` requirements fail in production workspaces
- **Budget gating** can block agent execution if workspace fails verification

```yaml
# In company.yaml governance section
verification:
  required_before_deploy: true
  min_strength: linked
  max_failures:
    must: 0
    should: 3
```

---

## Design Decisions

### Why markdown, not YAML/JSON schemas

Contracts are markdown because:
1. **Human readable**: A salesperson can read `workspace.spec.md` and understand what's checked
2. **Version controlled**: Diffs are meaningful in PRs
3. **Composable**: Markdown supports narrative context around structured blocks
4. **Consistent**: Everything else in the workspace is markdown

The structured blocks inside the markdown (spec-meta, spec-requirements, spec-verification)
are YAML for machine parsing. This gives both human readability and machine executability.

### Why not traditional test frameworks

Traditional test frameworks (pytest, jest, ExUnit) are designed for code. Workspace
verification checks file existence, YAML structure, cross-references, and content
patterns. These are **structural assertions about a file tree**, not unit tests of
functions. The spec format is purpose-built for this domain.

### Why opt-in

Not every workspace needs verification. A personal knowledge base with three reference
files doesn't benefit from contracts. A production sales engine with five agents, seven
pipeline stages, and three approval gates absolutely does. The verification layer adds
value proportional to workspace complexity.

---

*Verification Layer v1.0 — Self-validating workspace contracts for OSA Operations*

---

## Signal Theory Position

This spec implements **Layer 6 (Feedback Loop)** of the Optimal System architecture.

Verification contracts ARE the feedback mechanism for structural integrity. Every `.spec.md` file encodes a Wiener loop: the intended state (the spec requirements) is compared against the actual state (the workspace file tree), discrepancies are detected (drift and failures), and corrections are surfaced (rejection notices and exit codes). Without this layer, structural drift is silent — the system loses its ability to self-correct.

The `state.json` file is the explicit loop-closure record: it stores the last-verified hashes so each subsequent run can compare actual against expected. The ADR format in `spec/decisions/` closes a second loop — from "what must be true" (requirements) back to "why we decided this" (rationale), making the feedback traceable across time.

**Most relevant governing principles:**
- **Wiener (feedback closure)** — Every verification run is a loop check. The `/verify` command is the agent asking: "Does the current state match the intended state?" Exit codes 0/1/2 are the system's answer.
- **Beer (structural coherence across layers)** — The cross-layer verification table (MODULES.md → topology, WORKFLOW.md → FSMs, PROCEDURES.md → bindings) ensures that Beer's requirement of coherence at every scale is enforceable, not just aspirational.

See `architecture/optimal-system-mapping.md` for the canonical layer mapping.
