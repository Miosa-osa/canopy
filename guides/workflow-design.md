# Workflow Design Guide

> How to design multi-phase pipelines that coordinate agents through structured work.

---

## What Is a Workflow?

A workflow is a pipeline of phases that transforms input into output through
coordinated agent work. Each phase has an owner, an evidence gate, a signal
quality threshold, and a handoff protocol.

Workflows live in the `workflows/` directory:

```
workflows/
├── feature-cycle.md     <- Spec > Design > Build > Test > Review > Deploy > Monitor
├── bug-fix.md           <- Report > Reproduce > Fix > Test > Deploy
└── deal-cycle.md        <- Research > Outreach > Discovery > Demo > Proposal > Negotiate > Close
```

---

## The NEXUS 7-Phase Framework

NEXUS is the reference framework for structuring multi-agent work. It defines
7 phases that any project can use, adapt, or subset.

```
Phase 0: Discovery       -- Understand the problem space
Phase 1: Strategy         -- Decide approach and architecture
Phase 2: Foundation       -- Scaffold structure and contracts
Phase 3: Build            -- Implement features
Phase 4: Hardening        -- Test, review, secure
Phase 5: Launch           -- Deploy and activate
Phase 6: Operate          -- Monitor, iterate, evolve
```

Not every workflow uses all 7 phases. A bug fix might use phases 3-5 only.
A sales cycle maps different activities to each phase.

### Phase Anatomy

Every phase definition follows this structure:

```markdown
### Phase N: {Name}

- **Owner**: {agent-id}
- **Goal**: What this phase achieves
- **Evidence gate**: What proof is required to advance
- **Signal threshold**: Minimum S/N score (0.0-1.0)
- **Agents activated**:
  - Wave 1: {agent} ({what they do})
  - Wave 2: {agent} ({what they do})
- **Max duration**: Time limit
- **Max retries**: How many attempts before escalation (optional)
- **On failure**: What happens when the gate is not met
- **Handoff**: Template used to transition to next phase
```

### Understanding Evidence Gates

Evidence gates prevent bad work from advancing. Every phase transition requires proof.

| Gate Type | What It Checks | Example |
|-----------|---------------|---------|
| `review_approved` | A reviewing agent has approved the output | Architecture sign-off |
| `tests_pass` | Automated tests pass with required coverage | 80%+ test coverage |
| `signal_score` | Output S/N ratio meets threshold | Report scores 0.7+ |
| `human_approval` | Board or human stakeholder approves | Budget increase over 20% |
| `budget_check` | Cost remains within budget constraints | Monthly spend under ceiling |

### Signal Thresholds

Each phase has a signal quality threshold. Output below this threshold is rejected
and returned to the producing agent with a structured rejection notice.

```
Phase     Typical Threshold    Why
Research       0.7             Need reliable information
Build          0.6             Work in progress, iterate fast
Test           0.8             Quality verification demands precision
Deploy         0.9             Production changes require high confidence
```

Lower thresholds allow faster iteration. Higher thresholds enforce quality.
Set thresholds based on the cost of advancing bad work.

---

## Designing Phase Gates

### Gate Design Principles

**1. Gates must be verifiable.** "Code is good" is not a gate. "All tests pass
and coverage >= 80%" is a gate.

**2. Gates should be automatic where possible.** Prefer `tests_pass` over
`human_approval`. Reserve human gates for high-stakes decisions.

**3. Failed gates should produce actionable feedback.** When an evidence gate
rejects work, the rejection notice must say what specifically failed and
what the agent needs to fix.

**4. Gates should not be byppassable.** If a gate can be skipped, it provides
no value. The only exception is board override.

### Gate Examples

```markdown
# Feature Cycle Gates

Phase 1 (Spec):
  Gate: Requirements clear, acceptance criteria defined, estimated
  Verifier: tech-lead reviews spec document

Phase 3 (Build):
  Gate: Implementation complete, unit tests pass, coverage maintained
  Verifier: automated test suite + coverage tool

Phase 4 (Test):
  Gate: All tests pass, coverage >= 80%, QA approval
  Verifier: qa-engineer runs full test suite + manual verification

Phase 6 (Deploy):
  Gate: Deployment successful, health checks pass, error rates normal
  Verifier: automated health check script
```

---

## Handoff Patterns Between Agents

A handoff is how work transitions from one agent to another. Every phase transition
uses a structured handoff template from `handoffs/`.

