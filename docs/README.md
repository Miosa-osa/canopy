# Canopy documentation

Start with the current contracts and development guide below.
[The authority registry](../agent-authority.json) owns document classification and precedence.
This index does not turn historical plans into active requirements.

## Current contracts and guidance

| Document | Use it for |
|----------|------------|
| [Agent operating protocol](../CLAUDE.md) | Boot procedure, ownership, engineering rules |
| [Current product contract](current-product-contract.md) | Product scope, implementation evidence, readiness limits |
| [Development and verification](development.md) | Setup, browser/native development, tests, builds, generated types |
| [Desktop guide](../desktop/README.md) | Frontend commands, SPA behavior, browser limitations |
| [Workspace Engine](24-workspace-engine.md) | Pinned local checkout, manifest, preflight, API/tool execution |
| [Review queue](25-review-queue.md) | Canopy operational approval lifecycle; distinct from Engine Claim-to-Fact review |
| [Agent control plane](agent-control-plane.md) | Findings 1-6, fixtures A-G, coverage evidence, review policy, retest commands |
| [Contributing](../CONTRIBUTING.md) | Branches, validation, and independent review |
| [Engineering notes](../NOTES.md) | Dated decisions and verification records |

## Historical evidence

All numbered documents below 24 and all `wiring/` reports are historical in the registry.
Use them to understand prior plans and measurements, not to select current setup commands, permission rules, or product claims.
In particular, [05-operations.md](05-operations.md) contains obsolete setup and generation instructions; use [development.md](development.md) instead.
The old [Engine integration proposal](../wiring/optimal-engine-integration.md) is explicitly superseded by the current workspace Engine contract.

| Historical document | Original subject |
|---------------------|------------------|
| [01-foundation](01-foundation.md) | Architecture, planned build order, historical coverage targets |
| [02-frontend-design](02-frontend-design.md) | Original screen and design-system plan |
| [05-operations](05-operations.md) | Earlier local operations runbook |
| [06-audit](06-audit.md) | April hardening checklist |
| [07-day1-report](07-day1-report.md) | Day-one completion record |
| [08-week1-plan](08-week1-plan.md) | Original execution plan |
| [09-foundation-migration](09-foundation-migration.md) | UI foundation migration plan |
| [10-naming-ontology-audit](10-naming-ontology-audit.md) | Earlier terminology audit |
| [11-weeks-2-20-roadmap](11-weeks-2-20-roadmap.md) | Broader module roadmap, now parked |
| [12-week2-report](12-week2-report.md) | Dated completion and test counts |
| [13-week3-report](13-week3-report.md) | Dated workspace and file-operation report |
| [14-architecture-audit](14-architecture-audit.md) | Earlier architecture assessment |
| [15-phase2-report](15-phase2-report.md) | Earlier hardening report |
| [16-phase3-report](16-phase3-report.md) | Module backend report |
| [17-phase4-report](17-phase4-report.md) | Module frontend report |
| [18-wiring-audit](18-wiring-audit.md) | Earlier integration assessment |
| [19-runtime-e2e-trace](19-runtime-e2e-trace.md) | Dated runtime trace |
| [23-runtime-e2e-matrix](23-runtime-e2e-matrix.md) | Dated runtime verification matrix |

The previously cited attribution and feature-inventory documents, numbered 03 and 04, are absent.
They are not mandatory boot dependencies and must not be treated as current authority.
Use [../NOTICE.md](../NOTICE.md) for attribution and the current product contract for scope.
