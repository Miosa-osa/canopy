# Skills

This directory contains executable skill definitions for the Sales Engine workspace.

## Skill Format

Each skill lives in its own subdirectory with a `SKILL.md` file:

```
skills/
├── prospect/
│   └── SKILL.md
├── outreach/
│   └── SKILL.md
└── followup/
    └── SKILL.md
```

## Available Skills

Add skill subdirectories here. Each `SKILL.md` must define:
- **Command** — the slash command (e.g. `/prospect`)
- **Description** — what it does
- **Usage** — how to invoke it
- **Implementation** — the steps the agent executes
