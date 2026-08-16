# /edit

> Revise existing content for clarity, accuracy, and signal-to-noise ratio.

## Usage
```
/edit <file> [--focus <clarity|accuracy|conciseness|tone>] [--for <person>]
```

## What It Does
Reads the target file, analyzes it against Signal Theory principles, and suggests or applies edits to maximize signal-to-noise ratio. Can focus on specific dimensions: clarity (remove ambiguity), accuracy (fact-check against knowledge base), conciseness (cut noise), or tone (match receiver).

## Implementation
1. **Read content** -- load the file.
2. **Analyze** -- score against the 6 encoding principles.
3. **Identify noise** -- filler, hedging, repetition, wrong structure.
4. **Suggest edits** -- specific before/after changes with rationale.
5. **Apply** (if confirmed) -- make the edits.
6. **Validate** -- re-score to confirm improvement.

## Examples
```bash
# Edit for overall quality
/edit docs/pitch-card.md

# Focus on conciseness
/edit docs/architecture/FULL-SYSTEM-ARCHITECTURE.md --focus conciseness

# Edit for a specific receiver
/edit outreach-email.md --for "Ed Honour"
```
