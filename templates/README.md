# Workspace Templates

> Starter templates for different workspace sizes. Pick the tier that matches your
> needs, copy the directory, and customize.

---

## Template Tiers

| Tier | Files | Use Case | Time to Customize |
|------|-------|----------|-------------------|
| **micro** | ~5 | Single-purpose agent (email responder, code reviewer, content writer) | 15 minutes |
| **small** | ~15 | Small team or product (2-3 agents, focused domain) | 1 hour |
| **full** | ~30 | Multi-team operation (4+ agents, workflows, governance) | 2-3 hours |
| **enterprise** | ~40+ | Large organization (teams, budgets, governance, compliance) | Half day |
| **growth-operator-agency** | 300+ | Creator-business growth operating workspace with agents, skills, workflows, reference, and runtime shims | 30-60 minutes |

---

## How to Use

### 1. Pick Your Tier

```bash
# Start with the tier that matches your scale
cp -r templates/micro/ my-operation/

# Or for a full setup
cp -r templates/full/ my-operation/

# Or for the imported Growth Operator Agency workspace
cp -r templates/growth-operator-agency/ my-growth-operation/
```

### 2. Customize SYSTEM.md

Every template includes a `SYSTEM.md` with placeholder values. Replace:
- `{{OPERATION_NAME}}` — your operation's name
- `{{MISSION}}` — one-line mission statement
- `{{DOMAIN}}` — your domain (engineering, sales, consulting, etc.)
- Agent names and roles to match your team

### 3. Configure Agents

Each agent file has YAML frontmatter + markdown body following the standard
in `protocol/agent-format.md`. Customize:
- Identity and personality
- Critical rules for your domain
- Process/methodology specific to your workflows
- Deliverable templates your team actually uses

### 4. Configure Skills

Skills are slash commands your agents can invoke. Each skill has:
- `SKILL.md` defining usage, implementation steps, and examples
- Customize for your toolchain, repos, and deployment targets

### 5. Validate

```bash
/validate my-operation/
```

This checks: SYSTEM.md structure, YAML frontmatter validity, agent cross-references,
Signal encoding completeness, and workflow phase references.

---

## Tier Details

### micro (~5 files)

```
micro/
├── SYSTEM.md              # Minimal system prompt
├── agents/
│   └── worker.md          # Single agent definition
└── skills/
    └── do/
        └── SKILL.md       # One skill: the agent's primary action
```

Best for: Single-purpose bots. Email responder. Code reviewer. Meeting summarizer.
No governance, no workflows, no budgets. Just one agent doing one thing well.

### small (~15 files)

```
small/
├── SYSTEM.md              # System prompt with routing
├── company.yaml           # Basic company config
├── agents/
│   ├── lead.md            # Lead agent (orchestrator)
│   └── specialist.md      # Specialist agent
├── skills/
│   ├── primary/
│   │   └── SKILL.md       # Main workflow skill
│   ├── search/
│   │   └── SKILL.md       # Knowledge search
│   └── report/
│       └── SKILL.md       # Reporting skill
├── reference/
│   ├── domain.md          # Domain knowledge
│   └── standards.md       # Quality standards
├── handoffs/
│   └── lead-to-specialist.md
└── workflows/
    └── default.yaml       # Single workflow
```

Best for: Small teams. A lead + specialist setup with basic routing. Simple
governance through the lead agent. One workflow.

### full (~30 files)

```
full/
├── SYSTEM.md              # Full system prompt
├── company.yaml           # Company config with budgets
├── agents/
│   ├── director.md        # Director (orchestrator)
│   ├── engineer.md        # Engineering agent
│   ├── analyst.md         # Analysis agent
│   └── writer.md          # Content/docs agent
├── skills/
│   ├── primary/
│   │   └── SKILL.md
│   ├── search/
│   │   └── SKILL.md
│   ├── build/
│   │   └── SKILL.md
│   ├── review/
│   │   └── SKILL.md
│   ├── report/
│   │   └── SKILL.md
│   ├── deploy/
│   │   └── SKILL.md
│   ├── analyze/
│   │   └── SKILL.md
│   └── summarize/
│       └── SKILL.md
├── reference/
│   ├── domain.md
│   ├── standards.md
│   ├── architecture.md
│   └── glossary.md
├── handoffs/
│   └── inter-agent.md
└── workflows/
    ├── sprint.yaml
    └── review.yaml
```

Best for: Multi-team operations. 4 agents with clear ownership. 8 skills covering
the full development cycle. Workflows for sprints and reviews.

### enterprise (~40+ files)

```
enterprise/
├── SYSTEM.md              # Enterprise system prompt
├── company.yaml           # Full company config
├── agents/
│   ├── cto.md             # CTO (top-level orchestrator)
│   ├── engineering-lead.md
│   ├── product-lead.md
│   ├── security-lead.md
│   ├── engineer.md
│   └── analyst.md
├── skills/
│   ├── (8 skill directories)
│   └── ...
├── reference/
│   ├── domain.md
│   ├── standards.md
│   ├── architecture.md
│   ├── glossary.md
│   ├── compliance.md
│   └── runbooks.md
├── governance/
│   ├── approval-gates.md
│   ├── escalation.md
│   └── audit-policy.md
├── budgets/
│   ├── company.yaml
│   └── team-allocations.yaml
├── handoffs/
│   └── inter-agent.md
└── workflows/
    ├── sprint.yaml
    ├── review.yaml
    ├── incident.yaml
    └── onboarding.yaml
```

Best for: Organizations with compliance requirements, multiple teams, budget
tracking, and formal governance. Includes approval gates, audit trails, and
escalation procedures.

### growth-operator-agency (full imported workspace)

```
growth-operator-agency/
├── SYSTEM.md
├── company.yaml
├── agents/              # 41 growth agency personas
├── skills/              # 39 artifact-producing skills
├── reference/           # frameworks, swipe files, templates, vertical packs
├── workflows/           # launches, delivery, handoffs, automations
├── spec/                # banned vocabulary, context thresholds, runtime rules
├── prompts/             # prompt libraries by domain
└── .claude/commands/    # Claude Code slash-command shims
```

Best for: Creator-led info, coaching, consulting, course, community, and digital
product businesses that need a complete growth operating workspace. Start by
copying the template and filling in `company.yaml`.

---

## Upgrading Between Tiers

You can start small and grow:

1. **micro → small**: Add `company.yaml`, a second agent, routing in SYSTEM.md
2. **small → full**: Add more agents, skills, reference docs, second workflow
3. **full → enterprise**: Add governance/, budgets/, compliance reference, security agent

Each tier is a superset of the previous. No structural changes needed — just additions.

---

*Templates v1.0 — OSA Operations workspace starters*