### Standard Handoff

Used for normal phase transitions:

```markdown
# Handoff: {from_agent} -> {to_agent}

## Phase Transition
{Previous Phase} -> {Next Phase}

## Context Summary
{What was done, key decisions made, current state}

## Deliverables Passed
- {Document or artifact 1}
- {Document or artifact 2}

## Evidence
- {Gate evidence: test results, approval, score}

## Open Items
- {Anything unresolved that the receiving agent should know}

## Expected Next Action
{What the receiving agent should do first}
```

### Rejection Handoff

Used when a quality gate fails and work returns to a previous phase:

```markdown
# Rejection: {from_agent} -> {to_agent}

## Failed Gate
{Which evidence gate failed and why}

## Issues Found
1. {Specific issue with location and severity}
2. {Specific issue with location and severity}

## Retry Count
{N} of {max_retries}

## Required Fixes
- {What must change before resubmission}
```

### Escalation Handoff

Used when normal handoffs are insufficient:

```markdown
# Escalation: {from_agent} -> {manager_agent}

## Trigger
{Why this was escalated -- blocked, stalled, conflict, budget}

## Context
{Full situation summary}

## Options Considered
1. {Option A with pros/cons}
2. {Option B with pros/cons}

## Recommended Action
{What the escalating agent thinks should happen}
```

---

## Sprint Planning with Agents

Workflows can be organized into sprints -- time-boxed execution cycles.

### Sprint Structure

```
Sprint Planning (Day 1, 1 hour)
  - tech-lead reviews backlog
  - tech-lead selects items for sprint
  - Items assigned to agents

Sprint Execution (Days 1-10)
  - Agents work through assigned tasks
  - Daily status checks via /status skill
  - Blocked items escalated immediately

Sprint Review (Day 10)
  - tech-lead reviews completed work
  - Metrics collected: velocity, quality, budget spend
  - Retrospective: what worked, what didn't
```

### Sprint Workflow Template

```markdown
### Phase: Sprint Planning

- **Owner**: tech-lead
- **Goal**: Select and assign work for the sprint
- **Evidence gate**: Sprint backlog approved, all items assigned
- **Signal threshold**: 0.6
- **Agents activated**:
  - Wave 1: tech-lead (backlog review, prioritization, assignment)
- **Max duration**: 1 day
- **On failure**: Escalate to board -- sprint cannot start without plan

### Phase: Sprint Execution

- **Owner**: assigned agents per task
- **Goal**: Complete all sprint items
- **Evidence gate**: All assigned tasks completed or explicitly deferred
- **Signal threshold**: 0.6
- **Agents activated**:
  - Wave 1: all assigned agents (parallel execution on their tasks)
- **Max duration**: 10 days
- **On failure**: Unfinished items return to backlog with context handoff

### Phase: Sprint Review

- **Owner**: tech-lead
- **Goal**: Verify completed work, collect metrics, retrospective
- **Evidence gate**: Review complete, metrics logged
- **Signal threshold**: 0.7
- **Agents activated**:
  - Wave 1: tech-lead (review, metrics, retrospective)
- **Max duration**: 1 day
- **On failure**: N/A -- review always completes
```

---

## Incident Response Workflows

When something breaks, you need a different workflow -- fast, focused, and escalation-heavy.

```markdown
# Incident Response Workflow

## Overview
```
Detect -> Triage -> Mitigate -> Fix -> Verify -> Postmortem
```

### Phase 1: Detect

- **Owner**: health-monitor (proactive agent)
- **Goal**: Identify the incident and alert the team
- **Evidence gate**: Incident confirmed (not a false positive)
- **Signal threshold**: 0.9
- **Max duration**: 5 minutes
- **On failure**: Auto-escalate to board if detection confidence < 0.9

### Phase 2: Triage

- **Owner**: tech-lead
- **Goal**: Assess severity, identify affected systems, assign responders
- **Evidence gate**: Severity assigned, responders identified
- **Signal threshold**: 0.8
- **Max duration**: 15 minutes
- **On failure**: Auto-escalate -- P0 assumed if triage takes > 15 minutes

### Phase 3: Mitigate

- **Owner**: devops + backend-dev
- **Goal**: Stop the bleeding -- rollback, feature flag, traffic reroute
- **Evidence gate**: Impact reduced or contained
- **Signal threshold**: 0.7
- **Max duration**: 1 hour
- **On failure**: Escalate to board for manual intervention

### Phase 4: Fix

- **Owner**: backend-dev or frontend-dev
- **Goal**: Implement permanent fix
- **Evidence gate**: Fix implemented, tests pass
- **Signal threshold**: 0.8
- **Max duration**: 4 hours
- **On failure**: Ship mitigation as temporary fix, schedule permanent fix

### Phase 5: Verify

- **Owner**: qa-engineer + devops
- **Goal**: Confirm fix works, no regressions, monitoring clear
- **Evidence gate**: All health checks pass for 1 hour post-deploy
- **Signal threshold**: 0.9
- **Max duration**: 2 hours
- **On failure**: Rollback, return to Mitigate phase

### Phase 6: Postmortem

- **Owner**: tech-lead
- **Goal**: Document what happened, why, and how to prevent it
- **Evidence gate**: Postmortem document approved, action items assigned
- **Signal threshold**: 0.7
- **Max duration**: 2 days
- **On failure**: N/A -- postmortem always completes
```

