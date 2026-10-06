# Skill Authoring

Every skill is a folder. Every skill has the same shape. A skill written today works unchanged on any runtime that reads markdown and YAML — that is [INV-10](../INVARIANTS.md).

---

## The folder shape

```
skills/{slug}/
├── SKILL.md                    ← the runtime-agnostic canonical
├── reference/                  ← layer 2 knowledge local to this skill
├── examples/                   ← golden outputs for calibration
├── evidence/
│   ├── blind-output-test.md    ← verification protocol
│   ├── failure-modes.md        ← what can go wrong
│   └── runs/                   ← run-by-run log
└── adapters/
    ├── claude-code.md          ← the slash-command runtime binding
    ├── manifest.yaml             ← workspace manifests binding
    └── http.openapi.yaml       ← HTTP / OpenAPI binding (v1.1 target)
```

When the runtime scans `skills/*/SKILL.md` at boot, every skill folder is discovered automatically. Adding a new skill is adding a new folder — no registry, no manifest, no central index.

---

## `SKILL.md` — the canonical

### Frontmatter

```yaml
---
name: "Design Offer"
id: design-offer
department: foundations
tier: sacred-format
description: "Produce an Offer Document with Value Stack, Bonuses, Guarantee, and 3:1 economics gate."
agent_affinity: [offer-architect, foundations-head]
required_compartments:
  - creator_identity_matrix: 0.5
  - audience_intelligence_system: 0.7
  - offer_architecture: 0.3
writes_to_compartments:
  - offer_architecture
required_tools: [file_read, file_write, file_edit, filesystem]
signal:
  mode: creator
  genre: offer-document
  type: sacred-format
  format: markdown
  structure: 12-section
evidence_gate:
  - blind_output_test_passed
  - signal_score >= 0.8
  - economics_validation_passed
execution_mode: interactive
---
```

### Body sections (fixed order)

1. **Role** — one paragraph declaring what the skill is and what it produces.
2. **Decision Logic** — the WHY. Tradeoffs, judgment rules, tacit principles. This is the load-bearing part.
3. **Tacit Principles** — 5–10 rules the skill enforces without asking.
4. **Process** — numbered phases. Each phase has a clear input and output.
5. **Output Format** — the exact shape of the deliverable. If sections are missing, flag with `[GAP: section N]` — never silently truncate.
6. **Context Requirements** — which compartments are read, which are written, which are checked for threshold.
7. **Verification Checklist** — what must be true before the artifact ships.
8. **Important Rules** — hard constraints. Typically a list of NEVERs.
9. **Cross-skill Routing** — what skill runs next, what skill runs first, conditional routes.

### Anti-patterns

- Do not reference a specific runtime in the body. No "use the Read tool" — just "read the compartment."
- Do not hardcode file paths. Describe inputs abstractly ("the creator's ICP compartment"), adapters resolve paths.
- Do not rename named frameworks. the 7-Phase Offer Building System stays as the 7-Phase Offer Building System. Renaming severs the lineage.
- Do not use banned vocabulary. Run the banned-vocab check before commit. See [`spec/BANNED-VOCABULARY.md`](../spec/BANNED-VOCABULARY.md).

---

## `adapters/claude-code.md`

```markdown
---
description: Produce an Offer Document with Value Stack, Bonuses, Guarantee, 3:1 economics gate.
argument-hint: "[optional: offer name or product]"
allowed-tools: Read, Write, Edit, Grep, Glob
---

# /design-offer — the slash-command runtime binding

Load and execute `skills/design-offer/SKILL.md` in the current workspace.

## Runtime behavior

1. Read context:
   - read `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - read `skills/design-offer/SKILL.md` (full body)
   - read `skills/design-offer/reference/` (all files)
   - `Read` upstream: `output/build-icp/latest.md`, `output/build-positioning/latest.md`

2. Pre-flight check: verify required_compartments thresholds in `company.yaml`. If below threshold, enter Compartment Interview Mode.

3. Execute Process per SKILL.md — follow numbered phases.

4. Write output: `output/design-offer/{YYYY-MM-DD}-offer-document.md`.

5. Update `company.yaml` compartments declared in SKILL.md frontmatter.

6. Post-ship: write run log to `skills/design-offer/evidence/runs/{date}-run.md`.

## Quality gates

