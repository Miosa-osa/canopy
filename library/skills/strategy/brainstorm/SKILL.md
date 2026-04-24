---
name: brainstorm
description: "Generate 3–5 distinct approaches to a problem with pros, cons, effort estimates, and a reasoned recommendation. Forces structured divergent thinking before jumping to implementation. Use when facing a technical decision, architecture choice, or strategic tradeoff where multiple viable paths exist."
user-invocable: true
triggers:
  - brainstorm
  - brainstorm ideas
  - explore options
  - compare approaches
  - tradeoff analysis
  - decision matrix
---

# /brainstorm

> Generate 3–5 approaches with pros, cons, and a reasoned recommendation.

## Usage

```bash
/brainstorm "<problem>" [--options <n>] [--constraint "<constraint>"]
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `"<problem>"` | string | required | The problem or decision to brainstorm |
| `--options` | int | `3` | Number of approaches to generate (max 5) |
| `--constraint` | string | — | Constraint to apply across all approaches |

## Workflow

1. **Clarify** — restate the problem as a clear question.
2. **Explore** — generate N approaches (default: 3, max: 5). Each must be genuinely different, not variations of the same idea.
3. **Evaluate** — for each approach, list pros, cons, effort estimate, risk level.
4. **Decide** — recommend the best approach with clear reasoning.
5. **Plan** — break the recommended approach into concrete next steps.

## Examples

```bash
# Brainstorm a technical decision
/brainstorm "How should we handle auth in the platform?"

# Brainstorm with more options
/brainstorm "Revenue model for OS Accelerator" --options 5

# Brainstorm with constraints
/brainstorm "Hiring a frontend dev" --constraint "budget under $8K/mo"
```

## Output

```markdown
## Brainstorm: How should we handle auth in the platform?

### Approach 1: Session-based auth with Phoenix.Token
- **Pros**: Simple, built-in, no external deps
- **Cons**: Harder to scale across services, sticky sessions
- **Effort**: 1 week | **Risk**: Low

### Approach 2: JWT with refresh tokens
- **Pros**: Stateless, works across services, mobile-friendly
- **Cons**: Token revocation complexity, larger payload
- **Effort**: 2 weeks | **Risk**: Medium

### Approach 3: OAuth2 with third-party provider (Auth0/Clerk)
- **Pros**: Battle-tested, social login, MFA out of the box
- **Cons**: Vendor lock-in, monthly cost, latency
- **Effort**: 1 week | **Risk**: Low

### ✅ Recommendation: Approach 2 (JWT)
Stateless auth fits the multi-service architecture. Implement short-lived access tokens (15 min) with rotating refresh tokens to mitigate revocation concerns.

### Next Steps
1. Define token payload schema
2. Implement refresh token rotation in the auth service
3. Add middleware to Phoenix and SvelteKit
```
