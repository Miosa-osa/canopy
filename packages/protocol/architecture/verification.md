# Verification — Self-Validating Workspaces

> Workspaces declare their own invariants. Verification runs check those
> invariants against real state and surface drift before it compounds.
> Four strength levels (smoke, standard, deep, adversarial), spec contracts
> as the ground truth, and ADR-linked decisions that expire when their
> assumptions change.

---

## Overview

Systems drift. A spec written at project start diverges from reality as
implementation evolves, decisions accumulate, and context shifts. Verification
is the mechanism that detects this drift systematically — not through manual
audit, but through executable contracts that the workspace itself enforces.

Every workspace can declare a verification contract: a set of invariants that
must hold for the workspace to be considered in a valid state. Verification
runs evaluate those contracts against real state (files, task graph, agent
configs, decision graph confidence) and produce a structured findings report.

The design principle: **verification is a feedback loop, not a checkpoint**.
It does not block work — it continuously monitors and surfaces signals so
agents can self-correct rather than waiting for a human-triggered review.

---

## Spec Contracts

A spec contract is a formal declaration of workspace invariants. Contracts
live in the workspace as a `VERIFICATION.md` file in the spec layer.

### Contract Schema

```yaml
verification:
  workspace_id: "eng-team-auth"
  version: "1.0"
  description: "Auth service workspace invariants"

  invariants:
    - id: "INV-001"
      description: "All API endpoints must have corresponding test coverage"
      check: "test_coverage >= 0.80 for all files in lib/api/"
      severity: critical
      owner: "backend-lead"

    - id: "INV-002"
      description: "No hardcoded secrets in source files"
      check: "no_secrets_pattern in src/**"
      severity: critical
      owner: "security-auditor"

    - id: "INV-003"
      description: "All decision graph decisions have confidence >= 0.60"
      check: "decision_graph.active_decisions.all? {|d| d.confidence >= 0.60}"
      severity: high
      owner: "architect"

    - id: "INV-004"
      description: "Session compaction running within budget"
      check: "sessions.token_usage < sessions.budget * 0.90"
      severity: medium
      owner: "platform"
```

### Invariant Severity Levels

| Severity | Description | Verification Failure Action |
|----------|-------------|---------------------------|
| `critical` | System integrity at risk if violated | Block promotion, escalate immediately |
| `high` | Work quality significantly degraded | Flag to team leader, require acknowledgment |
| `medium` | Drift present but work can continue | Surface in next pulse report |
| `low` | Advisory — good hygiene, not blocking | Log only |

---

## Verification Strength Levels

Four levels of verification depth. Higher levels run more checks at greater
token cost. Agents select the level appropriate to context.

### Level 1 — Smoke

The cheapest verification pass. Checks only the most critical structural
invariants. Used as a lightweight pre-flight before major operations.

```
Checks performed:
  - Critical invariants only (severity: critical)
  - File existence checks (required files present)
  - Schema validation (task, agent, session files parse correctly)
  - No orphaned tasks (tasks with missing dependencies)

Token cost: ~500–1,000 tokens
Duration: < 5 seconds
Trigger: before major task handoffs, before deployments
```

### Level 2 — Standard

The default verification run. Checks all invariants above `low` severity,
runs cross-reference validation, and evaluates decision graph health.

```
Checks performed:
  - All Level 1 checks
  - High and medium invariants
  - Cross-reference integrity (context keeper entries reference valid tasks)
  - Decision graph pulse: confidence distribution, goals without decisions
  - Session budget utilization
  - Peer protocol: unacknowledged handoffs older than 24 hours

Token cost: ~2,000–5,000 tokens
Duration: 10–30 seconds
Trigger: end of sprint, before milestone completion, weekly scheduled
```

### Level 3 — Deep

Comprehensive verification. Includes semantic analysis of spec drift —
comparing what the spec says should be true against what the codebase
and decision history show is true.

