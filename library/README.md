# Library -- Reusable Agents and Skills

A catalog of agent definitions and skill definitions that can be composed into
any workspace. Pick what you need, copy it into your operation's `agents/` or
`skills/` directory, and customize.

## Agents (159 definitions, 13 categories)

```
library/agents/
├── academic/           ├── marketing/          ├── sales/
├── design/             ├── paid-media/         ├── spatial-computing/
├── engineering/        ├── product/            ├── specialized/
├── game-development/   ├── project-management/ ├── support/
└── testing/
```

Each agent is a markdown file with YAML frontmatter following the standard in
`protocol/agent-format.md`. Agents define identity, core rules, process,
deliverables, communication style, and success metrics.

## Skills (76 definitions, 11 categories)

```
library/skills/
├── agent/        ├── development/   ├── operations/   ├── strategy/
├── ai-patterns/  ├── knowledge/     ├── search/       ├── workflow/
├── content/      ├── learning/      ├── security/
```

Each skill is a `SKILL.md` file that defines usage, implementation steps, and
examples. Skills are the command interface between the agent and the underlying
engine or toolchain.

## Usage

```bash
# Copy agents into your workspace
cp library/agents/engineering/tech-lead.md my-operation/agents/

# Copy skills into your workspace
cp -r library/skills/development/build/ my-operation/skills/
```

---

*Library v1.0 -- 159 agents, 76 skills*
