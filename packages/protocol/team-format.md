# Team Manifest Format

> The standard for defining organizational subtrees within an Operation. Teams are
> the unit of coordination between individual agents and the company level — they
> group agents by function, establish a shared budget envelope, and define the
> coordination patterns that govern how members work together.

---

## Why Teams

The `reportsTo` field in agent definitions composes agents into an org chart. But
an org chart alone doesn't coordinate. It routes escalations. It doesn't answer:
"Who is responsible for shipping feature X?", "What's the engineering team's
collective budget ceiling?", or "How does a review handoff flow between members?"

Teams bridge that gap. A team is a named group of agents that:

- Shares a **budget ceiling** distinct from individual agent budgets
- Operates under a **common mission** that scopes their collective work
- Has **defined coordination patterns** — how members pass work to each other
- Follows **escalation rules** for situations that exceed individual authority
- Has a **manager** who is accountable for the team's output quality

Without teams, a 20-agent operation is a flat list. With teams, it's a legible
organization where responsibilities, budgets, and workflows are clearly bounded.

---

## File Convention

Every team definition lives in `teams/{team-id}.md`. Like agent files, it follows
a YAML frontmatter + Markdown body convention. The frontmatter is machine-readable.
The body defines the team's operating model.

```
{operation-root}/
├── company.yaml
├── agents/
│   └── {agent-id}.md
└── teams/
    ├── engineering.md
    ├── sales.md
    └── content.md
```

---

## Frontmatter Schema

```yaml
---
name: string                    # Display name ("Engineering Team")
id: string                      # Unique slug ("engineering")
manager: string                 # Agent id of the team lead / manager
members: [string]               # List of agent ids on this team
budget: number                  # Monthly USD ceiling for the team (across all members)
signal: string                  # Team's default output mode (Signal Theory)
---
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Human-readable team name |
| `id` | string | yes | URL-safe identifier matching the filename |
| `manager` | string | yes | Agent id who manages this team; must be in `agents/` |
| `members` | list | yes | Agent ids who belong to this team; all must be in `agents/` |
| `budget` | number | yes | Monthly USD ceiling for the team as a whole |
| `signal` | string | yes | Signal Theory default encoding for team-level outputs |

### Signal Encoding

The `signal` field follows the same 5-dimension format as agent definitions:

```yaml
signal: S=(mode, genre, type, format, structure)
```

For teams, this encodes the expected output mode for team-level status reports,
retrospectives, and inter-team communications. Examples:

```yaml
# Engineering team producing sprint reports
signal: S=(data, report, inform, markdown, sprint-status)

# Sales team producing pipeline updates
signal: S=(data, report, inform, markdown, pipeline-summary)

# Content team producing editorial briefs
signal: S=(linguistic, brief, inform, markdown, editorial-status)
```

### Budget Semantics

Team budget is a ceiling on the **sum** of all member spending within the period,
not a per-agent cap. Individual agents retain their own `budget` fields in their
frontmatter. The team budget adds a rollup layer:

```
Individual:   agent-A can spend ≤ $400/month
              agent-B can spend ≤ $400/month
              agent-C can spend ≤ $600/month

Team ceiling: engineering team combined spend ≤ $1000/month
```

The more restrictive limit applies. If agent-A has $400/month but the team is
already at $950/$1000, agent-A is effectively limited to $50 for the remainder
of the period.

---

## Body Sections

The Markdown body MUST contain these 4 sections in order:

### 1. Mission

What this team exists to do. Written as a purpose statement, not a task list.
One to three sentences.

```markdown
# Mission

[Team name] exists to [primary purpose]. We are accountable for [outcome domain]
and measure success by [quality signal].
```

### 2. Coordination Patterns

How members collaborate. This section documents the repeating patterns that govern
day-to-day work — who does what, in what order, and how work moves between members.
Use numbered steps for sequential flows. Use parallel notation for concurrent work.

```markdown
# Coordination Patterns

## Pattern: [Name]
**Trigger**: [what starts this pattern]
**Flow**:
1. [Agent id] receives [input] and produces [output]
2. [Agent id] reviews output and either approves or returns with feedback
3. On approval: [Agent id] proceeds to [next step]
```

### 3. Escalation Rules

Conditions that require the manager to be notified or that escalate beyond the
team to the `reportsTo` chain. Be specific — vague escalation rules produce
inconsistent behavior.

```markdown
# Escalation Rules