---

## Example Workflows

### Dev Workflow: Feature Cycle

```
Spec -> Design -> Build -> Test -> Review -> Deploy -> Monitor
```

7 phases, 6 agents, 2 handoff types (standard + qa-fail loop).
See `operations/dev-shop/workflows/feature-cycle.md` for the complete definition.

Key design decisions:
- Build phase has the lowest signal threshold (0.6) -- iterate fast
- Test and Review have high thresholds (0.8) -- catch issues before deploy
- Deploy and Monitor require 0.9 -- production changes need confidence
- Dev-QA loop allows 3 retries before escalation

### Content Workflow: Editorial Pipeline

```
Ideation -> Research -> Draft -> Edit -> Optimize -> Publish -> Analyze
```

7 phases, 4 agents (editor-in-chief, writer, seo-specialist, social-media).
See `operations/content-factory/` for the full operation.

Key design decisions:
- Research phase loads reference/keywords.md and reference/topics.md
- Edit phase has the highest signal threshold -- brand voice must be perfect
- Publish phase activates social-media agent for multi-platform distribution
- Analyze phase feeds metrics back into ideation (learning loop)

### Sales Workflow: Deal Cycle

```
Research -> Outreach -> Discovery -> Demo -> Proposal -> Negotiate -> Close
```

7 phases, 5 agents (director, prospector, closer, researcher, copywriter).
See `operations/sales-engine/workflows/deal-cycle.md` for the complete definition.

Key design decisions:
- Deals can retreat (move backward) at any phase
- Stalled deal protocol triggers at 7, 14, 21, and 30 days
- Signal threshold increases as deals approach close (0.7 -> 0.9)
- Director involvement increases in later phases (governance)

---

## Workflow Design Checklist

Before deploying a workflow:

- [ ] Every phase has an owner, goal, evidence gate, and signal threshold
- [ ] Evidence gates are verifiable (not subjective)
- [ ] Handoff templates exist for every phase transition
- [ ] Failure paths are defined for every phase (on failure)
- [ ] Retreat patterns are explicit (when can work move backward?)
- [ ] Max duration is set for every phase (prevents infinite loops)
- [ ] Max retries are set for phases with feedback loops
- [ ] Escalation paths are defined (when normal resolution fails)
- [ ] Agent activation specifies waves (parallel vs sequential)
- [ ] Signal thresholds increase as work approaches production/delivery
- [ ] The workflow references agents that exist in the operation's agents/ directory

---

## Common Mistakes

### 1. No Failure Paths

Every phase needs an "On failure" definition. Without it, work gets stuck
when a gate is not met and nobody knows what to do next.

### 2. Flat Signal Thresholds

Using the same threshold for every phase (e.g., 0.7 everywhere) misses the point.
Early phases should iterate fast (lower threshold). Late phases should enforce
quality (higher threshold).

### 3. Missing Retreat Patterns

Work does not always move forward. Define when and how work can move backward.
A proposal that reveals new requirements should retreat to discovery, not stall.

### 4. Manual Gates on Automatable Checks

If a test suite can verify correctness, do not require a human to approve.
Reserve human gates for judgment calls -- strategy, budget, risk tolerance.

### 5. No Escalation Chain

Without escalation, stalled work stays stalled forever. Every workflow should
define what happens when normal resolution fails -- who gets notified, at what
time thresholds, and what powers they have.
