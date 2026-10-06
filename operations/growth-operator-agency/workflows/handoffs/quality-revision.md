# Quality Revision Handoff

> Used when a skill output fails a quality gate and requires revision. Per `INVARIANTS.md` INV-13, a maximum of 2 revision attempts is permitted before escalation.

## When to use

- Signal-theory S/N composite score below threshold (< 0.5 internal, < 0.8 external per `reference/canonical/spec/QUALITY.md`)
- Triple-layer verification failure (formal 40% / semantic 35% / information-theoretic 25%)
- Blind Output Test failure (0 of 3 evaluators said "expert")
- Critical-rule violation surfaced by agent or human review
- Banned vocabulary in output (`spec/BANNED-VOCABULARY.md`)

## Revision Handoff Block — required fields

```markdown
## Revision — {{skill}} — Attempt {{N}} of 2

**Date:** YYYY-MM-DD
**Artifact:** {{file-path}}
**Revision attempt:** {{N}} of 2

### 1. Original request
What was the skill asked to produce? Reference the originating handoff.

### 2. What was produced
Artifact path + completeness score + quality score breakdown (per 5-tuple).

### 3. Which gate failed
- Gate name: {{e.g., "Signal Theory — feedback-loop theory feedback loop"}}
- Threshold: {{e.g., 0.5}}
- Actual: {{e.g., 0.32}}
- Triple-layer breakdown:
  - Formal (40%): {{score}} — {{one-line reason}}
  - Semantic (35%): {{score}} — {{reason}}
  - Information-theoretic (25%): {{score}} — {{reason}}

### 4. Specific defects (cite lines)
- `file.md:42` — defect description
- `file.md:108` — defect description

### 5. What revision must address
Numbered list of what the revision MUST fix. Sections that passed are NOT rewritten. Only failed sections.

### 6. Preserved content
Explicit list of sections / paragraphs that passed quality and must NOT be touched by the revision.

### 7. Revision budget
Token/time budget for this revision. If exceeded, escalate per INV-13.
```

## The 2-Revision Rule

Per `INVARIANTS.md` INV-13:

- **Attempt 1** — original production
- **Attempt 2** — first revision after failure
- **Attempt 3** — second revision (last permitted)
- **Beyond Attempt 3** — escalate to user with:
  - Current score per gate
  - Specific gaps identified
  - Agent's best guess at root cause
  - Options for user (approve-with-exception / re-scope / kill)

No artifact cycles more than 2 revisions in the system. Indefinite revision loops violate INV-13 and indicate a scope problem, not a quality problem.

## Revision vs Re-run

**Revision:** fix specific defects in existing output. Preserve passing sections.

**Re-run:** discard output, run the skill from scratch. Use when:
- More than 60% of sections failed
- Input assumptions were wrong
- Wrong skill was invoked

## Escalation Path

If revision limit exhausted:

1. Agent writes escalation note to `.growth-os/event_log.jsonl`
2. Routes to Growth CEO (`agents/growth-ceo.md`)
3. Growth CEO summarizes to user with options
4. User decides: approve-with-exception / re-scope / abandon

## Cross-References

- `standard.md` — the normal phase-transition handoff
- `skill-to-skill.md` — programmatic invocation
- `../INVARIANTS.md` — INV-13 revision limit
- `../reference/canonical/spec/QUALITY.md` — verification spec
- `../reference/canonical/spec/BLIND-OUTPUT-TEST.md` — the gold-standard validation protocol

---
*Workspace: Growth Operating Agency v1.0 — revision contract per `INVARIANTS.md` INV-13*