- ESCALATE TO MANAGER when: [specific condition]
- ESCALATE OUTSIDE TEAM when: [specific condition requiring company-level involvement]
- BLOCK AND WAIT FOR HUMAN when: [irreversible action with ambiguous authorization]
```

### 4. Handoff Protocols

How work transitions between team members. Each handoff names the sender,
receiver, trigger condition, and required artifacts. This section makes implicit
coordination explicit.

```markdown
# Handoff Protocols

## [Sender] → [Receiver]
**Trigger**: [when does this handoff happen]
**Required artifacts**: [what must be produced before the handoff]
**Format**: [what genre/structure the handoff document uses]
**Gate**: [what the receiver checks before accepting work]
```

---

## Relationship to the Org Chart

Teams are a **grouping layer** on top of the `reportsTo` org chart. They do not
replace it. The org chart governs escalation paths. Teams govern coordination
patterns. Both can coexist without conflict:

```
Org chart (reportsTo):           Teams (members):
  ceo                              engineering/
    └── cto                          manager: cto
          ├── backend-dev            members: [backend-dev, frontend-dev, qa]
          ├── frontend-dev         sales/
          ├── qa-engineer            manager: cro
    └── cro                          members: [prospector, closer]
          ├── prospector
          └── closer
```

An agent can appear in only one team. If cross-functional collaboration is needed,
model it as a workflow handoff between teams — not as membership in multiple teams.

---

## Budget Rollup

Budget enforcement checks proceed in this order:

1. **Agent-level check**: Does the individual agent have budget remaining?
2. **Team-level check**: Does the team have collective budget remaining?
3. **Company-level check**: Does the operation have monthly budget remaining?

All three checks must pass. The first failure blocks execution and triggers the
relevant enforcement tier from `company.yaml`.

Team budget events are logged in `logs/activity.log`:

```
{ISO8601} | {team-id} | budget_event | team_ceiling | {outcome} | {cost_usd}
```

---

## Validation Rules

A team file is valid if:

1. YAML frontmatter parses without error
2. All required frontmatter fields are present
3. `manager` is a valid agent id that exists in `agents/`
4. All `members` are valid agent ids that exist in `agents/`
5. `manager` is one of the `members` (a manager is always a team member)
6. `budget` is greater than 0
7. `signal` field has exactly 5 comma-separated dimensions
8. All 4 body sections are present (matched by `# Section Name` headers)
9. No agent appears in more than one team's `members` list across the operation
10. The `id` field matches the filename (without the `.md` extension)

---

## Example

```yaml
---
name: Engineering
id: engineering
manager: cto
members: [cto, backend-architect, frontend-developer, code-reviewer, sre]
budget: 3000
signal: S=(data, report, inform, markdown, sprint-status)
---
```

```markdown
# Mission

Engineering exists to ship production-quality software that satisfies the
product spec on schedule. We are accountable for code quality, system
reliability, and delivery velocity. We measure success by defect rate,
deployment frequency, and signal scores on all code reviews.

# Coordination Patterns

## Pattern: Feature Implementation
**Trigger**: A task with `type: feature` enters `status: active`
**Flow**:
1. `backend-architect` reviews the spec and produces an architecture note
2. `backend-architect` hands off to `frontend-developer` + any backend agent in parallel
3. Implementation proceeds; agents may consult `backend-architect` on ambiguous decisions
4. On completion, each agent produces a handoff to `code-reviewer`
5. `code-reviewer` returns PASS or FAIL with specific corrections
6. On PASS: agent creates handoff to `sre` for deployment check
7. On FAIL: agent corrects and re-submits to `code-reviewer` (max 3 cycles)

## Pattern: Bug Response
**Trigger**: A task with `type: bug` and `priority: critical` enters `active`
**Flow**:
1. `sre` triages: is this a production incident? YES → escalate to manager
2. If not incident: `sre` assigns to the agent who owns the affected subsystem
3. Assigned agent reproduces, fixes, and hands off to `code-reviewer`
4. `code-reviewer` fast-tracks review (1-cycle limit for criticals)
5. `sre` deploys and monitors for 30 minutes

# Escalation Rules

- ESCALATE TO MANAGER when: QA/review cycle exceeds 3 retries on any single task
- ESCALATE TO MANAGER when: A task has been `blocked` for more than 24 hours
- ESCALATE OUTSIDE TEAM when: Budget ceiling is within 20% of exhaustion mid-period
- ESCALATE OUTSIDE TEAM when: An architectural decision affects another team's domain
- BLOCK AND WAIT FOR HUMAN when: Any deployment targets the production database schema

# Handoff Protocols

## backend-architect → code-reviewer
**Trigger**: Architecture note is finalized and implementation is complete
**Required artifacts**: Architecture note, implementation diff or file list, test results
**Format**: `S=(linguistic, spec, commit, markdown, architecture-note)`
**Gate**: code-reviewer checks that the implementation matches the architecture note
         and all referenced tests are green

## code-reviewer → sre
**Trigger**: code-reviewer issues a PASS verdict
**Required artifacts**: Review summary, list of changed files, test coverage report
**Format**: `S=(data, report, decide, markdown, review-summary)`
**Gate**: sre confirms deployment checklist is complete before proceeding

## any-member → cto (escalation)
**Trigger**: Any escalation condition above is met
**Required artifacts**: Description of the blocker, what was attempted, recommended path
**Format**: `S=(linguistic, brief, direct, markdown, escalation-brief)`
**Gate**: cto must acknowledge within 2 hours; if no response, notify CEO
```

