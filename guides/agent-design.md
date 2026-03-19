# Agent Design Guide

> How to write effective agent definitions for OSA Operations.

---

## Agent Definition Format

Every agent is a single markdown file with two parts:

1. **YAML frontmatter** -- Machine-readable metadata (organizational, budget, signal encoding)
2. **Markdown body** -- The system prompt injected when the agent activates (7 required sections)

### YAML Frontmatter

```yaml
---
name: Code Reviewer
id: code-reviewer
role: reviewer
title: Senior Code Reviewer
reportsTo: tech-lead
budget: 600
color: "#2E8B57"
emoji: "\U0001F50D"
adapter: osa
signal: S=(linguistic, report, inform, markdown, review-checklist)
tools: [read, write, edit, search, bash]
context_tier: l1
---
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Human-readable agent name |
| `id` | Yes | Machine identifier (kebab-case, unique within operation) |
| `role` | Yes | Functional role (maps to workflow phase ownership) |
| `title` | Yes | Job title for org chart display |
| `reportsTo` | Yes | ID of manager agent (or `board` for top-level) |
| `budget` | Yes | Monthly USD budget for this agent |
| `color` | No | Hex color for UI display |
| `emoji` | No | Display emoji |
| `adapter` | Yes | Runtime adapter: `osa`, `claude-code`, `cursor`, `http` |
| `signal` | Yes | Default signal encoding: S=(M, G, T, F, W) |
| `tools` | Yes | List of tools this agent can use |
| `context_tier` | No | Default context loading tier: `l0`, `l1`, `full` |

### The 7 Body Sections

Every agent markdown body MUST contain these 7 sections:

```markdown
# Identity & Memory
Who this agent is, their personality, what they remember.

# Core Mission
Numbered list of 3-7 primary responsibilities.

# Critical Rules
NEVER/ALWAYS rules that constrain agent behavior.

# Process / Methodology
How the agent works -- frameworks, decision trees, reference tables.

# Deliverable Templates
Markdown templates for the agent's primary outputs.

# Communication Style
Tone, default genre, receiver calibration.

# Success Metrics
How to measure whether this agent is performing.
```

---

## Designing Effective Agent Personalities

A good agent personality is not about being creative with adjectives. It is about
encoding the behavioral constraints that make the agent useful.

### The Three Personality Levers

**1. Domain expertise** -- What does this agent know deeply?

Bad: "You are an expert in everything related to software."
Good: "You think in bounded contexts, trade-off matrices, and architectural decision records."

**2. Behavioral constraints** -- What does this agent refuse to do?

Bad: "Be helpful and thorough."
Good: "NEVER engage in architecture astronautics -- every abstraction must justify its complexity."

**3. Decision framework** -- How does this agent make choices?

Bad: "Make good decisions."
Good: "Prefer reversible decisions over 'optimal' ones. When two approaches are close, choose the simpler one."

### Identity & Memory Section

This section establishes the agent's persona. Write it in second person ("You are...").
Include:

- **Role**: One-line functional description
- **Personality**: 3-5 adjectives that constrain behavior (not decorate it)
- **Memory**: What patterns this agent retains across sessions
- **Experience**: What this agent has "seen" that shapes its judgment

```markdown
# Identity & Memory

You are **Outbound Prospector**, a senior outbound sales specialist who builds
pipeline through signal-based prospecting and precision multi-channel sequences.
You believe outreach should be triggered by evidence, not quotas.

- **Role**: Signal-based outbound strategist and sequence architect
- **Personality**: Sharp, data-driven, allergic to generic outreach
- **Memory**: You remember which signal types, channels, and messaging angles
  produce pipeline for specific ICPs
- **Experience**: You've watched the inbox enforcement era kill lazy outbound,
  and you've thrived because you adapted to relevance-first selling
```

### Critical Rules Section

Rules are the most important part of the agent definition. They prevent failure modes.
Write them as NEVER/ALWAYS constraints:

```markdown
# Critical Rules

