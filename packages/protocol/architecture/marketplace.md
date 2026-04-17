# Marketplace — Workspace Templates & Distribution

> "Download a company." The marketplace distributes complete organizational templates:
> agent configurations, org charts, workflows, seed tasks, budget defaults, and domain
> knowledge — everything needed to deploy a working agent team.

---

## Overview

The marketplace solves the cold-start problem. Without it, every new workspace starts
from scratch: manually defining agents, org charts, workflows, budgets. The marketplace
provides pre-built templates that can be installed, customized, and running in minutes.

The core abstraction is the **Operation bundle** — a portable, versioned package containing
everything needed to deploy an AI-powered organization.

---

## What You Can Download

| Product Type | What It Contains | Example |
|-------------|-----------------|---------|
| **Company template** | Complete org chart, all agents, workflows, budget defaults, seed tasks, reference knowledge | "Lean Dev Shop" (CTO + 3 engineers + QA) |
| **Agent blueprint** | Single agent config: role, system prompt, adapter config, skills | "Senior TypeScript Engineer" |
| **Team template** | Org chart subtree with related agents | "Marketing Team: CMO + Content Writer + SEO Analyst" |
| **Skill pack** | Collection of engine-backed skills | "Engineering Skill Pack" (deploy, test, review) |
| **Workflow template** | Single workflow pipeline | "Sprint Workflow" (plan → dev → QA → deploy) |
| **Governance template** | Approval gates, escalation rules, budget policies | "Startup Governance" (minimal gates, high autonomy) |

---

## Bundle Format

```
operation-bundle.zip
├── manifest.yaml           # Metadata: version, author, pricing, compatibility
├── company.yaml            # Company definition: name, mission, budget, goals
├── SYSTEM.md               # Agent system entry point (boot sequence, core loop)
│
├── agents/                 # Agent definitions (YAML frontmatter + markdown body)
│   ├── ceo.md
│   ├── cto.md
│   └── {role}.md
│
├── skills/                 # Engine-backed slash commands
│   └── {skill-name}/
│        ├── SKILL.md
│        └── impl.ex
│
├── reference/              # Domain knowledge files
│   ├── {domain}.md
│   └── {domain}.yaml
│
├── workflows/              # Orchestration pipelines
│   └── {workflow}.yaml
│
├── handoffs/               # Handoff templates for phase transitions
│   └── {handoff-type}.md
│
├── tasks/                  # Seed tasks (optional starter work)
│   └── {ISSUE_PREFIX}-{n}.yaml
│
└── examples/               # Sample inputs/outputs
    └── {scenario}.md
```

---

## manifest.yaml Schema

```yaml
name: string                              # Display name
slug: string                              # URL-safe identifier
version: "1.0.0"                          # Semantic versioning
description: string                       # One-paragraph description
price_usd: 0                              # 0 = free, max 499

author:
  name: string
  id: string
  url: string

tags: [string]                            # Discovery tags
category: string                          # Primary category (see Categories)

adapter_compatibility:
  - osa
  - claude_local
  - openclaw_gateway
  - cursor

min_osa_version: "1.0.0"

changelog:
  - version: "1.0.0"
    date: "2026-03-18"
    notes: "Initial release"

dependencies:
  - slug: "base-engineering-skills"
    version: ">=1.0.0"

# Secret requirements (declared, never stored in bundle)
secrets_required:
  - key: "ANTHROPIC_API_KEY"
    description: "API key for Claude models"
    required: true
  - key: "GITHUB_TOKEN"
    description: "GitHub access for repo operations"
    required: false

# Warnings surfaced during import
warnings:
  - "This bundle requires Claude API access ($50-200/month estimated)"
  - "Seed tasks assume a TypeScript codebase"
```

---

## Export Modes

### Template Export (Default)

Structure only. The blueprint for spinning up a new company.

**Includes:** Agent definitions, org chart, adapter configs, workflows, seed tasks,
budget defaults, reference files, skills.

**Excludes:** In-progress tasks, historical cost data, run logs, session state,
agent runtime state, secrets.

### Snapshot Export

Full state. A complete picture you could restore or fork.

**Includes:** Everything in template, PLUS current task states, agent status,
aggregated cost data, session metadata (not raw conversation state).

---

## Import Flow

