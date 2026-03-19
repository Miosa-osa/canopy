# Inter-Agent Handoff Protocol

> Standard template for all agent-to-agent task delegation.

## Handoff Format

```markdown
## Task Handoff

**From**: [sending agent id]
**To**: [receiving agent id]
**Priority**: [high | normal | low]
**Deadline**: [date/time or "none"]
**Budget**: [estimated cost for this task]

### What I Need
[Clear, specific description of the deliverable]

### Constraints
- [Hard constraint 1]
- [Hard constraint 2]

### Context
[Relevant background. Link to reference files rather than duplicating content.]
- See: `reference/domain.md` for [topic]
- See: [previous deliverable] for prior work

### Expected Output
- **Genre**: [spec | report | brief | analysis | code]
- **Length**: [approximate word/line count]
- **Format**: [what the output should look like]

### When You're Done
Return to [sending agent]. Flag risks or open questions.
```

## Rules

1. Every handoff MUST include "What I Need" and "Constraints".
2. Context references files, not duplicates content.
3. Expected Output specifies genre.
4. Receiving agent asks ONE clarification maximum, then executes.
5. Sending agent reviews before forwarding externally.
6. Budget must be within receiving agent's remaining monthly allocation.
