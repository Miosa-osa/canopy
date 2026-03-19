# Inter-Agent Handoff Protocol

> Standard for all agent-to-agent task delegation. Enterprise edition includes
> budget tracking and approval gate references.

## Handoff Format

```markdown
## Task Handoff

**From**: [agent id]
**To**: [agent id]
**Priority**: [P0|P1|P2|P3]
**Deadline**: [date or "none"]
**Estimated Cost**: $[amount]
**Approval Gate**: [gate id or "none"]

### What I Need
[Specific deliverable description]

### Constraints
- [Hard constraint]

### Context
- See: [reference file links]

### Expected Output
- **Genre**: [genre]
- **Length**: [target]
- **Reviews Required**: [who needs to review before delivery]

### When You're Done
Return to [sender]. Flag risks. Include self-review checklist.
```

## Rules

1. Budget estimate required on every handoff.
2. If estimated cost triggers a gate, note the gate ID.
3. Receiving agent asks ONE clarification maximum.
4. Security-impacting tasks MUST note "Security Review Required."
5. Cross-team handoffs go through team leads, not direct to executors.
