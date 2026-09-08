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
