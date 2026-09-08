# Agent Control Plane Integrity

Effective: 2026-09-08.
Owner: platform.

The repository root `agent-authority.json` is the document authority registry.
Run `python3 scripts/agent_control_plane.py` before relying on repository instructions.
Run `python3 -m unittest discover -s scripts/tests -p 'test_agent_control_plane.py'` for adversarial fixtures.

Each document has an owner, scope, version, effective classification date, kind, status, and explicitly owned concepts.
The classification date records this authority review, not the original document publication date.
Only active normative documents and contracts may own current concepts.
One scoped concept has one owner document; reference and historical documents cannot override it.
Required boot references must lead to active authority.
Supersession must resolve to a current contract without cycles or missing targets.
New documents in the declared inventory require explicit classification.

A reference explains implementation or a proposal and does not independently authorize behavior.
A historical report describes evidence at its original date and does not establish current runtime state.
The validator verifies declared ownership and structural references, not arbitrary natural-language contradictions.
Semantic conflicts require human review and application regression evidence.

## Permission changes

The manifest records the permission baseline.
Documentation cannot grant API, tenant, workspace, tool, Fact, or topology access beyond runtime policy.
CODEOWNERS covers boot files, registered documentation, manifests, enforcement scripts, and workflows.
Repository branch rules must require code-owner review with stale approval dismissal and the `agent-control-plane-integrity` status check.
A workflow file alone cannot configure required checks or demonstrate that repository rules are enabled.
Permission changes require explicit review of the actual diff; a green structural validator is not permission approval.
Repository administrators retain the platform's ability to change repository settings.

## Evidence limits

### Backend coverage baseline

The full backend coverage gate is explicitly 67.5%, with no coverage exclusions added for this rollout.
The original `e41f4bd` checkout measured 67.03% coverage and nine failing tests on September 8.
The repaired suite passed 3,236 tests locally at 67.70%; the preceding Linux run measured 67.64%.
The previously implicit Mix default of 90% was not an achieved project baseline.
Historical 80% targets are not evidence that the current product meets that target.
Raise the configured floor as sustained coverage improves; reductions require explicit owner review of the measurement and rationale.
Coverage measures executed lines and does not substitute for behavior assertions or the authority and permission regressions.

### Report interpretation

The September 8 report correctly identified unresolved Canopy boot references and stale integration guidance.
Its broader epistemic and permission scenarios require runtime reproductions; documentation drift alone does not prove those exploits.
The Engine already exposes build SHA, release version, API version, migration level, and retrieval component identity.
Layered storage terminology and governed knowledge terminology can coexist without an API conflict.
Canopy's current workspace bridge executes local allowlisted Mix tasks; the old in-process dependency was a proposal.
The workspace contract and its tests govern checkout compatibility.
Do not claim universal prompt-injection prevention or full independent red-team closure from these gates.
