# Division Manifest Format

> The standard for defining the top organizational layer within an Operation. Divisions are
> the highest grouping unit below the company — they contain departments, which contain teams,
> which contain agents. A division establishes the strategic envelope within which its
> departments operate: shared mission, collective budget ceiling, and the coordination
> patterns that govern cross-department work.

---

## Why Divisions

The `reportsTo` field in agent definitions composes agents into an org chart. Teams group
agents by function. Departments group teams by domain. But without a division layer, large
operations have no clear boundary between, say, revenue-generating functions and
infrastructure functions — no envelope that says: "These departments share a mission,
a budget ceiling, and a strategic context."

Divisions bridge that gap. A division is a named grouping of departments that:

- Shares a **budget ceiling** that constrains the sum of department budgets beneath it
- Operates under a **common mission** that scopes the collective purpose of all departments within
- Has **defined coordination patterns** — how departments pass work across domain boundaries
- Follows **escalation rules** for situations that exceed any single department's authority
- Has a **head** — a department-level leader who is accountable for the division's strategic output

Without divisions, a 10-department operation is a flat list of functional domains. With
divisions, it is a legible hierarchy where strategic accountability, budget authority, and
cross-department workflows are clearly bounded.

---

## File Convention

Every division definition lives in `divisions/{division-id}.md`. It follows the same YAML
frontmatter + Markdown body convention as team and department files. The frontmatter is
machine-readable. The body defines the division's operating model.

```
{operation-root}/
├── company.yaml
├── agents/
│   └── {agent-id}.md
├── teams/
│   └── {team-id}.md
├── departments/
│   └── {department-id}.md
└── divisions/
    ├── technology.md
    ├── revenue.md
    └── operations.md
```

---

## Frontmatter Schema

```yaml
---
name: string              # Display name ("Technology")
id: string                # URL-safe slug ("technology")
description: string       # One-line purpose statement
head: string              # Agent id of the division head (must exist in agents/)
departments: [string]     # List of department ids that belong to this division
budget: number            # Monthly USD ceiling for the division (across all departments)
signal: string            # Division's default output mode (Signal Theory)
---
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Human-readable division name |
| `id` | string | yes | URL-safe identifier matching the filename |
| `description` | string | yes | One-sentence statement of the division's purpose |
| `head` | string | yes | Agent id who leads the division; must exist in `agents/` |
| `departments` | list | yes | Department ids contained in this division; all must exist in `departments/` |
| `budget` | number | yes | Monthly USD ceiling for the division as a whole |
| `signal` | string | yes | Signal Theory default encoding for division-level outputs |

### Signal Encoding

The `signal` field follows the same 5-dimension format used throughout the protocol:

```yaml
signal: S=(mode, genre, type, format, structure)
```

At the division level, this encodes the expected output mode for division-level strategic
reports, resource allocation decisions, and cross-department communications. Division outputs
operate at a higher abstraction than team outputs — they communicate status and decisions
to company leadership, not execution detail.

```yaml
# Technology division producing quarterly engineering report
signal: S=(data, report, inform, markdown, division-status)

# Revenue division producing pipeline and forecast
signal: S=(data, report, decide, markdown, revenue-forecast)

# Operations division producing resource allocation recommendation
signal: S=(linguistic, brief, decide, markdown, resource-allocation)
```

### Budget Semantics

Division budget is a ceiling on the **sum** of all department budgets beneath it. Department
budgets are in turn ceilings on the sum of their team budgets. The hierarchy is:

```
Company:      total monthly cap ≤ $50,000

Division:     technology division combined spend ≤ $20,000
              revenue division combined spend ≤ $18,000

Department:   engineering dept combined spend ≤ $12,000 (within technology)
              platform dept combined spend ≤ $8,000 (within technology)

Team:         backend team combined spend ≤ $5,000 (within engineering dept)
              frontend team combined spend ≤ $4,000 (within engineering dept)

