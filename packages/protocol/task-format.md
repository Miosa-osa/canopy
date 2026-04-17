# Task Manifest Format

> The standard for portable, reusable task definitions. Tasks are the atomic unit
> of work in an Operation — assigned to a single agent, scoped to one output,
> and resolvable in hours to days. This format adds structured headers, schedules,
> and evidence gates to the bare task schema in the Operations Spec.

---

## Two Task Forms

Tasks exist in two forms, each with a distinct purpose:

| Form | Location | When to Use |
|------|----------|-------------|
| **Ephemeral task** | `tasks/{ISSUE_PREFIX}-{n}.yaml` | Work items created at runtime — bugs, features, ad-hoc requests |
| **Task manifest** | `tasks/manifests/{task-id}.md` | Recurring or template tasks with fixed instructions, schedules, and acceptance criteria |

The Operations Spec (Section 4) documents the ephemeral YAML format. This file
documents the manifest format — the richer, persistent form used for repeating
work that is worth codifying.

A task manifest is a reusable definition. The runtime instantiates it on demand
or on schedule, creating an ephemeral task record in `tasks/` that links back to
the manifest.

---

## File Convention

```
{operation-root}/
└── tasks/
    ├── ACM-001.yaml             ← Ephemeral task (runtime-generated)
    ├── ACM-002.yaml
    └── manifests/               ← Task manifest definitions (committed)
        ├── monday-review.md
        ├── weekly-digest.md
        └── sprint-kickoff.md
```

---

## Frontmatter Schema

```yaml
---
name: string                    # Display name ("Monday Review")
id: string                      # Unique slug matching filename ("monday-review")
assignee: string                # Agent id responsible for execution
project: string | null          # Project id this task contributes to (optional)
milestone: string | null        # Milestone id this task satisfies (optional)
priority: string                # critical | high | medium | low
type: string                    # task | review | research | decision | recurring
schedule:
  cron: string                  # Cron expression ("0 9 * * 1" = Monday 9am)
  timezone: string              # IANA timezone ("America/Chicago")
  expires: ISO8601 | null       # Stop instantiating after this date (optional)
evidence_gate: string | null    # Gate type required for completion (or null)
signal: string                  # Signal Theory encoding for the output
---
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Human-readable task name |
| `id` | string | yes | URL-safe identifier; must match the filename |
| `assignee` | string | yes | Agent id that executes this task |
| `project` | string | no | Project id this task belongs to; null for unattached tasks |
| `milestone` | string | no | Milestone id this task contributes evidence for |
| `priority` | string | yes | Execution priority relative to other active tasks |
| `type` | string | yes | Task type (see below) |
| `schedule` | object | no | Present only for recurring tasks; absent for on-demand tasks |
| `schedule.cron` | string | yes (if schedule) | Standard cron expression (5 fields) |
| `schedule.timezone` | string | yes (if schedule) | IANA timezone string |
| `schedule.expires` | ISO8601 | no | Date after which the schedule stops firing |
| `evidence_gate` | string | no | Gate type required to mark this task done; null = no gate |
| `signal` | string | yes | Signal Theory encoding for the task's expected output |

### Priority Values

| Priority | When to Use |
|----------|-------------|
| `critical` | Production incident, blocking dependency, time-sensitive delivery |
| `high` | Active milestone work, deadline within 48 hours |
| `medium` | Standard feature work, no immediate deadline pressure |
| `low` | Background research, documentation, long-horizon improvements |

### Type Values

| Type | Semantics |
|------|-----------|
| `task` | Standard execution — produce an artifact, complete an action |
| `review` | Evaluate and judge another agent's output |
| `research` | Gather and synthesize information; output is a report or brief |
| `decision` | Analyze options and record a decision with rationale |
| `recurring` | Repeating task instantiated on a cron schedule |

### Evidence Gates

Evidence gates connect tasks to milestone completion. When a task references a
milestone, completing the task with a passing evidence gate contributes to that
milestone's evidence record:

| Gate Type | Satisfied When |
|-----------|---------------|
| `review_approved` | The task output has been reviewed and approved by the designated reviewer |
| `tests_pass` | All tests associated with this task's output are green |
| `signal_score` | The output's S/N score exceeds the workflow's threshold |
| `human_approval` | A human sign-off has been recorded in the activity log |
| `budget_check` | This task's spend is within the milestone's allocated budget |

Set `evidence_gate: null` for tasks that do not directly satisfy milestone criteria —
utility tasks, research steps, or work products that are inputs to larger deliverables.

### Signal Encoding

The `signal` field declares the expected output encoding for this task. This
tells the assignee agent what genre, format, and structure to use when producing
the task deliverable:

```yaml
# A research task producing a briefing document
signal: S=(linguistic, brief, inform, markdown, executive-summary)

