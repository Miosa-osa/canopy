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
On September 8, the live `main` protection required one approving review, code-owner review, approval after the last push, stale-approval dismissal, conversation resolution, and the four required status contexts.
Administrator enforcement was enabled, and force pushes and branch deletion were disabled.
An author cannot provide their own independent approval; administrators must satisfy the same merge requirements.
Recheck live settings before release because repository administrators can change settings separately from a pull request.
The workflow and CODEOWNERS files do not themselves establish that the live rules remain enabled.

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

## Findings 1-6: disposition and evidence

The September report is a set of concrete defects, proposed adversarial scenarios, and broader closure criteria.
The rows below distinguish the implemented response from the proof still required.
They do not certify independent red-team closure.

| Finding | Current response and evidence | Limit or remaining verification |
|---------|-------------------------------|---------------------------------|
| 1. Missing mandatory boot documents | [../CLAUDE.md](../CLAUDE.md) points to existing current contracts; missing legacy documents are no longer boot requirements; [the registry validator](../scripts/agent_control_plane.py) rejects unresolved authority references | Structural reference checks do not establish that document content is correct |
| 2. Ambiguous authority | [agent-authority.json](../agent-authority.json) declares owner, scope, version, status, requirements, and supersession; competing scoped ownership and cycles fail [fixtures](../scripts/tests/test_agent_control_plane.py) | Unregistered semantic contradictions inside otherwise valid prose still require review |
| 3. Historical completion reports treated as current | Historical documents remain classified and cannot own current concepts; the current README and index direct readers to current contracts | An arbitrary retrieval/prompt pipeline can still surface historical prose; Canopy has not demonstrated universal historical-poisoning resistance |
| 4. Old Engine wiring conflicts with the current contract | The old wiring proposal is explicitly superseded by [the workspace Engine contract](24-workspace-engine.md); examples require compatibility metadata | Different architecture vocabularies alone do not prove a runtime incompatibility; test the actual boundary |
| 5. Unpinned checkout and compatibility | [Static preflight](../backend/lib/canopy/workspaces/engine/compatibility.ex) checks checkout location, origin, commit, cleanliness, tracked contract, release range, API, migration metadata, and capabilities | This is not loaded-process attestation, dependency reproducibility, a live migration check, or protection against a malicious local owner |
| 6. Application CI does not validate the control plane | [Authority workflow](../.github/workflows/agent-control-plane.yml) runs the structural gate and fixtures alongside [application CI](../.github/workflows/ci.yml); live branch rules require their status contexts | A green build and static gate do not prove all semantic/runtime security invariants or independent red-team closure |

## Fixtures A-G: what can be retested

| Report fixture | Reproduction and expected evidence | Coverage status |
|----------------|------------------------------------|-----------------|
| A. Missing authority | Python `test_missing_authority`, missing Markdown/reference-link fixtures, and `test_unregistered_boot_reference` must reject the changed fixture repository | Automated structural regression |
| B. Competing ownership | `test_competing_authority`, dependency/supersession cycle fixtures, and duplicate-path/JSON-key fixtures must fail closed | Automated declared-ownership regression; prose semantics are outside the parser |
| C. Superseded architecture promoted to current | `test_superseded_normative`, `test_retired_boot_reference`, `test_historical_cannot_own_current_state`, and `test_textual_retired_boot_reference` reject stale authority classifications/references | Automated classification regression; no claim that version numbers in arbitrary prose are interpreted |
| D. Wrong Engine checkout | ExUnit compatibility tests change revision, replace the checkout with a symlink, dirty tracked code, or alter required compatibility metadata; execution must return `engine_incompatible` | Automated local-source compatibility regression; independent server/build-artifact attestation remains outside this bridge |
| E. Historical retrieval poisoning | Historical documents cannot own current authority in registry fixtures; current guidance states that retrieved history is dated evidence | Partial: no Canopy end-to-end adversarial retrieval test proves an agent cannot be influenced by stale content |
| F. Observation-to-Fact bypass | Canopy's [operational review tests](../backend/test/canopy/tools/reviews_test.exs) validate its own queue; Engine Claim-to-Fact authorization must be tested in the Engine repository | Not established by Canopy review or documentation tests; no cross-product epistemic bypass closure claim |
| G. Documentation weakens permissions without review | Permission-schema fixtures reject missing/empty declarations; CODEOWNERS and live protected-branch settings require independent review of changes | Partial: schema validation does not infer semantic permission widening, and configured review is not proof that a reviewer identified every dangerous change |

The report's final acceptance criterion requires an independent red team to fail to induce stale authority, wrong-runtime execution, permission expansion, or unauthorized Fact promotion.
The September work supplies concrete structural and application evidence, not that independent attestation.
Before declaring closure, record the tested commit, runtime identity, actor/tenant/workspace context, requests, actual responses, and reviewer for each remaining scenario.

## Retest commands

Run these from the Canopy repository root using the pinned toolchain:

```bash
make doctor
python3 scripts/agent_control_plane.py
python3 -m unittest discover -s scripts/tests -p 'test_agent_control_plane.py'
```

The Python command reports the structural fixture count for the checkout being tested.
Tests mutate disposable fixture repositories, not production documents.
Application regressions require PostgreSQL with pgvector:

```bash
cd backend
MIX_ENV=test MIX_TEST_PARTITION=_control_plane_retest mix test test/canopy/workspaces/engine_test.exs test/canopy/tools/workspace_engine_test.exs test/canopy_web/controllers/workspace_engine_controller_test.exs
MIX_ENV=test MIX_TEST_PARTITION=_control_plane_retest mix test test/canopy/sessions/persistence_test.exs test/canopy/tools/reviews_test.exs test/canopy/reviews_test.exs
MIX_ENV=test MIX_TEST_PARTITION=_control_plane_retest mix test --cover
```

From the repository root, run frontend checks separately:

```bash
cd desktop
pnpm check
pnpm lint
pnpm test
pnpm build
```

Frontend unit tests reject unexpected fetch calls, preventing a locally running backend from masking unawaited requests.
The [onboarding completion regression](../desktop/src/lib/design/patterns/onboarding/CompleteStep.test.ts), [setup-action tests](../desktop/src/lib/design/patterns/onboarding/setup-actions.test.ts), and [pin-query tests](../desktop/src/lib/api/queries/pins.test.ts) verify specific user-facing repairs; they are not security-attestation substitutes.
See [development guidance](development.md) for Rust checks, credential storage, generated types, native verification, and all required status names.

## Dated validation record

The repaired September 8 product baseline was merged as `b2a4308`.
[PR application CI](https://github.com/Miosa-osa/canopy/actions/runs/34277405018), [post-merge application CI](https://github.com/Miosa-osa/canopy/actions/runs/34277937280), and [post-merge authority CI](https://github.com/Miosa-osa/canopy/actions/runs/34277937347) passed.
Local frontend verification included 1,302 tests across 73 files with no backend running; Rust verification included 11 tests, clippy, and rustfmt.
These are dated measurements, not a promise that future changes pass.
The document/command follow-up must obtain its own CI results and independent review before merge.
