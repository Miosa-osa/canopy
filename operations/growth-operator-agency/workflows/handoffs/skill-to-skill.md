# Skill-to-Skill Handoff

> Used when one skill programmatically invokes another with no human in the loop. Distinct from `standard.md` (phase transition with human gate) and `quality-revision.md` (revision after gate failure).

## When to use

- `/plan-launch` invokes `/build-funnel` to generate funnel assets as part of launch-prep
- `/research` invokes `/competitor-intel` to pull competitive context mid-research
- `/design-offer` invokes `/build-positioning` (if not yet run) to populate positioning fields
- Any chained execution where human-in-the-loop approval is NOT required between steps

## Contract

```markdown
## Skill-to-Skill Invocation

**Invoking skill:** {{source-skill-slug}} (e.g., plan-launch)
**Invoked skill:** {{target-skill-slug}} (e.g., build-funnel)
**Parent workflow ID:** {{workflow-instance-uuid}}
**Invocation type:** {{sync | async | streaming}}

### Inputs passed
Structured YAML matching the target skill's Input schema from `adapters/http.openapi.yaml`:

```yaml
inputs:
  # Fields per target skill's frontmatter.required_compartments + explicit args
```

### Context inheritance
The target skill inherits:
- All `reference/` files loaded by the invoking skill (no re-load)
- The parent workflow's L0 context (SYSTEM.md, ENCODING.md, INVARIANTS.md, company.yaml)
- Any prior artifacts produced in this workflow (paths passed explicitly)

### Expected output
- Artifact file path the target skill writes to
- Minimum completeness score for invocation to be considered successful
- Back-channel for warnings (written to `.growth-os/event_log.jsonl`)

### Failure handling
- **Soft fail** (completeness below threshold): invoking skill logs warning, continues
- **Hard fail** (skill errors out): invoking skill aborts and propagates the error upward via standard handoff to human
- **Quality-gate fail**: route to `quality-revision.md` against the invoked skill; retry up to INV-13 limit

### Budget allocation
- Tokens: split from parent budget per agent-level budget declaration in `agents/<name>.md`
- Time: inherits parent time-budget
```

## Invariants for skill-to-skill chains

1. **No circular invocation.** Skill A cannot invoke Skill B that invokes Skill A. Detected via workflow-ID graph in `.growth-os/event_log.jsonl`.
2. **Depth limit.** Maximum 5 levels of nested skill invocation before escalation to human.
3. **Budget inheritance.** Child invocations cannot exceed parent's remaining budget. If budget would be exceeded, child is deferred and user notified.
4. **L0 preservation.** All chained skills must run under the same `company.yaml` + `ENCODING.md`. No cross-operation invocation without explicit user approval.
5. **Event-log discipline.** Every skill-to-skill invocation logs entry + exit to `.growth-os/event_log.jsonl` for audit.

## Example — `/plan-launch` → `/build-funnel`

```yaml
## Skill-to-Skill Invocation
invoking_skill: plan-launch
invoked_skill: build-funnel
parent_workflow_id: 7a3f2c1d
invocation_type: sync

inputs:
  funnel_type: vsl-to-application
  offer_tier: high-ticket
  pricing_anchor: $3000
  source_traffic: paid-meta + organic-youtube

context_inheritance:
  loaded_refs:
    - reference/frameworks/offer-architecture/grand-slam-offer.md
    - reference/operators/vsl-director.md
  prior_artifacts:
    - output/foundations/offer-document.md
    - output/foundations/icp-document.md

expected_output:
  path: output/funnels/launch-funnel-v1.md
  min_completeness: 80
  max_time_sec: 180

failure_handling:
  soft_fail: log + continue with warning
  hard_fail: abort parent, escalate to sales-head agent
  quality_gate: route to quality-revision, max 2 retries

budget:
  tokens: 12000 (from parent 30000 budget)
  time: 180 seconds
```

## Cross-References

- `standard.md` — human-gated phase transitions
- `quality-revision.md` — when invoked skill fails a gate
- `../spec/RUNTIMES.md` — adapter contract
- `../INVARIANTS.md` — INV-13 revision limit

---
*Workspace: Growth Operating Agency v1.0 — skill chain protocol*
