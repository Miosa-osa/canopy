# Deal Cycle Workflow

> 7-phase pipeline from prospect research through closed-won.

## Overview

```
Research -> Outreach -> Discovery -> Demo -> Proposal -> Negotiate -> Close
```

Each phase has an owner, evidence gate, and handoff protocol. Deals cannot
advance without passing the gate. Deals can retreat (move backward) at any time.

---

## Phases

### Phase 1: Research

- **Owner**: researcher
- **Goal**: Build company profile, score against ICP, determine if pursuit-worthy
- **Evidence gate**: ICP score >= 7/10 (for full pursuit), or 5-6 (for abbreviated)
- **Signal threshold**: 0.7
- **Agents activated**:
  - Wave 1: researcher (company research, ICP scoring)
- **Max duration**: 2 days
- **On failure**: Log as "Disqualified -- ICP below threshold"
- **Handoff**: standard (researcher -> prospector with research brief)

### Phase 2: Outreach

- **Owner**: prospector
- **Goal**: Engage the prospect through multi-touch sequence, book a meeting
- **Evidence gate**: Meeting booked with qualified contact
- **Signal threshold**: 0.6
- **Agents activated**:
  - Wave 1: prospector (sequence execution), copywriter (email drafts)
- **Max duration**: 30 days (full 21-day sequence + buffer)
- **On failure**: Move to nurture list, re-engage on trigger event
- **Handoff**: standard (prospector -> closer with meeting handoff brief)

### Phase 3: Discovery

- **Owner**: closer
- **Goal**: Uncover pain, map decision process, identify economic buyer, score MEDDPICC
- **Evidence gate**: MEDDPICC score >= 60% with Pain and Economic Buyer at Level 2+
- **Signal threshold**: 0.7
- **Agents activated**:
  - Wave 1: closer (discovery calls), researcher (supplemental research)
- **Max duration**: 14 days
- **On failure**: Retreat to Outreach (needs more nurturing) or Disqualify
- **Handoff**: standard (closer generates MEDDPICC scorecard, advances to Demo)

### Phase 4: Demo

- **Owner**: closer
- **Goal**: Demonstrate solution tailored to buyer's use cases, confirm champion
- **Evidence gate**: Champion confirmed (passes 3-test framework) + decision criteria validated
- **Signal threshold**: 0.7
- **Agents activated**:
  - Wave 1: closer (demo delivery), researcher (competitive positioning if competitor in deal)
- **Max duration**: 14 days
- **On failure**: Retreat to Discovery (gaps found), or hold (schedule follow-up demo)
- **Handoff**: standard (closer -> closer + copywriter for proposal creation)

### Phase 5: Proposal

- **Owner**: closer + copywriter
- **Goal**: Deliver proposal that maps directly to buyer's stated decision criteria
- **Evidence gate**: Proposal delivered, buyer confirms decision criteria are addressed
- **Signal threshold**: 0.8
- **Agents activated**:
  - Wave 1: copywriter (proposal draft), closer (pricing + terms)
  - Wave 2: director (pricing approval if discount involved)
- **Max duration**: 7 days
- **On failure**: Revise proposal based on feedback (max 2 revisions)
- **Handoff**: standard (proposal delivered, advance to Negotiate)

### Phase 6: Negotiate

- **Owner**: closer + director
- **Goal**: Agree on terms, navigate procurement, get to signature-ready
- **Evidence gate**: Terms agreed, legal cleared, mutual action plan complete
- **Signal threshold**: 0.9
- **Agents activated**:
  - Wave 1: closer (negotiation), director (discount approval, strategy)
- **Max duration**: 21 days
- **On failure**: Escalate to director if stalled > 7 days
- **Handoff**: standard (advance to Close with agreed terms)

### Phase 7: Close

- **Owner**: closer + director
- **Goal**: Get contract signed, transition to onboarding
- **Evidence gate**: Contract signed
- **Signal threshold**: 0.9
- **Agents activated**:
  - Wave 1: closer (final push), director (executive-to-executive if needed)
- **Max duration**: 14 days
- **On failure**: Escalate to director, then board. If > 14 days past committed close date, force go/no-go.
- **Handoff**: standard (closed-won handoff to onboarding/CS team)

---

## Handoff Definitions

| Handoff Type | Template | When Used |
|-------------|----------|-----------|
| standard | handoffs/standard.md | All phase transitions |
| escalation | handoffs/escalation.md | Stalled deals, pricing exceptions, risk situations |

## Retreat Protocol

Deals can move backward. Common retreat patterns:

| From | To | Trigger |
|------|-----|---------|
| Discovery | Outreach | Prospect not ready, needs more nurturing |
| Demo | Discovery | New stakeholder introduced, requirements changed |
| Proposal | Demo | Decision criteria changed after proposal delivered |
| Negotiate | Proposal | Terms rejected, need new proposal structure |

Every retreat resets the phase timer and requires a handoff with updated context.

## Stalled Deal Protocol

| Days Stalled | Action |
|-------------|--------|
| 7 days | Flag in pipeline review, closer documents plan to unstick |
| 14 days | Director reviews, prescribes action or forces go/no-go |
| 21 days | Director makes final call: invest or kill |
| 30 days | Auto-moved to "Stalled" status, removed from active forecast |
