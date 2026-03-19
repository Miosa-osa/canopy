# /setup

Full system setup and configuration for OptimalOS.

## What It Does
Initializes or reconfigures the OptimalOS system:
1. Verifies engine compilation and database
2. Runs full reindex of all markdown files
3. Validates topology.yaml configuration
4. Checks all 12 node folders exist with context.md
5. Verifies rhythm/ folder structure
6. Runs health diagnostics
7. Reports system status

## Usage
```
/setup                          # Full system setup
/setup --reindex                # Reindex only
/setup --validate               # Validate only (no changes)
```

## Engine Commands Used
```bash
cd engine && mix compile --force
cd engine && mix optimal.index
cd engine && mix optimal.stats
cd engine && mix optimal.health
cd engine && mix optimal.l0
```

## When to Use
- First time setup
- After major file reorganization
- After engine code changes
- When system feels broken