# A code review task
signal: S=(linguistic, report, decide, markdown, review-summary)

# A recurring status report
signal: S=(data, report, inform, markdown, team-status)
```

All 5 dimensions must be resolved. Unresolved dimensions produce inconsistent
output and will fail the S/N gate at phase transitions.

---

## Body Sections

The Markdown body MUST contain these 3 sections in order:

### 1. Instructions

What the agent must do to complete this task. Written as a step-by-step procedure
or a clear description of the work required. If the task is recurring, write
instructions that work for any instance of the recurring run.

Use imperative language. The agent executes these instructions directly.

```markdown
# Instructions

1. [Step 1 — what to do]
2. [Step 2 — what to do next]
3. [Step N — how to finalize]
```

### 2. Acceptance Criteria

The specific conditions that must be true for this task to be considered complete.
These are distinct from the evidence gate — acceptance criteria are the detailed
checklist, the evidence gate is the summary gate type that is evaluated once the
criteria are met.

Write as a checklist. Each item should be independently verifiable.

```markdown
# Acceptance Criteria

- [ ] [Specific, verifiable condition]
- [ ] [Specific, verifiable condition]
- [ ] [Specific, verifiable condition]
```

### 3. Output Format

The exact format of the deliverable this task produces. Reference the Signal
Theory dimensions from the frontmatter and specify any template the agent should
follow. If the output is a structured document, define the headers and sections.

```markdown
# Output Format

**Signal**: `S=(mode, genre, type, format, structure)`

[Describe the output structure, or paste the template the agent should use.]
```

---

## On-Demand vs Recurring Tasks

### On-Demand Task Manifest

An on-demand manifest has no `schedule` field. It is instantiated by an agent,
a workflow, or a human trigger:

```yaml
---
name: Code Review
id: code-review
assignee: code-reviewer
project: q2-launch
milestone: mvp
priority: high
type: review
evidence_gate: review_approved
signal: S=(linguistic, report, decide, markdown, review-summary)
---
```

### Recurring Task Manifest

A recurring manifest fires on a cron schedule. Each run creates a new ephemeral
task record in `tasks/`. The assignee agent reads the manifest for instructions
on each run:

```yaml
---
name: Monday Review
id: monday-review
assignee: ceo
project: null
milestone: null
priority: medium
type: recurring
schedule:
  cron: "0 9 * * 1"
  timezone: America/Chicago
  expires: null
evidence_gate: null
signal: S=(data, report, inform, markdown, team-status)
---
```

---

## Full Example — Recurring Status Review

```yaml
---
name: Monday Review
id: monday-review
assignee: ceo
project: null
milestone: null
priority: medium
type: recurring
schedule:
  cron: "0 9 * * 1"
  timezone: America/Chicago
  expires: null
evidence_gate: null
signal: S=(data, report, inform, markdown, team-status)
---
```

```markdown
# Instructions

1. Pull the activity log from the past 7 days: `logs/activity.log`
2. Summarize completed tasks by team — engineering, sales, content
3. Identify any blocked tasks older than 48 hours; note the blocking reason
4. Review budget consumption against monthly ceilings for each team
5. Flag any team spending above 80% of its monthly ceiling
6. Note any escalations logged in `logs/escalations.log` since last Monday
7. Produce the weekly status report using the Output Format below
8. Post the report to the CEO's channel and log the delivery in the activity log