- NEVER send outreach without a reason the buyer should care right now
- NEVER use "just checking in" as an outreach angle
- ALWAYS document what works -- a playbook in one rep's head is not a playbook
- ALWAYS test one variable at a time
- ALWAYS respect opt-outs immediately and completely
```

Rules should be:
- **Specific** -- "NEVER automate what should be personal" not "Be thoughtful"
- **Actionable** -- The agent can evaluate compliance in any situation
- **Derived from failure modes** -- Each rule prevents a known mistake

---

## Budget and Adapter Configuration

### Budget

The `budget` field in YAML sets the monthly USD ceiling for this agent. When the
agent's cumulative token costs exceed this amount, the heartbeat system auto-pauses
the agent and notifies the board.

```yaml
budget: 800  # $800/month ceiling
```

Budget guidance by agent complexity:

| Agent Type | Typical Budget | Why |
|-----------|---------------|-----|
| Utility (formatter, linter) | $100-300 | Few invocations, small context |
| Specialist (reviewer, QA) | $400-800 | Regular invocations, medium context |
| Lead (tech-lead, director) | $800-1500 | Frequent invocations, large context, orchestration |

### Adapter

The `adapter` field determines which runtime executes this agent:

| Adapter | When to Use |
|---------|------------|
| `osa` | Full protocol support -- heartbeat, sessions, budget enforcement |
| `claude-code` | Running inside Claude Code as behavioral mode |
| `cursor` | Running inside Cursor as agent rule |
| `http` | Custom runtime that speaks HTTP |

### Tools

The `tools` list defines what this agent can do:

```yaml
tools: [read, write, edit, search, bash, web-search]
```

Common tool sets:

| Agent Type | Tools |
|-----------|-------|
| Analyst / Researcher | `[read, search, web-search]` |
| Developer | `[read, write, edit, search, bash]` |
| Writer / Content | `[read, write, edit, search, web-search]` |
| Orchestrator | `[read, write, edit, search, bash, web-search]` |

---

## Signal Theory Integration

Every agent carries a default signal encoding:

```yaml
signal: S=(linguistic, spec, commit, markdown, adr-template)
```

This encodes the 5 dimensions of every output the agent produces:

| Dimension | What It Resolves | Example Values |
|-----------|-----------------|----------------|
| **M** (Mode) | How is it perceived? | linguistic, visual, code, data, mixed |
| **G** (Genre) | What form does it take? | spec, brief, report, proposal, plan, note |
| **T** (Type) | What does it do? | direct, inform, commit, decide, express |
| **F** (Format) | What container? | markdown, code, JSON, yaml, HTML |
| **W** (Structure) | Internal skeleton? | adr-template, review-checklist, meddpicc-scorecard |

### How to Choose the Right Signal

Match the signal to the agent's primary receiver:

| Receiver | Preferred Genre | Example Signal |
|----------|----------------|----------------|
| Developers | spec | S=(code, spec, commit, markdown, component-architecture) |
| Salespeople | brief | S=(linguistic, brief, direct, markdown, persuasion) |
| Executives | report | S=(data, report, inform, markdown, executive-dashboard) |
| Other agents | spec or report | S=(linguistic, report, inform, markdown, handoff-template) |

### Overriding Per-Deliverable

The frontmatter signal is the default. Agents can override for specific deliverables
in their Deliverable Templates section:

```markdown
### Template: Executive Summary
> Signal override: S=(linguistic, brief, inform, markdown, executive-summary)

### Template: Architecture Decision Record
> Signal override: S=(linguistic, spec, commit, markdown, adr-template)
```

---

## Examples

### Simple Agent: Bug Triager

A lightweight agent that classifies incoming bug reports.

```yaml
---
name: Bug Triager
id: bug-triager
role: triager
title: Bug Triage Specialist
reportsTo: tech-lead
budget: 200
adapter: osa
signal: S=(linguistic, report, decide, markdown, triage-template)
tools: [read, search]
context_tier: l0
---

# Identity & Memory

You are **Bug Triager**, a specialist who classifies incoming bug reports by severity,
component, and likely root cause. You are fast, decisive, and never block the queue.

- **Role**: Bug report classification and routing
- **Personality**: Decisive, systematic, zero tolerance for vague reports
- **Memory**: You track recurring bug patterns and component failure rates
- **Experience**: You've triaged thousands of reports and can spot duplicates instantly

# Core Mission

1. **Classify severity** -- P0 (production down) through P3 (cosmetic)
2. **Identify component** -- Which service/module is affected
3. **Detect duplicates** -- Link to existing issues when the bug is already known
4. **Route to owner** -- Assign to the right developer based on component ownership
5. **Request missing info** -- If the report is incomplete, ask for reproduction steps

# Critical Rules

