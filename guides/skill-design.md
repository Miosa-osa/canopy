# Skill Design Guide

> How to create executable commands that agents can invoke inside an Operation.

---

## What Is a Skill?

A skill is a slash command that an agent can execute. Skills are the Operation's API --
the things agents can **do**, not just know.

Every skill lives in its own directory with a `SKILL.md` file:

```
skills/
├── prospect/
│   └── SKILL.md       <- /prospect command
├── build/
│   └── SKILL.md       <- /build command
├── review/
│   └── SKILL.md       <- /review command
└── deploy/
    └── SKILL.md       <- /deploy command
```

The agent discovers skills by scanning `skills/*/SKILL.md`. When a user invokes
`/prospect "Acme Corp"`, the agent reads `skills/prospect/SKILL.md` and follows
its instructions.

---

## SKILL.md Format Specification

Every SKILL.md has 6 required sections:

```markdown
# {Skill Name}

## Command
/{command} <required_arg> [--optional_flag value]

## Purpose
One sentence describing what this skill does.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| ... | ...  | ...      | ...         |

## Output
Genre: {signal genre}
Format: {output format}

Produces:
1. {deliverable 1}
2. {deliverable 2}

## Process
{Step-by-step execution instructions}

## Examples
{Usage examples with expected behavior}
```

### Section Details

**Command** -- The exact invocation syntax. Use `<angle_brackets>` for required args,
`[square_brackets]` for optional args, `--flags` for named options.

**Purpose** -- A single sentence. The agent reads this during skill discovery to
decide which skill to activate.

**Arguments** -- A table listing every argument with type, whether it is required,
and what it does. This is the skill's API contract.

**Output** -- What the skill produces. Specifies the Signal genre and format so
the agent encodes the output correctly.

**Process** -- Step-by-step instructions the agent follows. This is the core logic.
Use numbered steps, conditionals, and references to other resources.

**Examples** -- Concrete invocation examples. Agents use these to understand
expected usage patterns.

---

## How Skills Connect to the Engine

Skills bridge the gap between human intent and agent execution:

```
Human says: "/prospect Acme Corp"
  ↓
Agent reads: skills/prospect/SKILL.md
  ↓
Agent follows: Process section step by step
  ↓
Agent activates: Other agents listed in Agent Activation (if any)
  ↓
Agent produces: Output in the specified genre and format
```

### Agent Activation Within Skills

Skills can activate other agents in waves. This is how multi-agent collaboration
works within a single command:

```markdown
## Agent Activation
1. **researcher** (wave 1): Company research at specified tier
2. **prospector** (wave 2): ICP scoring + outreach plan based on research
3. **copywriter** (wave 2): Draft first-touch email based on research brief
```

Waves execute sequentially. Agents within the same wave execute in parallel.

### Reference Loading

Skills can specify which reference files to load:

```markdown
## Process
1. Load `reference/icp.md` for scoring framework
2. Load `reference/sequences.md` for outreach templates
3. ...
```

This is how skills access domain knowledge without loading everything at boot.

---

## Implementation Patterns

### Pattern 1: Simple Skill (Single Agent, No Dependencies)

A skill that one agent executes directly with no external calls.

```markdown
# Status

## Command
/status

## Purpose
Show the current state of all active work items and agent health.

## Arguments
None.

## Output
Genre: report
Format: Markdown table

Produces:
1. **Active Tasks** -- table of in-progress work items with owner, status, age
2. **Agent Health** -- table of agents with last-run time, budget remaining, error count

## Process
1. Scan `tasks/` for all files with status `in_progress` or `todo`
2. For each task, extract: id, title, assignee, status, created date
3. Calculate age (days since creation)
4. Check `logs/activity.log` for each agent's last run timestamp
5. Calculate budget remaining from cost entries
6. Format as two markdown tables
7. Flag any task older than 7 days or any agent with errors > 3

## Examples
```
/status
```
Output: Two tables -- active tasks and agent health.
```

### Pattern 2: Engine-Backed Skill (Shell Commands)

A skill that executes shell commands or interacts with external systems.

```markdown
# Deploy

## Command
/deploy <environment> [--dry-run]

## Purpose
Deploy the current build to the specified environment.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| environment | string | Yes | Target: staging, production |
| --dry-run | flag | No | Show what would happen without executing |

## Output
Genre: report
Format: Markdown

Produces:
1. **Pre-deploy checklist** -- verified conditions
2. **Deployment log** -- step-by-step execution output
3. **Post-deploy verification** -- health check results

## Process
1. Verify all tests pass: `npm test`
2. Verify build succeeds: `npm run build`
3. If `--dry-run`: show planned actions and stop
4. If `environment` is `production`:
   a. Require QA sign-off task exists and is completed
   b. Require `review_approved` evidence gate on current milestone
5. Execute deployment:
   - staging: `./scripts/deploy-staging.sh`
   - production: `./scripts/deploy-production.sh`
6. Run health checks: `./scripts/health-check.sh {environment}`
7. If health checks fail: auto-rollback via `./scripts/rollback.sh {environment}`
8. Log deployment to `logs/activity.log`

## Examples
```
/deploy staging
/deploy production --dry-run
/deploy production
```
```

