# Project Format Standard

> The standard for defining projects within an Operation. A project is a bounded,
> time-scoped workstream that groups related tasks, milestones, and resource allocations
> under a single owner. Projects live below Initiatives and above Tasks in the goal
> hierarchy.

---

## Where Projects Fit

The Operations goal hierarchy has five levels:

```
Initiative  (north star — months to years)
  └── Project  (workstream — weeks to months)     ← THIS FILE
       └── Milestone  (checkpoint — days to weeks, has evidence gate)
            └── Task  (atomic unit — hours to days, assigned to one agent)
                 └── Sub-task  (breakdown — minutes to hours)
```

`company.yaml` defines Initiatives. Projects can be declared inline in
`company.yaml` under `goals.initiatives[].projects`, or as standalone
`PROJECT.md` files in a `projects/` directory for complex workstreams that
need their own goals, risk registers, and resource allocations.

For simple operations, inline declaration in `company.yaml` is sufficient.
For operations with 5+ active projects or projects that need detailed specs,
use standalone `PROJECT.md` files.

---

## File Convention

Standalone project files live in `projects/{project-id}/PROJECT.md`:

```
{operation-root}/
├── company.yaml
├── agents/
├── teams/
└── projects/
    ├── q2-launch/
    │   └── PROJECT.md
    └── infra-migration/
        └── PROJECT.md
```

---

## Frontmatter Schema

```yaml
---
name: string                    # Display name ("Q2 Platform Launch")
id: string                      # Unique slug ("q2-launch")
owner: string                   # Agent id accountable for delivery
team: string                    # Team id that owns this project
status: string                  # planned | active | completed | paused
budget: number                  # USD allocated for this project
milestones:
  - id: string                  # Milestone identifier (e.g., "mvp")
    name: string                # Display name ("MVP Complete")
    target: ISO8601             # Target completion date (YYYY-MM-DD)
    evidence_gate: string       # What must be true to mark this milestone done
dependencies:
  - id: string                  # Project id of a prerequisite project
    type: string                # blocks | informs | parallels
---
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Human-readable project name |
| `id` | string | yes | URL-safe identifier; must be unique across the operation |
| `owner` | string | yes | Agent id who is accountable for delivery |
| `team` | string | yes | Team id that owns this project (from `teams/`) |
| `status` | string | yes | Current project lifecycle state (see below) |
| `budget` | number | yes | USD budget allocated from the operation or team ceiling |
| `milestones` | list | no | Checkpoints with dates and evidence gates |
| `dependencies` | list | no | Other projects this one depends on |

### Status Values

| Status | Meaning |
|--------|---------|
| `planned` | Defined but not yet started. Resources not yet consumed. |
| `active` | In progress. Tasks are being executed. |
| `paused` | Work halted by decision (budget, blocker, priority shift). Requires explicit resume. |
| `completed` | All milestones satisfied. Evidence gates passed. |

Status transitions must be logged in `logs/activity.log`.

### Milestone Evidence Gates

A milestone is not complete until its evidence gate is satisfied. Evidence gate
types align with those defined in the Operations Spec:

| Gate Type | What It Checks |
|-----------|---------------|
| `tests_pass` | All tests in scope are green |
| `review_approved` | N designated reviewers approved |
| `signal_score` | S/N score >= threshold on all milestone deliverables |
| `human_approval` | Explicit human sign-off recorded in the log |
| `budget_check` | Milestone spend is within allocated budget |

Gate values can be combined using `+` for AND logic:
```yaml
evidence_gate: tests_pass+review_approved
```

### Dependency Types

| Type | Meaning |
|------|---------|
| `blocks` | This project cannot start until the dependency is `completed` |
| `informs` | This project uses outputs from the dependency but is not blocked |
| `parallels` | These projects run concurrently and share a domain boundary |

---

## Body Sections

The Markdown body MUST contain these 4 sections in order:

### 1. Goals

What this project must achieve. Write as measurable outcomes, not activities.
List 2-5 success criteria. Each criterion should be falsifiable — it should be
possible to determine whether it was met.

```markdown
# Goals

1. **[Outcome statement]** — measured by [metric or artifact]
2. **[Outcome statement]** — measured by [metric or artifact]
```

### 2. Resource Allocation

How the budget is distributed across phases or functional areas. This section
does not have to sum to the exact budget number — it is a planning guide, not
an accounting ledger. Variances are expected and should be tracked in the
activity log.

```markdown
# Resource Allocation

| Phase / Area | Allocated (USD) | Notes |
|-------------|----------------|-------|
| [Phase]     | [amount]       | [context] |
```

### 3. Risk Register

Known risks with likelihood, impact, and mitigation strategy. A risk is a
condition that, if it occurs, would threaten a milestone or the project as a whole.
Risks are not tasks — they are future uncertainties. Track them here so they can
be revisited as the project progresses.

```markdown
# Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| [Description] | low/medium/high | low/medium/high | [Mitigation action] |
```

### 4. Open Questions

Decisions that are not yet made and that the project owner or a relevant agent
needs to resolve before specific milestones can be completed. Each question
should name the blocker agent or human responsible for answering it.

```markdown
# Open Questions

- **[Question]** — Owner: [agent-id or human name], needed before: [milestone id]
```

---

## Inline Declaration in company.yaml

For simple projects, declare them directly under the parent Initiative in
`company.yaml`. This is the preferred approach for operations with fewer than
5 projects:

```yaml
goals:
  initiatives:
    - id: INI-001
      title: Launch MVP
      description: Ship v1.0 of the platform
      projects:
        - id: q2-launch
          title: Q2 Platform Launch
          owner: tech-lead
          team: engineering
          status: active
          budget: 5000
          milestones:
            - id: mvp
              name: MVP Complete
              target: 2026-04-01
              evidence_gate: tests_pass+review_approved
            - id: beta
              name: Beta Launch
              target: 2026-05-15
              evidence_gate: human_approval
