# Library -- Reusable Agents and Skills

A catalog of agent definitions and skill definitions that can be composed into
any workspace. Pick what you need, copy it into your operation's `agents/` or
`skills/` directory, and customize.

## Agents (380 definitions, 14 categories)

```
library/agents/
├── academic/           ├── marketing/          ├── sales/
├── design/             ├── paid-media/         ├── spatial-computing/
├── engineering/        ├── product/            ├── specialized/
├── game-development/   ├── project-management/ ├── support/
├── testing/
└── growth-operator-agency/
```

Each agent is a markdown file with YAML frontmatter following the standard in
`protocol/agent-format.md`. Agents define identity, core rules, process,
deliverables, communication style, and success metrics.

## Skills (174 definitions, 19 categories)

```
library/skills/
├── agent/        ├── development/   ├── operations/   ├── strategy/
├── ai-patterns/  ├── knowledge/     ├── search/       ├── workflow/
├── content/      ├── learning/      ├── security/
├── growth-operator-agency/
└── matt-pocock/
```

Each skill is a `SKILL.md` file that defines usage, implementation steps, and
examples. Skills are the command interface between the agent and the underlying
engine or toolchain.

## Usage

```bash
# Copy agents into your workspace
cp library/agents/technology/software-engineering/application-development/tech-lead.md my-operation/agents/

# Copy skills into your workspace
cp -r library/skills/development/build/ my-operation/skills/

# Copy the Growth Operator Agency skill pack into a workspace
cp -r library/skills/growth-operator-agency/* my-operation/skills/

# Copy the Growth Operator Agency agents into a workspace
cp library/agents/growth-operator-agency/*.md my-operation/agents/
```

---

## Imported Workspace Packs

### Growth Operator Agency

Imported from `https://github.com/Heuresis/Growth-Operator-Agency`.

- Full workspace template: `templates/growth-operator-agency/`
- Ready operation copy: `operations/growth-operator-agency/`
- Agent library slice: `library/agents/growth-operator-agency/`
- Skill library slice: `library/skills/growth-operator-agency/`
- Team manifest: `library/teams/growth-operator-agency.md`
- Growth department manifest: `library/departments/growth/growth-operator-agency.md`

### Matt Pocock Skills

Imported from `https://github.com/mattpocock/skills`.

- Skill library slice: `library/skills/matt-pocock/`

---

*Library v1.1 -- 380 agents, 174 skills*