Individual:   backend-architect can spend ≤ $1,200/month
```

The most restrictive limit in the chain applies at every moment. If the technology division
is at $19,500/$20,000, all departments, teams, and agents within it are collectively limited
to $500 for the remainder of the period — regardless of their own remaining budgets.

---

## Body Sections

The Markdown body MUST contain these 4 sections in order:

### 1. Mission

What this division exists to do. Written as a purpose statement, not a task list. One to
three sentences scoped at the strategic level — not the operational level.

```markdown
# Mission

[Division name] exists to [primary strategic purpose]. We are accountable for [outcome domain]
and measure success by [strategic quality signal].
```

### 2. Operating Model

How departments within the division coordinate. This section documents the structural
patterns that govern how departments are organized, how resources are allocated between
them, and how the division head maintains coherence across department domains.

```markdown
# Operating Model

## Structure
[How departments are organized and why]

## Resource Allocation
[How the division budget is distributed across departments and adjusted over time]

## Rhythm
[Cadence of division-level reviews, planning cycles, and coordination events]
```

### 3. Cross-Department Coordination

Patterns for work that spans more than one department within the division. This section
makes cross-department workflows explicit — who initiates, who executes, and how handoffs
are governed when the work cannot be contained within a single department.

```markdown
# Cross-Department Coordination

## Pattern: [Name]
**Trigger**: [what initiates this cross-department flow]
**Departments involved**: [list of department ids]
**Flow**:
1. [Department id] receives [input] and produces [output]
2. [Department id] reviews or continues with [action]
3. [Resolution condition and responsible department]
```

### 4. Escalation Rules

Conditions that require the division head to act, or that escalate beyond the division to
company leadership. Division-level escalations concern strategic decisions, budget authority,
and situations that no single department can resolve. Be specific.

```markdown
# Escalation Rules

- ESCALATE TO DIVISION HEAD when: [specific cross-department condition]
- ESCALATE TO COMPANY when: [specific condition requiring CEO or board involvement]
- BLOCK AND WAIT FOR HUMAN when: [irreversible strategic action with ambiguous authorization]
```

---

## Relationship to the Org Chart

Divisions are a **grouping layer** on top of the `reportsTo` org chart, departments, and
teams. They do not replace any of these layers. The layers serve distinct functions:

```
Layer             Governs
─────────────     ──────────────────────────────────────────
reportsTo chain   Escalation routing between individuals
Teams             Coordination patterns between agents
Departments       Domain ownership and team grouping
Divisions         Strategic envelope and budget authority
Company           Total network capacity and governance policy
```

```
Org chart (reportsTo):           Divisions (departments):
  ceo                              technology/
    └── cto                          head: cto
          ├── engineering-lead        departments: [engineering, platform]
          ├── platform-lead         revenue/
    └── cro                          head: cro
          ├── sales-lead              departments: [sales, marketing]
          └── marketing-lead
```

A department belongs to exactly one division. If cross-division collaboration is needed,
model it as an escalation to company leadership or a cross-division coordination pattern
documented in each division's Cross-Department Coordination section.

---

## Budget Rollup

Budget enforcement checks proceed in this order:

1. **Agent-level check**: Does the individual agent have budget remaining?
2. **Team-level check**: Does the team have collective budget remaining?
3. **Department-level check**: Does the department have collective budget remaining?
4. **Division-level check**: Does the division have collective budget remaining?
5. **Company-level check**: Does the operation have monthly budget remaining?

All five checks must pass. The first failure blocks execution and triggers the relevant
enforcement tier from `company.yaml`.

Division budget events are logged in `logs/activity.log`:

```
{ISO8601} | {division-id} | budget_event | division_ceiling | {outcome} | {cost_usd}
```

---

## Validation Rules

A division file is valid if:

1. YAML frontmatter parses without error
2. All required frontmatter fields are present
3. `head` is a valid agent id that exists in `agents/`
4. All `departments` are valid department ids that exist in `departments/`
5. `budget` is greater than 0
6. `budget` is greater than or equal to the sum of all contained department budgets
7. `signal` field has exactly 5 comma-separated dimensions
8. All 4 body sections are present (matched by `# Section Name` headers)
9. No department appears in more than one division's `departments` list across the operation
10. The `id` field matches the filename (without the `.md` extension)
11. The `head` agent's `reportsTo` chain terminates at the company's defined CEO within the org chart

