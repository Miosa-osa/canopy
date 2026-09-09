# Current Canopy product contract

Effective: 2026-09-08.
Owner: platform.

Canopy focuses on a desktop terminal workspace with continuity across restarts.
Named sessions, working directories, git worktrees, terminal restoration, and agent conversation continuity define the intended product direction.
The broader module vision is parked in navigation; routes retained in source do not establish current sidebar exposure or end-to-end readiness.

## Implemented evidence and limits

| Area | Implementation and regression evidence | What this establishes |
|------|----------------------------------------|-----------------------|
| Session snapshot and restore | [Persistence](../backend/lib/canopy/sessions/persistence.ex), [persistence tests](../backend/test/canopy/sessions/persistence_test.exs), [application lifecycle](../backend/lib/canopy/application.ex) | Live session metadata is saved to JSON and restored; current database cancellation and approval holds take precedence over stale snapshots |
| Terminal output | [Scrollback tests](../backend/test/canopy/sessions/scrollback_store_test.exs), [PTY batching tests](../backend/test/canopy/sessions/pty_bridge_batching_test.exs) | Stored output and bounded flush behavior; a process snapshot is not a complete terminal screen-state snapshot |
| Session resume | [Resume tests](../backend/test/canopy/sessions/resume_test.exs), [spawn pipeline](../backend/lib/canopy/agents/spawn_pipeline.ex) | Resume and spawn paths have tests; provider authentication, conversation identity, and full native quit/relaunch behavior require runtime-specific verification |
| Workspace state | [Workspace-state API tests](../desktop/src/lib/api/queries/workspace-states.test.ts), [layout tests](../desktop/src/lib/stores/mosaic-layout.test.ts) | State routing and layout helpers have coverage; complete UI restoration across native restarts is a separate acceptance test |
| Engine tasks | [Workspace Engine tests](../backend/test/canopy/workspaces/engine_test.exs), [contract](24-workspace-engine.md) | An approved local checkout and compatibility manifest gate allowlisted Mix tasks; this does not attest an independent HTTP server |
| Onboarding | [Completion tests](../desktop/src/lib/design/patterns/onboarding/CompleteStep.test.ts), [setup action tests](../desktop/src/lib/design/patterns/onboarding/setup-actions.test.ts) | Skipped steps do not claim successful setup; browser folder selection is unavailable and failed hires remain visible |

The snapshot stores external session identity, but retaining an identifier alone does not prove that every runtime resumes the same provider conversation.
A graceful backend stop differs from a forced process kill or operating-system crash.
Do not advertise crash-proof recovery or universal runtime resume from the existing unit tests.
Native packaging, authentication, terminal-screen fidelity, and provider-specific resume need explicit end-to-end evidence for the release being shipped.

## Authority

[../CLAUDE.md](../CLAUDE.md) governs agent operating rules.
This document governs current product scope.
[The workspace Engine contract](24-workspace-engine.md) governs local Engine execution.
[The review queue contract](25-review-queue.md) governs Canopy operational review, distinct from OptimalEngine Claim-to-Fact review.
[The authority registry](../agent-authority.json) supplies the ownership graph.

Historical architecture, foundation, phase, and wiring documents remain evidence of their original dates.
Completion counts and screenshots do not supersede current scope or establish that the current checkout works.
Competitor reports provide provenance, not permission to expand capabilities.
[../NOTICE.md](../NOTICE.md) owns attribution records.

Implementation claims require a named code path and a reproducible test against the checkout being shipped.
The [control-plane evidence](agent-control-plane.md) records the September 8 checks, coverage floor, and unresolved independent-red-team acceptance criteria.

## State ownership

Canopy owns application, workspace, terminal session, and operational review state.
Optimal Engine owns knowledge, memory, Claims, and Facts.
The local Canopy review API and MCP handlers operate inside a trusted operator boundary and accept a caller-supplied reviewer identifier.
Their approval status does not prove independent human review and does not confer Engine Fact-creation authority.
