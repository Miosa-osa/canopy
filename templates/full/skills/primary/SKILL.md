# /primary

> Main workflow execution and routing. Director-owned.

## Usage
```
/primary <request> [--priority <high|normal|low>] [--agent <id>]
```

## What It Does
Routes the request through the operation's core workflow. Director triages, assigns to
the right agent, tracks execution, reviews output, and delivers.

## Implementation
1. **Triage** — Director classifies the request type and urgency.
2. **Route** — Assign to the appropriate agent based on routing table.
3. **Execute** — Assigned agent processes using their skills.
4. **Review** — Director reviews output quality and genre fit.
5. **Deliver** — Final output formatted for the receiver.

## Examples
```bash
/primary "We need a pricing proposal for the enterprise tier"
/primary "Debug the auth timeout issue" --agent engineer --priority high
/primary "What's our current revenue run rate?" --agent analyst
```
