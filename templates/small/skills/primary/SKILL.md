# /primary

> The operation's main workflow skill. Executes the core business process.

## Usage

```
/primary <request> [--priority <high|normal|low>] [--delegate]
```

## What It Does

Routes the request through the operation's core workflow: triage, execute, validate,
deliver. When `--delegate` is set, the Lead hands off to the Specialist.

## Implementation

1. **Triage** — Lead classifies the request (strategic vs tactical).
2. **Route** — If tactical and `--delegate`, create handoff to Specialist.
3. **Execute** — Assigned agent processes the request.
4. **Validate** — Output checked against quality standards.
5. **Format** — Output formatted for the intended receiver's genre.
6. **Deliver** — Final output returned.

## Examples

```bash
# Lead handles directly
/primary "Draft a status update for the client"

# Delegate to specialist
/primary "Analyze the performance regression in module X" --delegate

# High priority routing
/primary "Client needs response by EOD" --priority high
```