---

## Common Mistakes

**Wrong: Listing a manager who is not in members.**
The manager must be a team member. They lead from within the team.

**Wrong: Putting the same agent in two teams.**
Agents have a single team context. Cross-team work flows via handoffs,
not dual membership.

**Wrong: Setting team budget higher than the sum of individual agent budgets.**
The team ceiling only matters if it is lower than what members could collectively
spend. A ceiling above the sum is not enforced and creates a false sense of control.

**Wrong: Vague escalation rules like "escalate when things go wrong."**
Escalation rules must name specific, detectable conditions. Agents cannot escalate
on ambiguous signals.

---

## See Also

- `protocol/agent-format.md` — Individual agent definitions, including `reportsTo`
- `protocol/company-format.md` — Company-level budget and governance
- `protocol/task-format.md` — Task definitions, including team assignment
- `architecture/governance.md` — How budget enforcement cascades through the hierarchy

---

### Teams as Signal Network Clusters

In Signal Theory, a team is a **cluster** in the Signal Network — a group of
tightly-connected endpoints with shared genre competence. The team format
encodes this network function:

| TEAM.md Element | Signal Network Function |
|----------------|------------------------|
| Team members list | Endpoints in the cluster — nodes that can encode/decode signals within the team's domain |
| Team mission | Shared genre competence declaration — what classes of signals this cluster handles |
| Manager / lead | Cluster gateway — the node that routes signals between this cluster and the broader network |
| Budget rollup | Aggregate channel capacity — Shannon constraint at the team level |
| Coordination patterns | System 2 (Coordination) — how S1 units within the cluster synchronize |
| Escalation rules | Algedonic channel — viability-preserving bypass when normal coordination fails |

**Recursive viability**: Every team IS a viable system. It has its own S1 (members
executing tasks), S2 (coordination patterns), S3 (manager allocating resources),
S4 (team-level pattern recognition), and S5 (team mission). This recursion is
Beer's fundamental insight — the same 5-subsystem structure repeats at every scale.

---

## Signal Theory Position

This spec implements **Layer 1 (Network clusters) + Layer 7 (Governance, recursive VSM)** of the Optimal System architecture.

Teams ARE clusters in the Signal Network — tightly connected endpoints that share genre competence, a common mission, and defined handoff protocols. Where `company.yaml` defines the full network topology, a team definition encodes a subnet: its internal routing (coordination patterns), its interface to the wider network (escalation rules and handoff protocols), and its bandwidth ceiling (team budget).

Each team IS also a recursive viable system. The 5 Beer subsystems appear directly in the team format:

| VSM Subsystem | Team Format Element |
|---------------|---------------------|
| S1 — Operations | `members` — the agents doing the work |
| S2 — Coordination | Coordination Patterns section — synchronization between members |
| S3 — Control | `manager` field — accountable for output quality and resource use |
| S4 — Intelligence | Escalation Rules section — what the team observes and surfaces upward |
| S5 — Policy | Team Mission section — the identity statement that constrains member behavior |

**Most relevant governing principles:**
- **Beer (recursion)** — Every team replicates the 5-subsystem structure. A viable team at any scale follows the same pattern.
- **Ashby (variety matching)** — Team composition (the `members` list) must provide enough behavioral variety to match the task variety the team faces. An under-staffed team is an Ashby violation.

See `architecture/optimal-system-mapping.md` for the canonical layer mapping.
