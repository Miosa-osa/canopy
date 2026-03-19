# Feature Cycle Workflow

> 7-phase pipeline from specification through monitored production deployment.

## Overview

```
Spec -> Design -> Build -> Test -> Review -> Deploy -> Monitor
```

Each phase has an owner, evidence gate, and handoff protocol. Nothing advances
without passing the gate.

---

## Phases

### Phase 1: Spec

- **Owner**: tech-lead
- **Goal**: Define what to build, why, and acceptance criteria
- **Evidence gate**: Requirements clear, acceptance criteria defined, estimated
- **Signal threshold**: 0.7
- **Agents activated**:
  - Wave 1: tech-lead (requirements, constraints, acceptance criteria)
- **Max duration**: 2 days
- **On failure**: Clarify requirements with requestor
- **Handoff**: standard (tech-lead -> architect with approved spec)

### Phase 2: Design

- **Owner**: architect
- **Goal**: Design system integration, API contracts, data model
- **Evidence gate**: Architecture approved by tech-lead, API contracts locked
- **Signal threshold**: 0.7
- **Agents activated**:
  - Wave 1: architect (system design, API contracts, data model)
  - Wave 2: tech-lead (design review and approval)
- **Max duration**: 3 days
- **On failure**: Revise design based on tech-lead feedback
- **Handoff**: standard (architect -> frontend-dev + backend-dev with design doc)

### Phase 3: Build

- **Owner**: frontend-dev + backend-dev
- **Goal**: Implement the feature per spec and design
- **Evidence gate**: Implementation complete, unit tests pass, coverage maintained
- **Signal threshold**: 0.6
- **Agents activated**:
  - Wave 1: frontend-dev (UI), backend-dev (API + logic) -- parallel
- **Max duration**: 5 days
- **On failure**: Escalate to tech-lead if blocked > 4 hours
- **Handoff**: qa-pass or qa-fail (devs -> qa-engineer with PR)

### Phase 4: Test

- **Owner**: qa-engineer
- **Goal**: Verify correctness, find bugs, ensure quality gate passes
- **Evidence gate**: All tests pass, coverage >= 80%, QA approval
- **Signal threshold**: 0.8
- **Agents activated**:
  - Wave 1: qa-engineer (test execution, manual verification, regression sweep)
- **Max duration**: 2 days
- **Max retries**: 3 (dev-QA loop)
- **On failure**: Return to Build with QA failure handoff (qa-fail)
- **Handoff**: qa-pass (qa-engineer -> tech-lead for final review)

### Phase 5: Review

- **Owner**: tech-lead
- **Goal**: Final code review -- correctness, security, maintainability
- **Evidence gate**: Code review approved, no blockers
- **Signal threshold**: 0.8
- **Agents activated**:
  - Wave 1: tech-lead (code review, architecture compliance check)
- **Max duration**: 1 day
- **On failure**: Return to Build with review feedback
- **Handoff**: standard (tech-lead -> devops for deployment)

### Phase 6: Deploy

- **Owner**: devops
- **Goal**: Deploy to staging, verify, deploy to production
- **Evidence gate**: Deployment successful, health checks pass, error rates normal
- **Signal threshold**: 0.9
- **Agents activated**:
  - Wave 1: devops (deployment execution, monitoring)
- **Max duration**: 1 day
- **On failure**: Auto-rollback, escalate to tech-lead
- **Handoff**: standard (devops confirms deployment, enters monitor phase)

### Phase 7: Monitor

- **Owner**: devops
- **Goal**: Confirm 24-hour stability, no error spikes, no performance degradation
- **Evidence gate**: 24h stability confirmed, metrics within baseline
- **Signal threshold**: 0.9
- **Agents activated**:
  - Wave 1: devops (post-deploy monitoring)
- **Max duration**: 24 hours
- **On failure**: Rollback + incident report
- **Handoff**: Feature complete. Close task.

---

## Dev-QA Loop

```
Build phase produces PR
  -> QA reviews
     -> PASS: advance to Review (handoffs/qa-pass.md)
     -> FAIL: return to Build (handoffs/qa-fail.md), retry_count++
     -> retry_count > 3: escalate to tech-lead
```

## Handoff Definitions

| Handoff Type | Template | When Used |
|-------------|----------|-----------|
| standard | handoffs/standard.md | Phase transitions (non-QA) |
| qa-pass | handoffs/qa-pass.md | QA approves |
| qa-fail | handoffs/qa-fail.md | QA rejects with fix instructions |
