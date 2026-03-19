# /remember

Capture friction patterns and observations for the learning loop.

## What It Does
3-mode friction capture:
- **Explicit**: Store a specific observation with confidence score
- **Contextual**: Scan recent sessions for correction signals
- **Mine**: Bulk extract patterns from session history

Observations stored in `observations` table. When 3+ observations accumulate in the
same category, escalates for rethink.

## Usage
```
/remember "always check duplicates before ingesting"
/remember --contextual                # Scan recent sessions
/remember --mine                      # Bulk extract from sessions
/remember --escalations               # Show patterns ready for rethink
```

## Categories
Observations are auto-classified into: process, people, tool, decision, pattern, friction

## Engine Command
```bash
cd engine && mix optimal.remember "observation text"
cd engine && mix optimal.remember --contextual
cd engine && mix optimal.remember --mine
cd engine && mix optimal.remember --escalations
```

## When to Use
- When you notice a recurring problem
- After making a mistake (capture the pattern)
- Friday review (check escalations)
- When user corrects the AI's approach