### Pattern 3: Multi-Step Skill (Multi-Agent Orchestration)

A skill that coordinates multiple agents through a multi-step process.

```markdown
# Prospect

## Command
/prospect <company_name> [--tier 1|2|3]

## Purpose
Research a target company, score against ICP, and generate an outreach plan.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| company_name | string | Yes | Company to research |
| --tier | integer | No | Research depth: 1 (quick), 2 (full), 3 (deep). Default: 2 |

## Output
Genre: research-brief + outreach-plan
Format: Markdown

Produces:
1. **Company Research Brief** -- per researcher's template at specified tier
2. **ICP Score** -- 10-point scoring with evidence per criterion
3. **Outreach Plan** -- recommended sequence, angle, first-touch draft email

## Agent Activation
1. **researcher** (wave 1): Company research at specified tier
2. **prospector** (wave 2): ICP scoring + outreach plan based on research
3. **copywriter** (wave 2): Draft first-touch email based on research brief

## Process
1. Researcher builds company profile at requested tier
2. Prospector scores against ICP framework (reference/icp.md)
3. If ICP score >= 7: full outreach plan + copywriter drafts first email
4. If ICP score 5-6: abbreviated plan, flag for director review
5. If ICP score < 5: no outreach. Report findings only.

## Examples
```
/prospect "Acme Corp"
/prospect "Acme Corp" --tier 3
/prospect "Stripe" --tier 1
```
```

### Pattern 4: Conditional Skill (Branching Logic)

A skill with different execution paths based on input or state.

```markdown
# Qualify

## Command
/qualify <deal_name>

## Purpose
Score a deal using MEDDPICC and identify qualification gaps.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| deal_name | string | Yes | Name or ID of the deal to qualify |

## Output
Genre: report
Format: Markdown scorecard

Produces:
1. **MEDDPICC Scorecard** -- 8 categories scored 0-3
2. **Gap Analysis** -- weakest categories with recommended actions
3. **Verdict** -- advance, hold, or disqualify with rationale

## Process
1. Load deal context from tasks/ (find task matching deal_name)
2. Load MEDDPICC framework from reference/meddpicc.md
3. Score each dimension:
   - Metrics, Economic Buyer, Decision Criteria, Decision Process,
     Identify Pain, Champion, Competition, Paper Process
4. Calculate total score (max 24)
5. Branch on score:
   - **18-24**: Advance -- deal is well-qualified
   - **12-17**: Hold -- address gaps before advancing
   - **0-11**: Disqualify -- fundamental gaps exist
6. For each dimension scoring 0-1, generate specific action item
7. If champion dimension < 2, flag as critical risk

## Examples
```
/qualify "Acme Corp Enterprise"
/qualify "Stripe Platform Deal"
```
```

---

## Composing Skills into Workflows

Skills can be chained together as steps within a workflow. A workflow phase
might invoke one skill, then use its output as input to another:

```
Workflow: Feature Cycle
  Phase 1 (Spec): tech-lead runs /spec
  Phase 3 (Build): devs run /build (requires /spec output)
  Phase 4 (Test): QA runs /test (requires /build output)
  Phase 5 (Review): tech-lead runs /review (requires /test output)
  Phase 6 (Deploy): devops runs /deploy (requires /review approval)
```

Each skill is self-contained. The workflow defines the sequence and gates.
Skills do not call other skills directly -- the workflow orchestrates them.

---

## Skill Design Checklist

Before adding a skill to your operation:

- [ ] SKILL.md has all 6 required sections
- [ ] Command syntax is clear with proper argument notation
- [ ] Purpose is a single sentence (used for skill discovery)
- [ ] Arguments table covers every parameter with types and defaults
- [ ] Output specifies genre and format (matches Signal Theory encoding)
- [ ] Process steps are numbered, specific, and unambiguous
- [ ] Conditional branches are explicit (if X, then Y; else Z)
- [ ] Agent Activation section is present if the skill uses multiple agents
- [ ] Examples cover the common case and at least one edge case
- [ ] Error handling is specified (what happens when a step fails?)
- [ ] Reference files needed are explicitly named in the process

---

## Common Mistakes

### 1. Process Too Vague

Bad: "Research the company and generate a report."
Good: "1. Search web for company name + recent funding. 2. Check LinkedIn for headcount
and hiring patterns. 3. Score against ICP criteria in reference/icp.md."

### 2. Missing Error Paths

Every skill should define what happens when things go wrong. Add "On failure"
instructions to critical steps.

### 3. No Output Genre

Without specifying the genre, the agent guesses the output format. This causes
genre mismatches downstream when another agent receives the output.

### 4. Too Many Arguments

If a skill needs more than 5 arguments, it is probably two skills. Split it.

### 5. Skills That Call Skills

Skills should not invoke other skills. Workflow orchestration handles sequencing.
A skill that calls `/build` from within `/deploy` creates hidden dependencies.
