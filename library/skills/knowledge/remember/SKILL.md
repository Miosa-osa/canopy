# /remember

> Capture observations, friction patterns, and learnings for future synthesis.

## Usage
```
/remember "<observation>"
/remember --contextual
/remember --mine
/remember --list
/remember --escalations
```

## What It Does
Stores observations and friction patterns into the learning loop. Over time, observations accumulate evidence. When confidence reaches a threshold, they become eligible for `/rethink` synthesis. This is how the system learns from experience.

## Implementation
- Explicit: `cd engine && mix optimal.remember "always check duplicates before inserting"`
- Contextual scan: `cd engine && mix optimal.remember --contextual` (scans recent signals)
- Bulk extract: `cd engine && mix optimal.remember --mine` (from session transcripts)
- List stored: `cd engine && mix optimal.remember --list`
- Check escalations: `cd engine && mix optimal.remember --escalations` (categories ready for rethink)

## Examples
```bash
# Store an explicit observation
/remember "Lead developer needs explicit constraints or they over-engineer"

# Scan recent signals for friction patterns
/remember --contextual

# See what's accumulated enough evidence for synthesis
/remember --escalations
```