# Acceptance Criteria

- [ ] All three teams are represented in the status report
- [ ] Each blocked task is named with its blocking reason and time-in-blocked state
- [ ] Budget status is listed for each team with percentage consumed
- [ ] Any escalations from the past week are summarized
- [ ] Report is delivered before 10am Chicago time on Monday

# Output Format

**Signal**: `S=(data, report, inform, markdown, team-status)`

```markdown
# Weekly Review — {date}

## Engineering
- Completed: [list]
- In Progress: [list]
- Blocked: [list with reasons]
- Budget: {spent}/{ceiling} ({pct}%)

## Sales
- Completed: [list]
- In Progress: [list]
- Blocked: [list with reasons]
- Budget: {spent}/{ceiling} ({pct}%)

## Content
- Completed: [list]
- In Progress: [list]
- Blocked: [list with reasons]
- Budget: {spent}/{ceiling} ({pct}%)

## Escalations
- [None | list of escalation summaries]

## Actions Required
- [Any items requiring human decision or cross-team coordination]
```
```

---

## Full Example — On-Demand Code Review

```yaml
---
name: Code Review
id: code-review
assignee: code-reviewer
project: q2-launch
milestone: mvp
priority: high
type: review
evidence_gate: review_approved
signal: S=(linguistic, report, decide, markdown, review-summary)
---
```

```markdown
# Instructions

1. Read the files listed in the task's `context` field (injected at instantiation)
2. Apply the review checklist from `reference/standards.md`
3. Check for: correctness, security (OWASP Top 10 applicable items), performance,
   maintainability, and test coverage
4. Score each dimension on a 1-5 scale
5. Produce a review summary using the Output Format below
6. If any dimension scores below 3: REJECT and list required corrections
7. If all dimensions score 3 or above: APPROVE and record in the activity log

# Acceptance Criteria

- [ ] All modified files are reviewed
- [ ] Each of the 5 dimensions is scored
- [ ] Any REJECT verdict includes specific, actionable correction items
- [ ] Review summary is produced in the correct format
- [ ] Result (APPROVE or REJECT) is logged in activity.log

# Output Format

**Signal**: `S=(linguistic, report, decide, markdown, review-summary)`

```markdown
## Code Review: {task-id}
**Verdict**: APPROVED | REJECTED
**Reviewer**: code-reviewer  **Date**: {date}

### Scores
| Dimension | Score (1-5) | Notes |
|-----------|------------|-------|
| Correctness | | |
| Security | | |
| Performance | | |
| Maintainability | | |
| Test Coverage | | |

### Issues Found
1. [CRITICAL] {file}:{line} — {description}
2. [MAJOR] {file}:{line} — {description}
3. [MINOR] {file}:{line} — {description}

### Required Corrections (if REJECTED)
1. [Specific correction]

### Signal Quality
S/N score: {score}  Mode: linguistic  Genre: report
```
```

---

## Instantiation Record

When a manifest is instantiated — either by a cron trigger or an agent — the
runtime creates an ephemeral record in `tasks/`:

```yaml
# tasks/ACM-042.yaml
id: ACM-042
title: Monday Review — 2026-03-23
type: recurring
status: active
assigned_to: ceo
manifest: monday-review         # Reference back to the manifest
milestone: null
priority: medium
estimate_hours: 0.5
evidence_required: null
created_at: 2026-03-23T09:00:00Z
updated_at: 2026-03-23T09:00:00Z
```

The ephemeral record tracks runtime state (status, timestamps, actual cost).
The manifest holds the permanent instructions. This separation keeps manifests
clean and reusable while letting the task record accumulate execution history.

---

## Validation Rules

A task manifest is valid if:

1. YAML frontmatter parses without error
2. All required frontmatter fields are present
3. `id` matches the filename (without `.md` extension)
4. `assignee` is a valid agent id that exists in `agents/`
5. `project`, if not null, references a valid project id
6. `milestone`, if not null, references a valid milestone id within the project
7. `priority` is one of: `critical`, `high`, `medium`, `low`
8. `type` is one of: `task`, `review`, `research`, `decision`, `recurring`
9. If `schedule` is present: `cron` is a valid 5-field cron expression and `timezone` is a valid IANA timezone
10. If `schedule` is present: `type` is `recurring`
11. If `type` is `recurring`: `schedule` is present
12. `evidence_gate`, if not null, references a valid gate type
13. `signal` has exactly 5 comma-separated dimensions
14. All 3 body sections are present (matched by `# Section Name` headers)

