# Canopy v2 — Documentation Index

These six documents are the authoritative source of truth for Canopy v2.
Read them before touching any code. They supersede any informal notes or
comments in the codebase.

Docs 01–04 are **design authority** (what we're building and why).
Docs 05–06 are **session authority** (how we operate + how Day 1 closed).

## Documents

### [01-foundation.md](./01-foundation.md)
**Platform Architecture, Tech Stack, Build Order**

The master synthesis. Covers the one-sentence thesis, current baseline, target
state, competitor synthesis (what lands where), final tech stack with
justifications, complete directory structure, 6-week build order, migration
strategy from canopy-legacy, and the 4 decisions Roberto needs to make.

Start here.

### [02-frontend-design.md](./02-frontend-design.md)
**Design System, Screens, Component Patterns, UX Flows**

Design system specification: OKLCh token system, typography, motion, shadow
model, component primitives (shadcn-svelte), pattern components, and
screen-by-screen UX breakdown. Read before writing any Svelte component.

### [03-steal-synthesis.md](./03-steal-synthesis.md)
**Competitor Patterns — Every Decision Documented**

For each of the 6 competitors (Cabinet, Multica, Core-OSS, SuperHQ,
Gradient-bang, Paperclip): what we lift, what we adapt, what we reject, and
why. Includes explicit ADAPT notes where we diverge from the source.

Cross-reference with NOTICE.md for attribution requirements.

### [04-platform-breakdown.md](./04-platform-breakdown.md)
**Full Feature Inventory with Provenance**

Every feature in Canopy v2 tagged with its source (original, Cabinet, Multica,
Core-OSS, SuperHQ, Gradient-bang, Paperclip, or novel synthesis). Covers all
19 modules with complete feature lists. Use this to answer "does Canopy have X?"

### [05-operations.md](./05-operations.md)
**Runbook — First Setup, Daily Dev, Troubleshooting**

How to clone, install, run, reset, and debug Canopy. Port map, log locations,
how to regenerate OpenAPI types, how to recover from common errors. Read this
if anything goes sideways.

### [06-audit.md](./06-audit.md)
**Day 1 Hardening + Audit Checklist**

Quality gate procedure run on 2026-04-17 between scaffold completion and Week 1
kickoff. Automated checks, architecture audit rules, hardening requirements,
cross-doc consistency procedure. Reference for future audit gates (Week 1 exit,
Week 6 ship gate, etc.).

### [07-day1-report.md](./07-day1-report.md)
**Day 1 Completion Record**

The formal sign-off on Week 0 scaffold + Day-1 hardening. What shipped, exit
criteria results, issues found + resolutions (all 14 in-band), deferrals with
targets, assumptions. Archive of how we closed Day 1.

### [08-week1-plan.md](./08-week1-plan.md)
**Week 1 Execution Plan — Live**

Live plan for Week 1: parallelization map, adapter-seeding logic, SessionsController
+ SSE endpoint shape, CodexLocal/GeminiLocal follow-on strategy, agent frontmatter
mapping table, day-by-day track ownership.

### [09-foundation-migration.md](./09-foundation-migration.md)
**MIOSA Foundation Migration Plan**

Plan + decisions for replacing shadcn-svelte primitives with Miosa-osa/foundation
component library. Pill-first, glassmorphism, OKLCh ↔ hex token alias layer.

### [10-naming-ontology-audit.md](./10-naming-ontology-audit.md)
**Naming, Topology, Ontology, Foundation Audit**

Self-audit of how names/categories/layers/boundaries were chosen across backend,
frontend, Rust, protocols, and docs. Flags 8 inconsistencies with a remediation
queue ordered by impact÷effort. Read this before large renames or layer changes.

---

## Third-Party Attributions

See [`../NOTICE.md`](../NOTICE.md) for lifted patterns and their license status.

## Contributing

See [`../CONTRIBUTING.md`](../CONTRIBUTING.md).