---

## Example

```yaml
---
name: Technology
id: technology
description: Build, operate, and evolve every software system the company depends on.
head: cto
departments: [engineering, platform, security]
budget: 22000
signal: S=(data, report, inform, markdown, division-status)
---
```

```markdown
# Mission

Technology exists to build, operate, and evolve every software system the company depends
on. We are accountable for system reliability, delivery velocity, and technical quality.
We measure success by uptime, deployment frequency, and signal scores across engineering
outputs.

# Operating Model

## Structure
Technology contains three departments: Engineering (product feature development), Platform
(infrastructure and developer tooling), and Security (threat modeling, compliance, and
access control). Engineering is the primary delivery unit. Platform exists to multiply
Engineering's throughput. Security sets the non-negotiable constraints both must operate
within.

## Resource Allocation
Division budget is allocated 55% to Engineering, 30% to Platform, and 15% to Security
at the start of each period. The CTO may rebalance allocations between periods based on
departmental spend rates and roadmap priorities. Rebalances exceeding 20% of any
department's allocation require a written rationale filed in `logs/budget-decisions.md`.

## Rhythm
Weekly: CTO reviews department-level spend and delivery metrics.
Monthly: Department heads submit status reports in division signal format.
Quarterly: CTO produces division-level strategic report for the CEO.

# Cross-Department Coordination

## Pattern: Security Review Gate
**Trigger**: Any feature or infrastructure change marked `security-review: required`
**Departments involved**: engineering (or platform), security
**Flow**:
1. `engineering` (or `platform`) completes implementation and produces a review request
   including: threat model, data flow diagram, and list of changed access boundaries
2. `security` reviews within 48 hours and returns APPROVED, CONDITIONAL, or BLOCKED
3. APPROVED: originating department proceeds to deployment
4. CONDITIONAL: originating department resolves conditions and re-submits (single cycle)
5. BLOCKED: escalate to division head (CTO) for resolution; no deployment until resolved

## Pattern: Platform Dependency Request
**Trigger**: Engineering requires a new infrastructure capability not yet available in Platform
**Departments involved**: engineering, platform
**Flow**:
1. `engineering` submits a dependency request specifying: capability needed, timeline, and
   impact on delivery if unavailable
2. `platform` reviews feasibility within 5 business days and responds with: ACCEPT (with
   delivery estimate), DEFER (with reason), or REJECT (with alternative)
3. If engineering disputes a DEFER or REJECT: escalate to division head

# Escalation Rules

- ESCALATE TO DIVISION HEAD when: A security review is BLOCKED and prevents a committed
  delivery milestone
- ESCALATE TO DIVISION HEAD when: A cross-department dependency request has been disputed
  and remains unresolved after 5 business days
- ESCALATE TO DIVISION HEAD when: Any department's spend reaches 85% of its allocation
  before the midpoint of the period
- ESCALATE TO COMPANY when: Division budget is within 15% of exhaustion before period end
- ESCALATE TO COMPANY when: A technical decision affects a non-Technology division's
  systems, data, or contractual commitments
- BLOCK AND WAIT FOR HUMAN when: Any action would modify production database schema,
  encryption keys, or access control policies across more than one department's scope
```

---

## Common Mistakes

**Wrong: Setting division budget lower than the sum of department budgets.**
The division ceiling only constrains if it is lower than what departments could collectively
spend. If the division budget is already below the committed department budgets, the
constraint fires immediately and blocks execution. Set the division ceiling intentionally.

**Wrong: Listing a head who does not appear in the org chart above the contained department heads.**
The division head must have organizational authority over the departments in the division.
An agent who is a peer of the department heads — not a manager — cannot serve as division head.

**Wrong: Putting the same department in two divisions.**
Departments have a single division context. Cross-division workflows are modeled as explicit
escalation patterns, not dual membership.

