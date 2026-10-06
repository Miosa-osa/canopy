# Canopy Import Notes

This template imports the Growth Operator Agency workspace from:

https://github.com/Heuresis/Growth-Operator-Agency

## What It Is

Growth Operator Agency is a full workspace-protocol package for creator-led info,
coaching, consulting, course, community, and digital product businesses.

It ships with:

- `SYSTEM.md` as the workspace boot file
- `company.yaml` as the creator business context profile
- 41 agent personas under `agents/`
- 39 skill packages under `skills/`
- Reference knowledge under `reference/`
- Operational workflows under `workflows/`
- Quality gates under `spec/`
- Claude slash-command shims under `.claude/commands/`
- Paperclip-compatible runtime manifest in `paperclip.manifest.yaml`

## Canopy Placement

This directory is the reusable template copy. To create a live workspace:

```bash
cp -R templates/growth-operator-agency operations/<creator-or-brand-name>
```

Then edit `operations/<creator-or-brand-name>/company.yaml` with the actual creator/business context.

## Library Slices

The same import is also exposed as reusable Canopy library components:

- `library/agents/growth-operator-agency/`
- `library/skills/growth-operator-agency/`
- `library/teams/growth-operator-agency.md`
- `library/departments/growth/growth-operator-agency.md`

Use the template when you want the whole agency workspace. Use the library slices when composing a custom Canopy operation.