```

When using inline declaration, omit the standalone `PROJECT.md` file.
The project's goals, risk register, and open questions can be added as
`description` text under the project entry, or tracked directly in the
activity log.

---

## Standalone PROJECT.md — Full Example

```yaml
---
name: Q2 Platform Launch
id: q2-launch
owner: tech-lead
team: engineering
status: active
budget: 5000
milestones:
  - id: mvp
    name: MVP Complete
    target: 2026-04-01
    evidence_gate: tests_pass+review_approved
  - id: beta
    name: Beta Launch
    target: 2026-05-15
    evidence_gate: human_approval
  - id: ga
    name: General Availability
    target: 2026-06-01
    evidence_gate: signal_score+budget_check
dependencies:
  - id: infra-migration
    type: blocks
---
```

```markdown
# Goals

1. **Auth system live and tested** — measured by: all auth tests passing, 0 open
   security findings from the code-reviewer
2. **Core API endpoints deployed** — measured by: API spec coverage >= 95%,
   review_approved from backend-architect
3. **Beta users onboarded** — measured by: 10 external users with active sessions,
   human_approval from product owner

# Resource Allocation

| Phase / Area | Allocated (USD) | Notes |
|-------------|----------------|-------|
| Auth system | 1200 | Heaviest lift; security review required |
| Core API | 1500 | Backend-architect + code-reviewer cycles |
| Frontend | 800 | UI for beta; design assets pre-approved |
| QA and load testing | 700 | Automated + manual review |
| Buffer | 800 | Unplanned corrections, second review cycles |

# Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Auth implementation requires security rework | medium | high | Security review at MVP milestone, not at GA |
| infra-migration slips past MVP date | low | high | Decouple auth from new infra; maintain fallback path |
| Review cycles exceed budget on core API | medium | medium | Cap code-reviewer retries at 3; escalate to manager on third failure |
| Frontend design changes requested post-alpha | high | low | Freeze design scope at MVP; all changes go to backlog |

# Open Questions

- **What auth provider do we use — custom JWT or managed service?** — Owner: backend-architect, needed before: mvp
- **What constitutes "active session" for the beta onboarding metric?** — Owner: tech-lead, needed before: beta
```

---

## Project Lifecycle

```
planned → active → completed
              ↓
           paused → active
```

A `paused` project must have a recorded reason in `logs/activity.log` and an
explicit decision to resume before transitioning back to `active`. Paused projects
still consume their milestone slots in the company goal hierarchy.

Transitions to `completed` require all milestone evidence gates to be satisfied.
The owner agent records the completion in `logs/activity.log` with references to
the evidence gate artifacts.

---

## Validation Rules

A project definition is valid if:

1. All required frontmatter fields are present and non-empty
2. `id` is unique across all projects in the operation (both inline and standalone)
3. `owner` is a valid agent id that exists in `agents/`
4. `team` is a valid team id that exists in `teams/`
5. `status` is one of: `planned`, `active`, `completed`, `paused`
6. `budget` is greater than 0
7. All milestone `id` values are unique within the project
8. All milestone `target` values are valid ISO8601 dates
9. All milestone `evidence_gate` values reference valid gate types
10. All `dependencies[].id` values reference existing project ids
11. Dependency graph across the operation contains no cycles
12. All 4 body sections are present (matched by `# Section Name` headers)

---

### Projects as Signal Chains

In Signal Theory, a project is a **signal chain** — an ordered sequence of signals
directed toward a bounded outcome. Each milestone is a signal that must be decoded
and acted upon before the next signal can be sent.

| PROJECT.md Element | Signal Chain Function |
|-------------------|---------------------|
| Milestones | Sequential signals — each must complete before the next begins |
| Evidence gates | Feedback checkpoints — Wiener constraint (verify decoding before proceeding) |
| Dependencies | Signal ordering — Signal B cannot be encoded until Signal A is decoded and acted upon |
| Team assignments | Routing rules — which cluster handles which signal in the chain |
| Success criteria | Terminal signal — the final feedback that closes the entire chain |
| Timeline | Channel scheduling — when each signal enters the network |

**Signal topology**: Projects can have both sequential and parallel signals.
Milestones with dependencies are sequential (each blocks on the previous).
Independent milestones are parallel (multiple signals in flight simultaneously).
Forcing sequential flow where parallel is possible is a Shannon violation —
it wastes available channel bandwidth.

---

## See Also

- `protocol/company-format.md` — Initiative and goal hierarchy context
- `protocol/team-format.md` — Team definitions referenced by `team` field
- `protocol/task-format.md` — Task definitions that reference project milestones
- `protocol/operations-spec.md` — Full Operations Spec, Section 4 (Goal Hierarchy)

---

## Signal Theory Position

Projects implement **signal chains** spanning multiple Optimal System layers:

- **Layer 1 (Network)**: Team assignments define routing — which clusters handle which chain segments
- **Layer 5 (Data)**: Project manifests are stored in the data substrate as the chain's coordination record
- **Layer 6 (Feedback)**: Evidence gates ARE feedback checkpoints — each gate closes a Wiener loop
- **Layer 7 (Governance)**: Budget allocation and approval requirements encode governance constraints

See `architecture/optimal-system-mapping.md` for the full 7-layer mapping.
