---
description: Build a VSL script using one of 5 framework variants (15-step / pull-push-persuade 11-step pull-push-persuade / 13-step VSL slides / three-phase VSL formula / hidden-pitch long-form video). Cycle 2 Sales hero.
argument-hint: [optional: --variant=A|B|C|D|E or topic focus]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, WebFetch
---

# /build-vsl

Execute the VSL Builder skill.

## Instructions

Read and execute `skills/build-vsl/SKILL.md`. Follow its Process section Phases 0-12.

Upstream dependencies:
- `output/design-offer/*.md` — Offer Doc with Value Equation Score >= 150 + LTV:CAC >= 3
- `output/build-positioning/*.md` — Positioning Doc with named Mechanism
- `output/build-icp/*.md` — ICP Doc Completeness >= 80
- `output/extract-voice/*.md` — Brand Voice Doc with 15+ phrases_to_use (recommended)

If `--variant=A|B|C|D|E` provided, use that variant. Otherwise apply Variant Selection Decision Tree.

Write output to `output/build-vsl/{date}-vsl-script-{variant}.md`.

Sacred format — requires 3/3 Blind Output Test pass before paid traffic.

## Arguments

$ARGUMENTS
