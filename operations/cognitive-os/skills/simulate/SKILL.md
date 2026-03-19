# /simulate

Monte Carlo scenario planning and impact analysis.

## What It Does
Runs Monte Carlo Tree Search for scenario planning. Evaluates potential decisions
by simulating outcomes across multiple paths. Reports expected value, risk
distribution, and recommended actions.

## Usage
```
/simulate "What if we price AI Masters at $2K per seat?"
/simulate "Impact of hiring two more devs" --scenarios 100
```

## Options
| Flag | Description | Default |
|------|-------------|---------|
| `--scenarios` | Number of simulation paths | 50 |

## Engine Command
```bash
cd engine && mix optimal.simulate "scenario description"
cd engine && mix optimal.impact "decision description"
```

## When to Use
- Before major decisions (pricing, hiring, partnerships)
- Strategic planning sessions
- When evaluating trade-offs between options