```
Checks performed:
  - All Level 2 checks
  - Spec drift analysis: compare PROCEDURES.md bindings against actual implementations
  - ADR currency check: decisions linked to assumptions that have changed
  - Memory coherence: semantic facts that contradict active decision graph nodes
  - Dependency audit: external dependencies against known vulnerability list
  - Capability audit: agent capability declarations vs. tasks attempted

Token cost: ~10,000–25,000 tokens
Duration: 1–5 minutes
Trigger: before major architecture changes, quarterly review, post-incident
```

### Level 4 — Adversarial

Full adversarial analysis. Spawns a dedicated verification agent that
attempts to find invariant violations through active probing — not just
passive checking.

```
Checks performed:
  - All Level 3 checks
  - Active invariant stress-testing (attempt to trigger edge cases)
  - Decision graph adversarial probe: find paths where confidence cascade
    could be manipulated to produce invalid decisions
  - Governance bypass probe: check for escalation chain gaps
  - Self-healing coverage: identify error categories with no healing path

Token cost: ~50,000–100,000 tokens
Duration: 15–60 minutes
Trigger: before system-wide rollouts, security incidents, compliance review
```

---

## Drift Detection

Drift is the gap between declared invariants and observed state. Verification
surfaces drift before it reaches a severity threshold that blocks work.

### Drift Scoring

```
drift_score(workspace) = weighted sum of invariant violation scores

Per invariant:
  passing    → 0
  warning    → 0.25 × severity_weight
  failing    → 1.0 × severity_weight

severity_weight:
  critical → 4
  high     → 2
  medium   → 1
  low      → 0.25

workspace drift_score: 0.0 (clean) → ∞ (severe violations)

Thresholds:
  0.0–2.0  → GREEN  (workspace healthy)
  2.0–5.0  → YELLOW (drift present, monitor)
  5.0–10.0 → ORANGE (intervention recommended)
  > 10.0   → RED    (work should pause for remediation)
```

### Drift Report Format

