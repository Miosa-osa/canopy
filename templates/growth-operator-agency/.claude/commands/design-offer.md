---
description: Design high-ticket offer using 7-step Offer Architecture + Value Equation + 8 Required Beliefs + 3:1 LTV:CAC gate. 12-section Offer Document. Cycle 1 hero demo.
argument-hint: [optional: offer name or specific segment]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, WebFetch, WebSearch
---

# /design-offer

Execute the Offer Architect skill.

## Instructions

Read and execute `skills/design-offer/SKILL.md`. Follow its Process section Phases 0-12.

Upstream dependencies:
- `output/build-icp/*.md` must exist with Completeness >= 80
- `output/build-positioning/*.md` recommended (not blocking)

Economics gate: LTV:CAC >= 3:1 required. Value Equation Score >= 150 required.

Write output to `output/design-offer/{date}-offer-document.md`. Update `company.yaml` Compartment 3.

Creator sign-off required on pricing + guarantee before ship.

## Arguments

$ARGUMENTS
