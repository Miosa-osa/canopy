# Canopy v2 — Documentation Index

This index includes current contracts, historical reports, and reference material.
Classification and precedence are declared in `../agent-authority.json`.
Start with [the current product contract](./current-product-contract.md).
Completion counts below describe dated runs and do not prove the current build passes.

## Documents

### [01-foundation.md](./01-foundation.md)
**Platform Architecture, Tech Stack, Build Order**

The master synthesis. One-sentence thesis, current baseline, target state,
final tech stack with justifications, complete directory structure, build
order, migration strategy, and open decisions.

Start here.

### [02-frontend-design.md](./02-frontend-design.md)
**Design System, Screens, Component Patterns, UX Flows**

Design system specification: OKLCh token system, typography, motion, shadow
model, component primitives, pattern components, and screen-by-screen UX
breakdown. Read before writing any Svelte component.

### [05-operations.md](./05-operations.md)
**Runbook — First Setup, Daily Dev, Troubleshooting**

How to clone, install, run, reset, and debug Canopy. Port map, log locations,
how to regenerate OpenAPI types, how to recover from common errors. Read this
if anything goes sideways.

### [06-audit.md](./06-audit.md)
**Day 1 Hardening + Audit Checklist**

Quality gate procedure run on 2026-04-17 between scaffold completion and Week 1
kickoff. Automated checks, architecture audit rules, hardening requirements,
cross-doc consistency procedure. Reference for future audit gates.

### [07-day1-report.md](./07-day1-report.md)
**Day 1 Completion Record**

Formal sign-off on Week 0 scaffold + Day-1 hardening. What shipped, exit
criteria results, issues found + resolutions, deferrals with targets,
assumptions.

### [08-week1-plan.md](./08-week1-plan.md)
**Historical Week 1 Execution Plan**

Historical plan for Week 1: parallelization map, adapter-seeding logic, SessionsController
+ SSE endpoint shape, CodexLocal/GeminiLocal follow-on strategy, agent frontmatter
mapping table, day-by-day track ownership.

### [09-foundation-migration.md](./09-foundation-migration.md)
**MIOSA Foundation Migration Plan**

Plan + decisions for adopting the Miosa-osa/foundation component library.
Pill-first, glassmorphism, OKLCh ↔ hex token alias layer.

### [10-naming-ontology-audit.md](./10-naming-ontology-audit.md)
**Naming, Topology, Ontology, Foundation Audit**

Self-audit of how names/categories/layers/boundaries were chosen across backend,
frontend, Rust, protocols, and docs. Flags 8 inconsistencies with a remediation
queue ordered by impact÷effort. Read this before large renames or layer changes.

### [11-weeks-2-20-roadmap.md](./11-weeks-2-20-roadmap.md)
**Weeks 2–20 Roadmap**

Phase plan for the remaining 19 weeks: agent autonomy (Week 2), productivity
modules (Weeks 3–12), system modules (Weeks 13–17), v1.0 ship (Weeks 18–20).
Daily track breakdowns, exit criteria per week, dependency graph.

### [12-week2-report.md](./12-week2-report.md)
**Week 2 Completion Record**

Sign-off on Week 2 + Week 3 early scaffold. 13 parallel tracks, triple-stack
verify (1001 backend / 49 vitest / 11 cargo, all green), shell polish wiring,
Oban test-mode fix, deferrals with targets.

### [13-week3-report.md](./13-week3-report.md)
**Week 3 Completion Record**

Sign-off on Week 3 (workspace protocol + file ops + persona editor + seeder
polish). 7 parallel tracks, triple-stack verify, agent corpus 169 → 336,
deferrals with targets.

### [14-architecture-audit.md](./14-architecture-audit.md)
**Full Architecture Audit — 9 Parallel Streams**

Granular topology: 71 entry points mapped, 8 critical data flows traced, storage
hot/warm/cold tiers, dependency DAG, 15 failure modes, scaling cliffs at 10x/100x/
1000x, top 10 entropy hotspots, control point map, security attack surface,
tiered priority matrix.

### [15-phase2-report.md](./15-phase2-report.md)
**Phase 2 Completion Record — Audit Closure + Week 4 Polish**

Closed 7 audit findings (governance+budget gates, rate limiter, markdown RCE
chain, ghost sessions, type contract, sessions index, vault HKDF). Triple-stack
verify (1108 backend / 277 vitest / 11 cargo, all green). Shell polish landed.

### [16-phase3-report.md](./16-phase3-report.md)
**Phase 3 Completion Record — Module Backends + Self-Audit Rollback**

6 module backends (Tasks/Chat/Docs/Channels/Files/Dashboard) + Notifications
+ MCP resources/prompts + Governance RuleCache + Oban concurrency bump. 12
parallel agents dispatched, 4 tracks fully rolled back mid-phase. Triple-stack
verify: 1473 backend / 277 vitest / 11 cargo.

### [17-phase4-report.md](./17-phase4-report.md)
**Phase 4 Completion Record — Module Frontends**

6 module frontends (Tasks/Chat/Docs/Channels/Files/Dashboard) + NotificationBell
+ sidebar route flips. 6 modules moved from /coming-soon to real routes.
Triple-stack: 1473 backend / 469 vitest / 11 cargo.

### [24-workspace-engine.md](./24-workspace-engine.md)
**Workspace OptimalEngine Contract**

Workspace-local `engine/` integration, `.canopy/engine.yaml` manifest shape,
API routes, and agent/MCP tool names.

### [25-review-queue.md](./25-review-queue.md)
**Review Queue Contract**

Human review activation paths, persistence model, lifecycle, API, and `/review`
UI behavior.

---

## Contributing

See [`../CONTRIBUTING.md`](../CONTRIBUTING.md).