```markdown
## Verification Report — {workspace_id}
**Level**: {smoke | standard | deep | adversarial}
**Run at**: {timestamp}
**Overall**: GREEN | YELLOW | ORANGE | RED (drift_score: {score})

### Violations

#### CRITICAL
- **INV-002** [security-auditor] No hardcoded secrets
  Status: FAILING
  Evidence: `lib/auth/config.ex:45` contains pattern matching `/secret.*=.*["\'][^"\']+["\']`
  Recommended action: Extract to environment variable or Vault reference

#### HIGH
- **INV-003** [architect] Decision graph confidence >= 0.60
  Status: WARNING
  Evidence: 2 of 14 active decisions below threshold
    - decision-id: "dec-auth-algo" — confidence: 0.52
    - decision-id: "dec-session-storage" — confidence: 0.48
  Recommended action: Review and update or escalate for team re-confirmation

### Passing (12 of 14 invariants)
- INV-001: Test coverage ✓ (84%)
- INV-004: Session budget ✓ (72% utilized)
- [10 more...]
```

---

## ADR-Linked Decisions

Architecture Decision Records (ADRs) can declare their governing assumptions
as verifiable invariants. When those assumptions change, the ADR is flagged
as requiring review.

### ADR Assumption Declaration

```markdown
# ADR-007: Use RS256 for JWT signing

## Status: Accepted
## Date: 2026-01-15

## Context
JWT tokens need asymmetric signing to support multi-service verification.

## Assumptions
These assumptions must hold for this ADR to remain valid:

| Assumption | Invariant ID | Check |
|-----------|-------------|-------|
| Key rotation tooling is available | INV-ADR-007-1 | vault.key_rotation_enabled? |
| Team has RS256 operational experience | INV-ADR-007-2 | team.capabilities includes "rs256_ops" |
| No services require symmetric signing | INV-ADR-007-3 | services.all? { no_hs256_requirement? } |

## Expiry Condition
If any assumption above is violated, this ADR must be re-evaluated.
```

### ADR Currency Verification

During Level 3 (deep) verification, the system checks all ADRs with declared
assumptions against current state:

```
For each ADR with declared assumptions:
  For each assumption:
    evaluate check_fn against current state
    │
    ├── passes → assumption holds, ADR current
    │
    └── fails → assumption violated
          → flag ADR as "requires review"
          → create observation node in decision graph:
            {content: "ADR-{n} assumption '{name}' no longer holds",
             source: "verification",
             confidence: 1.0}
          → confidence cascade propagates to downstream decisions
```

---

## Verification Loops

Verification is not a one-time gate — it is a recurring feedback loop
integrated into the agent execution cycle.

### Loop Integration Points

| Integration Point | Trigger | Level |
|------------------|---------|-------|
| Pre-handoff | Before peer handoff is sent | Smoke |
| Pre-milestone | Before task marked complete as milestone | Standard |
| Scheduled | Weekly or configurable interval | Standard |
| Post-incident | After self-healing episode completes | Deep |
| Pre-architecture-change | When ADR status changes to Accepted | Deep |
| Compliance review | Quarterly or on-demand | Adversarial |

### Verification as Self-Healing Input

When a verification run finds critical violations, it feeds directly into
the self-healing subsystem:

```
Verification run: CRITICAL violation found (INV-002: hardcoded secrets)
  │
  ▼
Create SelfHealing.Episode:
  error_category: ERR_CONFIG
  error_severity: SEV_HIGH
  error_message: "Verification: INV-002 failing — hardcoded secret detected at lib/auth/config.ex:45"
  │
  ▼
Standard healing lifecycle proceeds (diagnose → fix → verify)
  │
  ▼
Healing agent applies fix (extracts secret to env var)
  │
  ▼
Verification re-run (smoke level) to confirm fix
```

---

## Signal Theory Position

The Verification subsystem implements a feedback loop within **Layer 6
(The Feedback Loop)** and governance integrity within **Layer 7 (The
Governance / VSM)** of the Optimal System.

```
OS Layer 6 — The Feedback Loop
  ↕
Verification — contractual feedback that detects drift before it compounds

CIRCULAR CAUSALITY: Spec contracts define the expected state. Verification
  runs observe actual state. The drift score is the difference signal.
  Healing episodes close the loop by restoring actual state to expected state.
  This is Wiener's feedback closure applied to workspace integrity.

OS Layer 7 — The Governance (VSM) — S3/S4
  ↕
Verification — S4 intelligence (scanning the environment for drift) feeding
  S3 control (triggering corrections via self-healing or escalation).

ADR CURRENCY: ADR-linked verification ensures that the Policy layer (S5)
  decisions remain consistent with operational reality (S1). When S1 state
  changes in a way that invalidates an S5 decision, the ADR currency check
  surfaces the inconsistency — a Beer S5/S1 coherence check.
```

### Governing Principle: Wiener — Feedback Closure

A workspace without verification contracts is broadcasting without confirmation.
Work happens, state changes, but there is no mechanism to detect when the system
has drifted outside its intended operating envelope. Verification closes that loop:
it provides the feedback signal that tells the system whether its outputs are still
coherent with its declared intentions.

### Governing Principle: Beer — Viable Structure

Drift accumulation is a viability threat. A workspace where 40% of invariants
are quietly failing is not viable — it has structural incoherence that will
eventually surface as catastrophic failures. Verification implements S4
(Intelligence) by continuously scanning for drift signals and S3 (Control)
by triggering corrections before the drift crosses viability thresholds.

---

## See Also

- [self-healing.md](self-healing.md) — Verification critical violations trigger healing episodes; healing agents re-run smoke verification to confirm fixes
- [decision-graph.md](decision-graph.md) — ADR assumption failures create observation nodes that propagate via confidence cascade to downstream decisions
- [heartbeat.md](heartbeat.md) — Verification loops run as part of the standard heartbeat cycle at configured intervals
- [governance.md](governance.md) — RED workspace status (drift_score > 10) escalates to governance chain
- [spec-layer.md](spec-layer.md) — PROCEDURES.md and WORKFLOW.md spec bindings are validated during Level 3 deep verification
- [context-mesh.md](context-mesh.md) — Context keeper cross-reference integrity is checked during standard verification
- [optimal-system-mapping.md](optimal-system-mapping.md) — Full 7-layer OS mapping

---

*Verification v1.0 — Self-validating workspaces with spec contracts, drift detection, four strength levels, and ADR currency checks*
