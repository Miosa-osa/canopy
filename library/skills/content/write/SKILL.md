---
name: write
description: "Generate content in the correct genre for a target receiver using the Signal Theory framework. Resolves all 5 signal dimensions (Mode, Genre, Type, Format, Structure), applies the matching genre skeleton, and adapts to the receiver's decoding capacity. Supports genres: brief, spec, plan, transcript, note, pitch, proposal, report, email, social-post, outline, changelog, ADR. Use when producing any structured written content for a specific audience."
user-invocable: true
triggers:
  - write
  - write content
  - draft
  - generate content
  - write brief
  - write spec
  - write email
  - write report
---

# /write

> Generate content in the correct genre for the target receiver.

## Usage

```bash
/write <genre> --for <person> [--topic "<topic>"] [--tone <tone>]
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `<genre>` | enum | required | Content genre (brief, spec, plan, pitch, email, etc.) |
| `--for` | string | required | Target receiver (role or name from people registry) |
| `--topic` | string | — | Subject matter for the content |
| `--tone` | string | `professional` | Tone override: `formal`, `casual`, `technical`, `persuasive` |

## Workflow

1. **Resolve receiver** — look up person in people registry (CLAUDE.md or 10-team/context.md). If not found, ask the user for the receiver's role and communication preferences.
2. **Select genre** — use the specified genre or infer from receiver preference.
3. **Load genre skeleton** — apply the structured template for the genre:
   - **brief**: TL;DR → Key Points → Action Required (executive summary)
   - **spec**: Overview → Requirements → Constraints → Interface → Edge Cases (technical)
   - **plan**: Goal → Phases → Timeline → Risks → Success Criteria (strategic)
   - **pitch**: Hook → Problem → Solution → Proof → Ask (persuasive)
   - **email**: Subject → Context → Ask → Next Steps (direct)
   - **report**: Summary → Data → Analysis → Recommendations (analytical)
   - **ADR**: Status → Context → Decision → Consequences (architectural)
   - Other genres (note, transcript, proposal, social-post, outline, changelog): follow standard structure for the format.
4. **Assemble context** — run `/assemble` to gather relevant topic context if needed.
5. **Generate** — produce content matching genre structure, receiver bandwidth, and tone.
6. **Validate** — check output against the 6 encoding principles:
   1. **Mode-message alignment** — written content reads well; verbal content speaks well
   2. **Entropy preservation** — no critical information lost in compression
   3. **Receiver bandwidth match** — complexity fits the receiver's expertise level
   4. **Genre convention** — output follows the skeleton structure for the chosen genre
   5. **Signal-to-noise ratio** — every sentence earns its place; no filler
   6. **Actionability** — receiver knows exactly what to do after reading
   If validation fails on any principle, revise the output before delivering.

## Examples

```bash
# Write a brief for a salesperson
/write brief --for "sales rep" --topic "Q2 pricing update"

# Write a spec for a developer (with explicit constraints)
/write spec --for "lead developer" --topic "authentication flow"

# Write a pitch for a client
/write pitch --for "prospect" --topic "platform demo"
```

## Output

```markdown
## Brief: Q2 Pricing Update

**For**: Sales team
**Genre**: Brief (executive summary format)
**Signal dimensions**: Written → Brief → Informational → Bullet → Top-down

### Key Changes
- Enterprise tier increases 12% effective July 1
- Existing contracts honored through renewal date
- New "Startup" tier at $49/mo replaces free trial

### Talking Points
1. Frame as investment in reliability and support SLA
2. Grandfather existing customers — emphasize loyalty value
3. Startup tier opens new pipeline segment

### Action Required
Update pricing decks by June 15. Notify active prospects before announcement.
```
