---
description: Design funnel architecture using one of 7 archetypes (VSL / Webinar / Application / Book-a-Call / Tripwire / Challenge / Community LM). Stage-by-stage blueprint with KPIs, tracking, dependencies, economics cross-validation.
argument-hint: [optional: --archetype=1-7 or business model hint]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# /build-funnel

Execute the Funnel Architect skill.

## Instructions

Read and execute `skills/build-funnel/SKILL.md`. Follow its Process section Phases 0-9.

Upstream dependencies:
- `output/design-offer/*.md` — Offer Doc (gate-passed)
- `output/build-positioning/*.md`
- `output/build-icp/*.md`
- `output/build-vsl/*.md` — if selecting Archetype 1 or 2 (VSL-based archetypes)

Apply Archetype Selection Decision Tree based on offer price tier, creator resources, audience awareness level, and existing sales team.

Write output to `output/build-funnel/{date}-funnel-blueprint-archetype-{N}.md`.

Economics gate: LTV:CAC must remain >= 3:1 (cross-check against Offer Doc).

## Arguments

$ARGUMENTS