```
Download bundle
  │
  ▼
┌───────────────────┐
│ 1. PREVIEW        │ ← Dry-run: show what will be created, flag collisions
│    (dry-run)      │   No mutations. Human reviews before proceeding.
└────────┬──────────┘
         ▼
┌───────────────────┐
│ 2. VALIDATE       │ ← Schema check, adapter compatibility, dependency resolution
└────────┬──────────┘
         ▼
┌───────────────────┐
│ 3. COLLISION       │ ← Handle conflicts with existing agents, tasks, workflows
│    HANDLING        │   Options: skip, overwrite, rename, merge
└────────┬──────────┘
         ▼
┌───────────────────┐
│ 4. SECRET          │ ← Prompt for required secrets (API keys, tokens)
│    REQUIREMENTS    │   Secrets are never stored in the bundle.
└────────┬──────────┘
         ▼
┌───────────────────┐
│ 5. SCAFFOLD        │ ← Create company, agents, workspaces, task hierarchy
└────────┬──────────┘
         ▼
┌───────────────────┐
│ 6. CUSTOMIZE       │ ← User adjusts budgets, modifies agents, sets API keys
└────────┬──────────┘
         ▼
┌───────────────────┐
│ 7. DEPLOY          │ ← Start heartbeats, fire CEO's first run
└───────────────────┘
```

### Validation Checks

| Check | What It Verifies |
|-------|-----------------|
| Schema validity | manifest.yaml, company.yaml, agent frontmatter all parse |
| Org chart integrity | All `reportsTo` references resolve, no cycles |
| Signal encoding | All agent signal fields have 5 dimensions |
| Adapter compatibility | Required adapters available on target instance |
| Dependency resolution | Required dependency bundles installed |
| Version compatibility | Bundle version compatible with target OSA version |
| Workflow references | All workflow agent references resolve |

### Collision Handling

When importing into an existing workspace:

| Collision Type | Options |
|---------------|---------|
| Agent slug exists | Skip (keep existing), Overwrite, Rename (append suffix) |
| Task ID exists | Skip, Overwrite, Re-number |
| Workflow name exists | Skip, Overwrite, Rename |
| Reference file exists | Skip, Overwrite, Merge (append) |

---

## Categories

| Category | Examples |
|----------|---------|
| **Software Development** | Full-stack dev shop, API team, mobile studio |
| **Marketing & Growth** | Performance marketing, content marketing, SEO |
| **Content & Media** | Content studio, podcast production, newsletter |
| **Research & Analysis** | Market research, competitive intelligence, data |
| **Operations** | Customer support, internal ops, QA/testing |
| **Sales** | Sales team, deal pipeline, outbound agency |
| **Finance** | Bookkeeping, financial analysis, budgeting |
| **Creative** | Design team, brand studio, video production |

---

## Versioning

Bundles follow semantic versioning:

| Component | When to Bump | Example |
|-----------|-------------|---------|
| **MAJOR** | Breaking: agent signature changes, removed skills, schema changes | 1.0.0 → 2.0.0 |
| **MINOR** | Additive: new agents, workflows, skills, reference files | 1.0.0 → 1.1.0 |
| **PATCH** | Fixes: typo corrections, prompt improvements, config tweaks | 1.0.0 → 1.0.1 |

### Forking with Lineage

When a user forks a bundle, lineage is preserved:

```yaml
forked_from:
  slug: "lean-dev-shop"
  version: "1.2.0"
  author: "original-author"
  forked_at: "2026-03-18"
```

This enables tracing the evolution of organizational patterns.

---

## Discovery

### Search Dimensions

| Dimension | Filter Type |
|-----------|------------|
| Text query | Semantic + keyword on name, description, tags |
| Category | Dropdown |
| Agent count | Range (1-5, 6-15, 15+) |
| Adapter types | Multi-select |
| Price range | Range slider |
| Rating / stars | Minimum threshold |
| Recency | Sort by last updated |

---

## Pricing Model

| Tier | Range | What You Get |
|------|-------|-------------|
| **Free** | $0 | Full bundle, community support |
| **Basic** | $1-$49 | Full bundle, author support |
| **Professional** | $50-$199 | Full bundle, priority support, 1yr updates |
| **Enterprise** | $200-$499 | Full bundle, custom support, SLA |

**What you're buying:** A template — pre-built org structure, tested configs, proven
workflows, domain knowledge, seed tasks.

**What you're NOT buying:** API keys, hosting, infrastructure, ongoing execution, data.

---

## Publishing

Anyone with a GitHub account can publish. Export from a running Operation:

```bash
# Export
mix optimal.bundle export --output ./my-operation-v1.0.0.zip

# Publish
mix optimal.marketplace publish ./my-operation-v1.0.0.zip \
  --slug "my-dev-shop" \
  --category "Software Development" \
  --price 0

# Update
mix optimal.marketplace publish ./my-operation-v1.1.0.zip \
  --slug "my-dev-shop" \
  --changelog "Added QA agent"
```

---

## Related Docs

- [heartbeat.md](heartbeat.md) — How imported agents execute
- [adapters.md](adapters.md) — Adapter compatibility requirements
- [governance.md](governance.md) — Governance templates in bundles
- [budgets.md](budgets.md) — Budget defaults in company.yaml
- [tasks.md](tasks.md) — Seed tasks in bundles

---

*Operations Marketplace v2.0 — Download a company, customize it, deploy it*
