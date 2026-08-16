---
name: pay
description: Authorize agent payments via Machine Payments Protocol (MPP). Handles microtransactions, API purchases, service subscriptions within budget governance. Triggered by pay, purchase, buy, transaction, payment, MPP, commerce.
---

# /pay — Agent Commerce via Machine Payments Protocol

## Purpose

Authorizes payments from an agent to external services using the Machine Payments
Protocol (MPP). Integrates with workspace budget enforcement and governance gates
to ensure agents spend within approved limits.

## Usage

```
/pay <amount> <currency> --to <service> --for <reason> [--recurring <interval>]
```

## Arguments

| Arg | Required | Default | Description |
|-----|----------|---------|-------------|
| `amount` | Yes | — | Payment amount (supports micro: `0.001`) |
| `currency` | Yes | `USD` | Currency code or `USDC` for stablecoins |
| `--to` | Yes | — | Service endpoint or provider name |
| `--for` | Yes | — | Human-readable reason (logged to budget) |
| `--recurring` | No | one-time | Interval: `hourly`, `daily`, `weekly`, `monthly` |
| `--max` | No | from budget | Maximum per-transaction limit override |
| `--approve` | No | auto | Force approval: `auto` (within threshold) or `manual` |

## Workflow

1. **Check budget** — Query workspace budget from `company.yaml`
   - Calculate remaining budget for this agent/project/goal
   - If over budget → hard stop, return error, notify orchestrator
2. **Check governance** — Evaluate payment against approval thresholds
   - Under agent threshold → auto-approve
   - Under project threshold → log + proceed
   - Over threshold → queue for human approval, pause until resolved
3. **Construct payment request** — Build MPP-compatible payment intent
4. **Authorize** — Send payment via configured payment adapter (Stripe MPP, etc.)
5. **Log** — Record transaction in budget ledger:
   ```yaml
   - timestamp: 2026-03-20T14:32:00Z
     agent: prospector
     amount: 0.50
     currency: USD
     to: browserbase
     for: "3 browser sessions for lead scraping"
     task_id: task-042
     status: completed
   ```
6. **Report** — Return confirmation with remaining budget

## Examples

```bash
# Pay for API access
/pay 0.50 USD --to browserbase --for "browser sessions for lead scraping"

# Subscribe to data feed
/pay 29.99 USD --to "linkedin-enrichment" --for "lead enrichment API" --recurring monthly

# Microtransaction for compute
/pay 0.003 USD --to "compute-provider" --for "10min GPU for analysis"

# Payment requiring approval (over threshold)
/pay 500 USD --to "data-vendor" --for "Q1 industry report" --approve manual
```

## Governance Integration

Payment thresholds are defined in `company.yaml`:

```yaml
governance:
  payment_thresholds:
    auto_approve: 10.00        # Agent pays without asking
    notify: 50.00              # Agent pays, human notified
    require_approval: 100.00   # Human must approve first
    hard_ceiling: 1000.00      # Never exceed without board override
```

## Budget Ledger

All payments are logged to `.canopy/budget-ledger.jsonl` (append-only):

```jsonl
{"ts":"2026-03-20T14:32:00Z","agent":"prospector","amount":0.50,"to":"browserbase","task":"task-042"}
{"ts":"2026-03-20T14:35:00Z","agent":"closer","amount":29.99,"to":"linkedin","task":"task-043"}
```

The `/budget` skill reads this ledger for spend dashboards and forecasting.

## Dependencies

- `company.yaml` with budget and governance config
- Payment adapter configured in `engine/` (Stripe MPP, etc.)
- `/budget` skill for spend tracking and reporting
- `/approve` skill for governance gate integration
