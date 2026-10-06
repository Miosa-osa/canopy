# Changelog — Growth Operating Agency

All notable changes to this template are tracked here. Format follows [Keep a Changelog](https://keepachangelog.com). Versioning follows [Semantic Versioning](https://semver.org).

## [1.0.0] — 2026-04-21

Initial private release of the Growth Operating Agency workspace template.

### Added

- `SYSTEM.md` — identity, boot sequence, routing architecture, skills catalog, agent roster, spec, encoding flywheel.
- `INVARIANTS.md` — 14 sacred rules (NEVER / ALWAYS) enforced at every skill invocation, plus S/N root objective.
- `ENCODING.md` — 11-compartment Creator Context Profile schema, weighted per Impact Distribution Principle.
- `company.yaml` — clean-template configuration file with every compartment scaffolded and empty, ready for a creator fill.
- `.env.template` — credential template covering LLM, research, ads, email, CRM, funnel, analytics services.
- **29 shipped skills** across 7 departments — Foundations (5), Marketing (7), Nurture (4), Sales (3), Launch (2), Scale (5), Partnerships (3). Each skill is a folder with `SKILL.md`, `reference/`, `examples/`, `evidence/`, and `adapters/`.
- **41 agents** — 1 orchestrator (`growth-ceo`), 7 department heads, 33 specialists. Each has declarative frontmatter, reporting chain, and skills array.
- **Spec (8 files)** — Signal Theory, Quality, Runtimes, Banned Vocabulary, Blind Output Test, Context Thresholds, Integrations, HTTP/OpenAPI adapter contract.
- **Reference library** — frameworks (Signal Theory, classical, primitives, operator-specific), operators (17 encoded playbooks + 1 external), platforms (Instagram, LinkedIn, Meta Ads, TikTok, X), swipe-file, templates, examples, AGENT-ARCHITECTURE (82KB).
- **Workflows** — departments (7 mermaid FSMs), client-onboarding (week-1 + 90-day), delivery (4-week fulfillment), execution-templates (7), automations (5 playbooks).
- **Operations** — team leadership, collaboration, hiring, cadences (daily / weekly / monthly / quarterly), finance schema, dashboards, crisis management, tool SOPs, mode-of-operations.
- **Handoffs** — skill-to-skill, standard, quality-revision.
- **.claude/commands/** — 29 slash-command bindings (1:1 with skills).
- **Adapters** — slash-command runtime (`.md`) + the workspace manifest (`.yaml`) shipped for every skill.

### Repository hygiene

- `.gitignore` — covers `.DS_Store`, credentials, runtime outputs, creator-encoded data, build artifacts.
- `LICENSE` — MIT.
- `.github/SECURITY.md` — credential handling and `_private/` data contract.
- `.github/CONTRIBUTING.md` — internal contribution workflow.
- `docs/PROVENANCE.md` — authorship, foundational sources, theoretical roots.

### Known next steps

- HTTP / OpenAPI adapter skeleton per Sacred-Format skill (v1.1).
- Blind Output Test live evaluator runs, replacing `pending` status in each `skills/{slug}/evidence/blind-output-test.md` (post-instantiation).
- Per-skill `examples/` fill with encoded reference outputs.
- Codex / Cursor / OpenClaw adapters (v2.0).

---

*Growth Operating Agency — a Heuresis workspace template.*
