---
name: remember
description: >
  Capture behavioral friction as structured observations. Three modes: explicit
  (user states a lesson), contextual (scan conversation for corrections and patterns),
  and session mining (bulk extract from transcripts). Stores observations for later
  synthesis via /rethink.
  Triggers on: "remember", "lesson learned", "note pattern", "capture friction"
---

# /remember

> Capture behavioral friction and lessons as structured observations.

## Purpose

The input side of the learning loop. When something goes wrong, when a pattern emerges, or when the user corrects behavior — capture it as a structured observation. Observations accumulate over time and feed into `/rethink` for synthesis into system improvements. Three capture modes handle different scenarios: explicit (user tells you), contextual (you detect it), and mining (bulk extraction).

## Usage

```bash
# Explicit — user states a lesson
/remember "Always check for duplicates before inserting into the knowledge base"

# Contextual — scan recent conversation for corrections
/remember --contextual

# Mine session transcripts for patterns
/remember --mine path/to/session-transcript.md

# Mine recent sessions
/remember --mine --recent 7d

# List stored observations
/remember --list

# List observations by category
/remember --list --category process

# Check which categories are ready for synthesis
/remember --escalations

# Tag an observation
/remember "Never send specs to Robert Potter" --category people --severity high
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<observation>` | positional | — | Explicit observation text |
| `--contextual` | flag | false | Scan current conversation for implicit corrections |
| `--mine` | path/flag | — | Extract observations from transcript file(s) |
| `--recent` | duration | `7d` | For `--mine`, look back this far |
| `--list` | flag | false | List stored observations |
| `--escalations` | flag | false | Show categories ready for `/rethink` |
| `--category` | string | auto | Category: `process`, `people`, `technical`, `communication`, `tool-use` |
| `--severity` | enum | `normal` | `critical`, `high`, `normal`, `low` |
| `--confidence` | float | 0.5 | Initial confidence (increases with repeated observations) |
| `--source` | string | auto | Where this observation came from |

## Workflow

### Explicit mode
1. **Parse** — Extract the core lesson from the observation text.
2. **Categorize** — Auto-classify into category (or use `--category`).
3. **Deduplicate** — Check against existing observations. If similar exists, increase its confidence instead of creating duplicate.
4. **Store** — Write to `ops/observations/{category}/{timestamp}-{slug}.json`.
5. **Check threshold** — If category now has enough observations (default: 5), flag for escalation.

### Contextual mode
1. **Scan** — Read recent conversation history.
2. **Detect** — Look for correction patterns: "No, I meant...", "That's wrong...", "Actually...", user re-doing work, explicit feedback.
3. **Extract** — For each detected correction, formulate an observation: what went wrong, what the correct behavior is.
4. **Store** — Same as explicit mode for each extracted observation.

### Mining mode
1. **Load** — Read transcript file(s) or recent session logs.
2. **Pattern match** — Identify: repeated mistakes, workflow friction, time wasters, user frustration signals, successful shortcuts.
3. **Extract** — Formulate observations from each detected pattern.
4. **Batch store** — Store all observations, deduplicating against existing.
5. **Report** — Summarize what was mined and how many observations were captured.

## Output

### Stored observation
```json
{
  "id": "obs-2026-03-20-143500-a1b2",
  "observation": "Always check for duplicates before inserting into the knowledge base",
  "category": "process",
  "severity": "normal",
  "confidence": 0.5,
  "occurrences": 1,
  "source": "explicit/user",
  "created_at": "2026-03-20T14:35:00Z",
  "updated_at": "2026-03-20T14:35:00Z"
}
```

### Escalation check
```markdown
## Observation Escalations

| Category | Count | Avg Confidence | Ready for /rethink? |
|----------|-------|---------------|---------------------|
| process | 7 | 0.68 | YES (threshold: 5) |
| people | 3 | 0.55 | no (threshold: 5) |
| technical | 12 | 0.74 | YES (threshold: 5) |
| communication | 2 | 0.40 | no (threshold: 5) |
| tool-use | 5 | 0.62 | YES (threshold: 5) |

Run `/rethink "process"` to synthesize process observations into system improvements.
```

## Dependencies

- File system for observation store (`ops/observations/`)
- Conversation history access (for `--contextual` mode)
- Session transcript access (for `--mine` mode)
- `/rethink` — Downstream consumer of accumulated observations
