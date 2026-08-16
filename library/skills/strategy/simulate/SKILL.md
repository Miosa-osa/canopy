# /simulate

> Run scenario simulations to explore outcomes before committing to a decision.

## Usage
```
/simulate "<scenario>" [--branches <n>] [--depth <n>]
```

## What It Does
Takes a scenario or decision and simulates multiple outcome branches. Uses Monte Carlo tree search to explore the decision space, evaluating each branch on probability and impact. Returns a ranked set of outcomes with recommended actions.

## Implementation
Runs: `cd engine && mix optimal.simulate`

Process:
1. **Parse scenario** -- extract the decision point, actors, constraints, and unknowns.
2. **Generate branches** -- produce N possible outcomes (default: 3).
3. **Evaluate** -- score each branch on probability (0-1) and impact (positive/negative).
4. **Simulate forward** -- for each branch, simulate 2nd-order effects.
5. **Rank** -- order by expected value (probability x impact).
6. **Report** -- structured outcome tree with recommended action.

## Examples
```bash
# Simulate a pricing decision
/simulate "What happens if we raise AI Masters to $2K/seat?"

# Simulate with more branches
/simulate "Bennett leaves the team" --branches 5

# Deeper simulation
/simulate "We launch the platform in Q2 vs Q3" --depth 3
```