---

## Common Mistakes

**Wrong: A recurring task with `evidence_gate` set.**
Recurring tasks produce periodic outputs; they rarely satisfy a single milestone.
Set `evidence_gate: null` for recurring tasks unless they are specifically designed
to close out a milestone.

**Wrong: Instructions written as outcomes rather than actions.**
"The review should be complete" is not an instruction. "Read the files, apply
the checklist, produce the summary" is an instruction. Write what to do, not what
should result.

**Wrong: Acceptance criteria that duplicate the instructions.**
Instructions describe the process. Acceptance criteria describe the done state.
"Ran the review" is not a criterion — "All modified files are reviewed" is.

**Wrong: An evidence gate with no acceptance criteria that maps to it.**
If `evidence_gate: review_approved`, at least one acceptance criterion must
verify that the review was actually approved by a designated reviewer.

---

### Tasks as Atomic Signals

In Signal Theory, a task is an **atomic signal** — the smallest unit of encoded
intent that produces action at a destination. One task = one intent = one signal.

| TASK.md Element | Atomic Signal Property |
|----------------|----------------------|
| Title / description | Encoded intent — what action this signal demands |
| Assignee | Destination node — the endpoint that will decode and act |
| Status | Signal lifecycle stage — Created → Sent → Received → Decoded → Acted Upon |
| Priority | Channel priority — which signals get decoded first when bandwidth is constrained |
| Dependencies | Signal ordering — this signal cannot be transmitted until prerequisite signals complete |
| Evidence / acceptance criteria | Feedback specification — what constitutes confirmed decoding (Wiener loop closure) |
| Template | Genre skeleton — pre-resolved Structure (dimension W) for recurring task patterns |
| Tags | Signal metadata — classification dimensions for routing and filtering |

**Task status IS the Signal lifecycle**:

```
pending     = Created (intent encoded, not yet transmitted)
assigned    = Sent (signal in transit to destination node)
in_progress = Received + Decoding (destination is processing)
review      = Decoded (output produced, awaiting feedback confirmation)
done        = Acted Upon + Feedback closed (loop complete)
blocked     = Transmission failure (noise, routing error, dependency)
cancelled   = Signal withdrawn (intent no longer valid)
```

**Task templates** are genre templates at the task level — the same dual-process
encoding mechanism as skills. A recurring task pattern (weekly report, sprint
review, deploy checklist) gets formalized as a template, converting expensive
System 2 encoding into cheap System 1 invocation.

---

## See Also

- `protocol/operations-spec.md` — Section 4: Goal Hierarchy and ephemeral task schema
- `protocol/project-format.md` — Project definitions that tasks roll up to
- `protocol/team-format.md` — Team definitions and coordination patterns for task handoffs
- `protocol/agent-format.md` — Agent definitions, including the `skills` that agents use during task execution
- `protocol/signal-theory.md` — Signal Theory reference for the `signal` field

---

## Signal Theory Position

Tasks implement **atomic signals** at the most granular level of the Optimal System:

- **Layer 2 (Signal)**: Each task IS a signal — encoded intent directed at a destination to produce action
- **Layer 5 (Data)**: Task manifests persist in the data substrate, tracking lifecycle state
- **Layer 6 (Feedback)**: Task completion with evidence IS feedback loop closure — the Wiener constraint at the atomic level
- **Layer 7 (Governance)**: Priority, assignment rules, and approval requirements encode governance constraints

The task lifecycle (pending → assigned → in_progress → review → done) maps directly
to the Signal lifecycle (Created → Sent → Received → Decoded → Acted Upon + Feedback).

See `architecture/optimal-system-mapping.md` for the full 7-layer mapping.
