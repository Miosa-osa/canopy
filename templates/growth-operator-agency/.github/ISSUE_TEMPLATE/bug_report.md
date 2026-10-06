---
name: Bug report
about: Something in the template does not work as documented
title: "[bug] "
labels: bug
assignees: ''
---

## What happened

A clear, concrete description. What skill or file or runtime surface broke.

## What I expected

What the documented behavior says should happen.

## Repro

Minimal steps to reproduce. Include the skill slug, runtime, and any relevant commands.

1.
2.
3.

## Runtime

- [ ] slash-command runtime
- [ ] workspace manifests
- [ ] Codex
- [ ] Cursor
- [ ] OpenClaw
- [ ] Generic LLM (specify below)

Runtime version / model:

## Workspace version

Growth Operating Agency version from `CHANGELOG.md` or the `README.md` header:

## Relevant files

Paths to the files involved (e.g. `skills/design-offer/SKILL.md:123`).

## Evidence

Logs, screenshots, `output/` artifacts, or `evidence/` entries that show the failure. Do not paste filled `company.yaml` values or any `_private/` contents — per [INV-11](../INVARIANTS.md) creator data stays local.

## Severity

- [ ] Blocks first run
- [ ] Skill produces wrong output
- [ ] Quality gate misfires
- [ ] Documentation drift
- [ ] Other

## Additional context

Anything else relevant — related skills, recent changes, runtime quirks.
