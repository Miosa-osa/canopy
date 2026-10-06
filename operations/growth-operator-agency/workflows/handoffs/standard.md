# Standard Handoff Protocol

> Every phase transition in a Growth Operating Agency workflow uses this template. Referenced from `SYSTEM.md` and `spec/WORKFLOW.md`.

## When to use

Use `standard.md` when passing work from one agent to another, or from one skill to the next in a chain (e.g., `/research` → `/build-icp`). Use `quality-revision.md` when the output of a skill failed a quality gate and needs revision.

## Handoff Block — required fields

Every handoff MUST include these 7 fields:

```markdown
## Handoff — {{source-skill}} → {{target-skill}}

**Date:** YYYY-MM-DD
**From agent:** {{agent-id}}
**To agent:** {{agent-id}}

### 1. Work completed
Specific outputs + outcomes produced by the source skill.

### 2. Decisions made
Each decision with rationale + rejected alternatives. This is the "why" trail.

### 3. Artifacts produced
File paths + completeness scores. Format:
- `reference/knowledge/foundations.md` — completeness 82/100
- `reference/knowledge/foundations.md` — completeness 90/100

### 4. Quality score (Signal Theory 5-tuple)
S = (M, G, T, F, W). Each dimension scored 0.0-1.0. Composite S/N must exceed threshold per `reference/canonical/spec/QUALITY.md`.

### 5. Context for next agent
Key findings, VOC phrases, framework outputs the downstream skill needs. Lift specific sentences verbatim if downstream will re-use.

### 6. Dependencies
Files + threshold conditions required before the next phase can start. If any dependency is not met, the handoff blocks.

### 7. Open items
Unresolved questions, data gaps, things the downstream agent should be aware of but not blocked on.
```

## Phase-specific context (Foundations chain)

The Foundations chain carries specific context forward at each step. Load-bearing.

### `:market_research` → `:build_icp`
Carry forward:
- `market_maturity_stage` (awareness-spectrum research 4-stage)
- `top_3_pain_signals` (ranked by intensity + frequency)
- `voc_phrases` (verbatim customer language)
- `competitive_landscape_summary`
- `demand_strength_score`
- `monetization_evidence`

### `:build_icp` → `:build_positioning`
Carry forward:
- `limiting_beliefs` (Worthless / Helpless / Hopeless diagnosis per Limiting Belief Triad)
- `awareness_levels` (per awareness-spectrum research)
- `transformation_type` (Status / Capability / Safety)
- `key_objections` (top 5 ranked)
- `voc_phrases`
- `icp_demographics_summary`

### `:build_positioning` → `:build_offer`
Carry forward:
- `positioning_angle` (unique mechanism named)
- `unique_mechanism_name`
- `differentiation_pillars`
- `pricing_signals` (from competitive analysis)
- `category_pov`

### `:build_offer` → `:foundations_complete`
Carry forward:
- `offer_structure` (tiered with value stack)
- `economics_summary` (LTV:CAC ≥ 3.0 validated)
- `belief_stack` (3-5 beliefs + installation methods)
- `value_proposition`
- `pricing_model`
- `guarantee_design`

## Cross-References

- `quality-revision.md` — use when the handoff fails a quality gate and revision is required
- `skill-to-skill.md` — use when one skill programmatically invokes another (no human in the loop)
- `../reference/canonical/spec/QUALITY.md` — triple-layer verification spec
- `../reference/canonical/spec/SIGNAL.md` — Signal Theory 5-tuple encoding

---
*Workspace: Growth Operating Agency v1.0 — handoff contract per `protocol/skill-and-agent-system.md`*
