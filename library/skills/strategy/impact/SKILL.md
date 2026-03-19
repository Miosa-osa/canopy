# /impact

> Analyze the downstream impact of a change across all nodes.

## Usage
```
/impact "<change>" [--scope <node>]
```

## What It Does
Maps the ripple effects of a proposed change across the knowledge base. Identifies which nodes, people, revenue streams, and processes are affected. Classifies impacts as direct (1st order) or indirect (2nd/3rd order).

## Implementation
Runs: `cd engine && mix optimal.impact`

Process:
1. **Parse change** -- what is being changed and in which domain.
2. **Map dependencies** -- which nodes reference the affected entity.
3. **Trace effects** -- 1st order (direct), 2nd order (downstream), 3rd order (cascading).
4. **Identify stakeholders** -- who needs to know.
5. **Assess risk** -- probability and severity of negative effects.
6. **Report** -- impact map with affected nodes, people, and recommended mitigations.

## Examples
```bash
# Impact of a team change
/impact "Lead developer takes 2 weeks off"

# Impact of a pricing change
/impact "Raise enterprise pricing to $5K/mo"

# Scoped impact analysis
/impact "Switch from Firecracker to containers" --scope platform
```
