# /summarize

> Summarize content for a target audience. Writer-owned.

## Usage
```
/summarize <source> [--audience <executive|technical|general>] [--length <short|medium|long>]
```

## What It Does
Takes source content (document, transcript, data) and produces a structured summary
tailored to the target audience's genre and comprehension level.

## Implementation
1. **Load** — Read the source content.
2. **Identify** — Key points, decisions, action items, entities.
3. **Compress** — Reduce to target length preserving key information.
4. **Format** — Structure for the target audience's preferred genre.
5. **Deliver** — Summary with clear takeaways and action items.

## Length Targets

| Length | Words | Use Case |
|--------|-------|----------|
| short | 50-100 | Slack message, quick update |
| medium | 150-300 | Email, brief, status update |
| long | 400-800 | Report section, detailed overview |

## Examples
```bash
/summarize meeting-transcript.md --audience executive --length short
/summarize architecture-doc.md --audience technical --length medium
/summarize quarterly-data.md --audience general --length long
```
