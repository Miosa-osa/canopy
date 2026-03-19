---
name: rethink
description: >
  Synthesize accumulated observations into system evolution proposals. Fires when
  observation count reaches threshold. 5-phase process: triage, methodology updates,
  pattern detection, proposal generation, and human approval. Never auto-implements —
  always proposes changes for review.
  Triggers on: "rethink", "synthesize learnings", "evolve system", "improve process"
---

# /rethink

> Synthesize observations into system evolution — always with human approval.

## Purpose

The synthesis side of the learning loop. When enough observations accumulate in a category (tracked by `/remember`), rethink analyzes them for patterns, generates concrete improvement proposals, and presents them for human approval. This is how the system evolves: not through ad-hoc fixes, but through deliberate synthesis of accumulated evidence. Critical rule: rethink NEVER auto-implements changes. Every proposal requires explicit human approval.

## Usage

```bash
# Rethink a specific category
/rethink "process"

# Rethink with confidence override
/rethink "people" --force

# Rethink all categories that are ready
/rethink --all

# Dry run — show what would be proposed
/rethink "technical" --dry-run

# View past rethink proposals
/rethink --history

# Set custom threshold
/rethink "tool-use" --threshold 3
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<category>` | positional | — | Category to synthesize (from `/remember` categories) |
| `--all` | flag | false | Process all categories that meet threshold |
| `--force` | flag | false | Override confidence threshold |
| `--threshold` | int | 5 | Minimum observations required |
| `--dry-run` | flag | false | Show proposals without creating approval requests |
| `--history` | flag | false | View past rethink proposals and their status |
| `--depth` | enum | `standard` | `quick` (pattern summary), `standard` (proposals), `deep` (proposals + impact analysis) |

## Workflow

### 5-Phase Process

1. **Triage** — Load all observations in the target category. Filter by confidence (>= 0.3). Sort by severity and frequency. Discard noise (low confidence + single occurrence).
2. **Pattern detection** — Cluster related observations. Identify:
   - Recurring themes (same mistake, different contexts)
   - Escalating severity (problem getting worse)
   - Root causes (multiple symptoms, one cause)
   - Contradictions (observations that conflict — flag for human resolution)
3. **Methodology update** — For each detected pattern, determine what system artifact should change:
   - CLAUDE.md rules
   - Agent system prompts
   - Workflow definitions
   - Skill parameters
   - Routing tables
   - Quality thresholds
4. **Proposal generation** — For each proposed change:
   - Write a specific, actionable proposal
   - Include: what changes, why (evidence from observations), expected impact, risk level
   - Show the exact diff (before/after) when possible
   - Estimate effort: trivial (config change), moderate (workflow change), significant (architecture change)
5. **Human approval** — Submit proposals via `/approve` as `strategy_proposal` type. Block until resolved. On approval, provide implementation instructions (but do not auto-implement).

## Output

```markdown
## Rethink Report — Category: process

**Observations analyzed:** 7
**Patterns detected:** 3
**Proposals generated:** 2

### Pattern 1: Duplicate Content Creation
**Evidence:** 4 observations (confidence: 0.72)
- obs-a1b2: "Always check for duplicates before inserting"
- obs-c3d4: "Created duplicate signal file for Ed's call"
- obs-e5f6: "Knowledge base has 3 versions of pricing decision"
- obs-g7h8: "Ingestion created duplicate when slightly different wording"

**Root cause:** No deduplication check in the ingestion pipeline.

**Proposal 1:** Add dedup check to /seed skill
- **Change:** Add content hash comparison in seed workflow step 5
- **Diff:**
  ```
  Before: 5. Write — Create inbox item
  After:  5. Dedup — Hash content, check against existing seeds. If >85% similarity, warn and link instead of creating new.
          6. Write — Create inbox item
  ```
- **Impact:** Prevents ~60% of duplicate content (based on observation frequency)
- **Risk:** Low — additive change, no existing behavior modified
- **Effort:** Moderate — requires hash index

→ Submitted as approval req-x1y2. Awaiting human decision.

### Pattern 2: Missing Cross-References
**Evidence:** 3 observations (confidence: 0.58)
...

### Archived Observations
The following observations were consumed by this rethink and archived:
- obs-a1b2, obs-c3d4, obs-e5f6, obs-g7h8 → archived to ops/observations/process/archived/
```

## Dependencies

- `/remember` — Source of observations
- `/approve` — Proposal approval gate
- Observation store (`ops/observations/`)
- System configuration files (for generating diffs)
- `/health` — For impact analysis at `deep` depth
