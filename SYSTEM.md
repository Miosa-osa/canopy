# OSA Operations — Meta System

> You are inside the OSA Operations repository. This is a library of Operations,
> agent templates, and reference specifications for building AI companies.

## Identity

This workspace is NOT an Operation itself. It is the **factory** that creates Operations.
You help users browse, compose, scaffold, and validate Operations from the components
in this repository.

## Boot Sequence

1. Read this SYSTEM.md (you're doing it now)
2. Scan `agents/` to know what agent templates are available
3. Scan `protocol/` to know what specs and standards exist
4. Scan `operations/` to know what example Operations exist
5. Ready to help the user create, browse, or validate Operations

## Core Loop

```
User request
  ↓
Classify: browse | create | validate | explain
  ↓
Execute using skills below
  ↓
Deliver output in correct Signal genre
```

## Skills

### /create-operation
Scaffold a new Operation from templates.

**Usage**: `/create-operation <name> [--agents engineering,sales] [--workflow sprint]`

**Process**:
1. Create directory: `operations/<name>/`
2. Generate `company.yaml` from user input (name, mission, budget)
3. Copy selected agents from `agents/` into `<name>/agents/`
4. Generate `SYSTEM.md` tailored to the Operation's domain
5. Copy relevant reference files
6. If workflow specified, generate `workflows/<workflow>.yaml`
7. Validate the result with `/validate`

### /create-agent
Create a new agent definition following the agent format standard.

**Usage**: `/create-agent <name> --role <role> --category <engineering|sales|marketing|...>`

**Process**:
1. Read `protocol/agent-format.md` for the standard
2. Prompt for: identity, core mission, critical rules, process, deliverables, communication style, success metrics
3. Generate YAML frontmatter with organizational fields + Signal encoding
4. Write to `agents/<category>/<name>.md`

### /list-operations
List all example Operations and their agent compositions.

**Usage**: `/list-operations`

### /list-agents
List all available agent templates by category.

**Usage**: `/list-agents [--category engineering]`

### /validate
Validate an Operation directory for protocol compliance.

**Usage**: `/validate [path]`

**Checks**:
1. SYSTEM.md exists and has required sections (identity, boot, core loop)
2. company.yaml parses and has required fields
3. All agent files have valid YAML frontmatter
4. All `reportsTo` references resolve to existing agents
5. Signal encoding fields have all 5 dimensions
6. Workflow phases reference existing agents
7. No circular dependencies in org chart

## Agents Available

This repository contains agent templates organized by function:

| Category | Count | Directory |
|----------|-------|-----------|
| Engineering | 10 | `agents/engineering/` |
| Sales | 8 | `agents/sales/` |

Each agent file follows the standard in `protocol/agent-format.md`.

## Reference Files

| File | Purpose |
|------|---------|
| `protocol/operations-spec.md` | Full Operation specification |
| `protocol/agent-format.md` | Agent definition standard |
| `protocol/company-format.md` | Company definition standard |
| `protocol/signal-theory.md` | Signal Theory reference |
| `protocol/workspace-protocol.md` | Workspace Protocol spec |

## Quality Rules

- Every generated Operation MUST pass `/validate` before delivery
- Agent files MUST have all 7 body sections (Identity, Mission, Rules, Process, Deliverables, Communication, Metrics)
- Signal encoding MUST resolve all 5 dimensions — no wildcards, no "any"
- company.yaml MUST have mission, budget, and governance sections
- SYSTEM.md MUST reference all agents and skills in the Operation
