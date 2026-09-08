# Canopy Engineering Notes


- 2026-09-08: Agent authority now has an explicit registry and adversarial structural validator.
Historical architecture reports remain evidence and cannot own current concepts.
Cross-repo execution compatibility and governed API authorization require runtime tests, not documentation assertions alone.

- 2026-09-08: PTY immediate-cap flush tests now hold the ordinary flush timer and synchronize through the GenServer mailbox instead of imposing a 31ms scheduler deadline.
They verify pending bytes are cleared, the timer is cancelled, and exact output reaches subscribers when the cap is crossed.
A temporary raised-cap mutation caused both cap tests to fail; restoring production behavior passed all 9 batching tests.

- 2026-09-08: Claude, Codex, and Gemini subprocess integration tests now own SQL sandbox connections because runtime environment construction reads Vault credentials.
Plain ExUnit cases could accidentally use a previous shared owner during teardown, causing sporadic shutdown exits.
The Gemini cancellation test now writes a fake credential before execution; removing DataCase ownership reproduces the failure deterministically, while all 104 adapter tests pass with explicit ownership.
# Coverage gate baseline, 2026-09-08

The original e41f4bd backend measured 67.03% coverage with nine failing tests; the repaired suite passed all 3,236 tests locally at 67.70%, with the preceding Linux run measuring 67.64%.
Configured an explicit 67.5% floor above the original measured baseline, retaining full coverage collection and adding owner review for backend/mix.exs.
The previous implicit 90% default and historical 80% target were not achieved coverage claims.

## Current guidance and evidence review, 2026-09-08

The README, documentation index, contributor guide, desktop guide, and active contracts now distinguish current implementations from historical plans and unverified full native restoration.
Current setup and validation guidance lives in docs/development.md; the historical operations document remains unchanged and no longer serves as the current runbook.
The authority registry now includes the desktop guide and checks Markdown references in current guides and contracts.

Findings 1-6 and adversarial fixtures A-G have an evidence and retest matrix in docs/agent-control-plane.md.
The matrix explicitly leaves semantic historical-retrieval poisoning, independent runtime attestation, and cross-product unauthorized Fact promotion unproven by Canopy's structural checks.
Live branch protection was checked for independent code-owner review, last-push approval, stale-review dismissal, administrator enforcement, and four required status contexts.

The development command recheck reproduced duplicate Vite startup in make dev and incorrect Tauri CLI working-directory resolution.
The command follow-up makes Tauri own the single Vite process, resolves Tauri from the repository root, and makes test-watch explicitly frontend-only.
Tauri info now resolves the native application configuration; that inspection is not evidence of a completed native authenticated session or full quit/relaunch restoration.

The initial documentation validation passed the authority check, all 26 then-current structural fixtures, and 104 local Markdown links/anchors; later fixture additions must be rerun on their final checkout.
Historical and generated documents were preserved.

- 2026-09-08: Active current contracts now receive mandatory reference scanning, including bare Markdown paths in prose.
The scanner keeps paths relative to the containing document and does not treat bare filenames in fenced examples or external URLs as local dependencies.
Canopy compatibility now rejects hidden Git index flags and ignored executable source/configuration inputs while retaining normal ignored dependency/build directories.
The checks remain preflight validation within a trusted local operating-system boundary, not process or dependency attestation.
All nested Markdown guides now match CODEOWNERS, including the registered desktop guide, so documentation authority changes retain mandatory owner review.

## Preserved control-plane evidence, 2026-09-08

Added six exact synthetic fixture trees and an append-only incident ledger with expected outcomes, content hashes, causal lessons, local red-team scope, and revisit triggers.
The trusted comparison uses a separate protected base checkout rather than treating candidate evaluator/tests as their own authority.
The initial ledger remains proposed policy until independent owner review; explicit bootstrap still runs the prior base evaluator and regression suite.
Subsequent changes must retain prior records and fixtures, appending supersession instead of deleting history.
The ordinary pull-request workflow records evaluator identity and replay outcomes without privileged untrusted-code execution or an external immutability claim.
Clarified that Canopy reviews are trusted-operator operational state, not authenticated proof of independent human approval or Engine Fact authority.

The trusted comparison CLI now requires exact clean Git roots, checks enforcement inputs against Git blobs despite hidden index flags, and verifies expected trusted SHA.
It runs the trusted validator before candidate execution and detects post-child enforcement or ledger mutation.
A separate CI container wrapper supplies execution isolation; the Python harness alone is not an OS sandbox.
The fresh-agent command is documented separately from deterministic scoring tests and does not claim that Canopy operational approval authenticates human identity.