- Triple-layer verification per `reference/canonical/spec/QUALITY.md`.
- Banned-vocabulary check per `spec/BANNED-VOCABULARY.md`.
- Economics: 3:1 LTV:CAC enforced per INV-4.
- Signal score ≥ 0.8 before ship.
- Blind Output Test queued for sacred-format skills.

## Failure handling

Per `workflows/handoffs/quality-revision.md`: auto-revise once, then surface the gap to the creator, then escalate.

`$ARGUMENTS`
```

Adapter files should be ≤ 50 lines. If they exceed 50, decision logic has leaked from `SKILL.md` — pull it back.

---

## `adapters/manifest.yaml`

```yaml
skill_id: design-offer
skill_path: skills/design-offer/SKILL.md
skill_name: "Design Offer"

tier: reasoning_ai
category: foundations
temperature_gate: warm

role_affinity:
  - offer-architect
  - foundations-head

required_tables:
  - creators
  - agents
  - events
  - documents

tools:
  - file_read
  - file_write
  - file_edit
  - filesystem

execution_mode: interactive
temperature: 0.5

evidence_gate:
  - blind_output_test_passed
  - signal_score >= 0.8
  - economics_validation_passed

context_slices:
  read:
    - creator_identity_matrix
    - audience_intelligence_system
    - offer_architecture
  write:
    - offer_architecture

output:
  location: "output/design-offer/{date}-offer-document.md"
  format: markdown
  signal_tuple:
    mode: creator
    genre: offer-document
    type: sacred-format
    format: markdown
    structure: 12-section

next_skill_routing:
  on_complete:
    - condition: "economics_validation_passed"
      recommend: build-vsl
  on_fail:
    escalate_to: foundations-head

logging:
  phase_transitions: true
  source_count: true
  confidence_per_section: true
  blind_output_test_required: true
```

---

## `evidence/blind-output-test.md`

Three tiers exist depending on the artifact:

| Tier | Pass criteria | Applies to |
|---|---|---|
| **Sacred-format** | 3/3 evaluators | `design-offer`, `build-positioning`, `extract-voice`, `build-vsl`, `webinar-script`, `plan-launch`, `case-study` |
| **External** | 2/3 evaluators | Content, ad, email, funnel, partnership skills |
| **Internal** | 1/3 evaluators | `build-icp`, `build-sop`, `hiring-brief`, `retention-check`, `competitor-intel`, `revenue-report`, `launch-report` |

The `evidence/blind-output-test.md` file scaffolds evaluator roster, test protocol, known failure modes, and revision log. See any existing skill's file for the canonical shape — `skills/research/evidence/blind-output-test.md` is the reference.

---

## Adding a new skill

1. Pick a slug. Use kebab-case. Keep it to 2–3 words. Verb-noun structure is strongest — `build-icp`, `design-offer`, `write-linkedin-post`.
2. Create the folder `skills/{slug}/` with the five subdirectories above.
3. Write `SKILL.md` first. Get Decision Logic and Process right before any adapter work.
4. Run the skill manually against a test creator to validate the Process section.
5. Once Process is proven, write the the slash-command adapter. Keep it thin.
6. Write the manifest adapter in parallel.
7. Scaffold `evidence/blind-output-test.md` with the right tier classification.
8. Add a `.claude/commands/{slug}.md` that points at the the slash-command adapter.
9. Add the entry to `skills/_INDEX.md`.
10. Update `CHANGELOG.md`.

---

## Modifying an existing skill

Changes to `SKILL.md` Decision Logic, Tacit Principles, or Output Format cascade through every output the skill ever produced. Before modifying:

1. Read the skill end to end.
2. Check which compartments it reads and writes.
3. Check which downstream skills depend on its output.
4. Check the blind-output-test failure-modes — is this change addressing a known failure?
5. Run the change against at least one test creator before committing.

Changes to adapter files are safe in isolation. Changes to `SKILL.md` are not.

---

## Quality gates before commit

Per [`.github/CONTRIBUTING.md`](../CONTRIBUTING.md):

- Banned-vocabulary sweep clean.
- No hardcoded `/Users/...` paths.
- Every referenced file exists.
- Version footer updated on `skills/_INDEX.md` if the catalog changed.
- Cross-reference check — if Process references `reference/frameworks/foo/`, that file exists.

---

*Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
