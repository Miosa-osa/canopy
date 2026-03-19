# /translate

> Convert content between genres while preserving the core signal.

## Usage
```
/translate <file> --from <genre> --to <genre> [--for <person>]
```

## What It Does
Takes content in one genre and re-encodes it in another while preserving the core signal. A spec becomes a brief. A transcript becomes action items. A brain dump becomes a plan. Matches the target genre's skeleton and the receiver's bandwidth.

## Implementation
1. **Read source** -- load the content.
2. **Extract signal** -- identify the core facts, decisions, and action items regardless of current genre.
3. **Apply target skeleton** -- use the target genre's structure template.
4. **Encode for receiver** -- if `--for` specified, match that person's preferred genre and bandwidth.
5. **Validate** -- verify no critical signal was lost in translation.

## Examples
```bash
# Convert a spec into a brief for a salesperson
/translate docs/system-spec.md --from spec --to brief --for "sales team"

# Convert a transcript into action items
/translate signals/2026-03-18-jordan-debrief.md --from transcript --to plan

# Convert a brain dump into a structured plan
/translate rhythm/weekly-dump.md --from note --to plan
```