**Wrong: Writing mission statements at the operational level.**
A division mission describes strategic purpose and outcome accountability — not task lists.
"We write code, review PRs, and deploy services" is a team mission statement. "We build
and operate every system the company depends on" is a division mission statement.

**Wrong: Vague cross-department coordination with no trigger conditions.**
Every coordination pattern must name a specific, detectable trigger. Agents cannot initiate
cross-department workflows on ambiguous signals.

---

## See Also

- `protocol/department-format.md` — Department definitions, including `teams` membership
- `protocol/team-format.md` — Team definitions, including `members` and coordination patterns
- `protocol/agent-format.md` — Individual agent definitions, including `reportsTo`
- `protocol/company-format.md` — Company-level budget, governance, and escalation chain
- `architecture/governance.md` — How budget enforcement cascades through the hierarchy

---

### Divisions as Signal Network Subnets

In Signal Theory, a division is a **named subnet** in the Signal Network — a bounded
collection of clusters (departments and their teams) that share a strategic genre competence
and operate under a common bandwidth ceiling. Where `company.yaml` defines the full network
topology, a division definition encodes the largest operational subnet: its internal routing
policy (operating model), its cross-subnet interface (cross-department coordination), its
viability bypass channel (escalation rules), and its aggregate bandwidth ceiling (division
budget).

| DIVISION.md Element | Signal Network Function |
|--------------------|------------------------|
| `departments` list | Clusters within the subnet — each department is itself a collection of tightly-connected endpoints |
| Division mission | Strategic genre competence declaration — what classes of signals this subnet is responsible for producing |
| `head` | Subnet gateway — the node that routes signals between this subnet and the company-level network |
| Budget ceiling | Aggregate channel capacity for the subnet — Shannon constraint at the division level |
| Operating model | System 3 (Control) + System 2 (Coordination) — how the division head allocates resources and how departments synchronize |
| Cross-department patterns | Inter-cluster routing — how signals traverse department boundaries without losing fidelity |
| Escalation rules | Algedonic channel — viability-preserving bypass to company level when normal coordination fails |

**Recursive viability**: Every division IS a viable system. It has its own S1 (teams
executing work), S2 (coordination patterns between departments), S3 (division head
allocating resources and holding accountability), S4 (cross-department intelligence
surfaced to the division head), and S5 (division mission). This recursion is Beer's
fundamental insight — the same 5-subsystem structure repeats at every scale.

---

## Signal Theory Position

This spec implements **Layer 1 (Network subnets) + Layer 7 (Governance, recursive VSM at
the highest operational level)** of the Optimal System architecture.

Divisions ARE the largest operational subnets in the Signal Network — collections of
department clusters that share strategic genre competence, a common mission, and a defined
budget envelope. Where `company.yaml` defines the complete network and its governance
policy, a division definition encodes the primary routing boundary: its internal structure
(operating model), its cross-boundary interface (cross-department coordination patterns),
and its maximum throughput (division budget).

Each division IS also a recursive viable system operating at the highest sub-company scale:

| VSM Subsystem | Division Format Element |
|---------------|------------------------|
| S1 — Operations | `departments` — the operational units doing the work |
| S2 — Coordination | Cross-Department Coordination section — synchronization between departments |
| S3 — Control | `head` field + Operating Model section — accountable for resource allocation and output quality |
| S4 — Intelligence | Escalation Rules section — what the division observes and surfaces to company leadership |
| S5 — Policy | Division Mission section — the identity statement that constrains all department and team behavior within |

**Most relevant governing principles:**
- **Beer (recursion)** — Every division replicates the 5-subsystem structure. A viable division at any scale follows the same pattern as a viable team or company.
- **Ashby (variety matching)** — Division composition (the `departments` list) must provide enough domain variety to match the strategic challenges the division faces. A division facing both infrastructure and product demands with only one department type is an Ashby violation.
- **Shannon (bandwidth ceiling)** — The division budget is the aggregate channel capacity for the subnet. Exceeding it is a Shannon violation at the organizational level.

See `architecture/optimal-system-mapping.md` for the canonical layer mapping.