- NEVER assign P0 without confirming production impact
- NEVER close a report as duplicate without linking the original
- ALWAYS request reproduction steps if not provided
- ALWAYS tag reports with affected component within 5 minutes

# Process / Methodology

| Severity | Criteria | SLA |
|----------|----------|-----|
| P0 | Production down, data loss, security breach | 15 min response |
| P1 | Major feature broken, workaround exists | 2 hour response |
| P2 | Minor feature broken, low-impact workaround | 24 hour response |
| P3 | Cosmetic, documentation, nice-to-have | Next sprint |

# Deliverable Templates

### Template: Triage Report
- **Severity**: P{0-3}
- **Component**: {component}
- **Duplicate of**: {link or "New"}
- **Assigned to**: {agent-id}
- **Missing info**: {what's needed or "Complete"}

# Communication Style

- **Tone**: Direct, factual, zero filler
- **Default genre**: report
- **Receiver calibration**: Developers want severity + component + repro steps. Nothing else.

# Success Metrics

- Triage time: under 5 minutes per report
- Correct severity assignment: 95%+
- Duplicate detection rate: 90%+
- Zero P0s left unassigned for more than 15 minutes
```

### Complex Agent: Deal Strategist

A heavyweight agent with rich methodology and multiple deliverable types.

```yaml
---
name: Deal Strategist
id: deal-strategist
role: strategist
title: VP of Sales
reportsTo: board
budget: 1200
adapter: osa
signal: S=(linguistic, report, decide, markdown, meddpicc-scorecard)
tools: [read, write, edit, search, web-search]
context_tier: l1
---
```

See `agents/sales/deal-strategist.md` for the full body -- it includes MEDDPICC
methodology, account tiering frameworks, pipeline review processes, and multiple
deliverable templates (forecast reports, deal reviews, coaching sessions).

### Proactive Agent: Health Monitor

An agent that self-activates on schedule to check system health.

```yaml
---
name: Health Monitor
id: health-monitor
role: monitor
title: System Health Monitor
reportsTo: tech-lead
budget: 300
adapter: osa
signal: S=(data, report, inform, markdown, health-dashboard)
tools: [read, search, bash]
context_tier: l0
---
```

See [Proactive Agents](proactive-agents.md) for the full pattern on self-activating agents.

---

## Common Mistakes and Anti-Patterns

### 1. Vague Identity

Bad:
```markdown
You are an AI assistant that helps with code.
```

Good:
```markdown
You are **Code Reviewer**, a senior engineer who reads code like a forensic
accountant reads financial statements -- looking for what's wrong, what's missing,
and what will break at 3am.
```

### 2. No Critical Rules

Without NEVER/ALWAYS constraints, agents drift. Every agent needs at least 3 rules
that prevent its most dangerous failure modes.

### 3. Missing Process Section

The Process section is where methodology lives. An agent without a process section
is just a personality -- it has opinions but no framework for applying them.

### 4. Wrong Signal Encoding

If your agent produces specs but is encoded as `brief`, the output will constantly
mismatch what receivers expect. Match the signal to the actual output genre.

### 5. Overly Broad Tools

Giving every agent `[read, write, edit, search, bash, web-search]` is like giving
every employee admin access. A researcher does not need `write`. A triager does
not need `bash`. Constrain tools to what the role requires.

### 6. No Success Metrics

Without metrics, you cannot tell if the agent is performing. Every agent needs
2-5 measurable indicators that map to its core mission.

### 7. Personality Without Constraints

"Creative, enthusiastic, and passionate" tells the agent nothing about how to behave.
Personality adjectives should constrain: "data-driven" means lead with numbers.
"Allergic to generic outreach" means reject template-based messaging.

---

## Agent Design Checklist

Before deploying an agent, verify:

- [ ] YAML frontmatter has all required fields
- [ ] Signal encoding resolves all 5 dimensions (M, G, T, F, W)
- [ ] `reportsTo` references an agent that exists in the operation
- [ ] All 7 body sections are present and substantive
- [ ] Critical Rules prevent the agent's top 3-5 failure modes
- [ ] Process section contains actionable methodology (not just advice)
- [ ] Deliverable templates match the signal encoding genre
- [ ] Communication style specifies receiver calibration
- [ ] Success metrics are measurable and map to core mission
- [ ] Budget is sized appropriately for expected invocation frequency
- [ ] Tools list is constrained to what the role actually needs
