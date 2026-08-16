# /summarize

> Compress content to a target length while preserving key signal.

## Usage
```
/summarize <file|text> [--length <short|medium|long>] [--format <bullets|prose|table>]
```

## What It Does
Reads the input content, identifies the key signals (decisions, action items, facts, commitments), and produces a compressed summary at the target length. Preserves entropy -- maximum meaning per unit of output.

## Implementation
1. **Read content** -- load file or accept inline text.
2. **Extract key signals** -- decisions, action items, facts, names, numbers, deadlines.
3. **Rank by importance** -- what must survive compression vs what's nice-to-have.
4. **Compress** -- generate summary at target length.
5. **Validate** -- verify no critical signals were lost.

Lengths: short (~100 words), medium (~300 words), long (~500 words).

## Examples
```bash
# Summarize a long document to bullets
/summarize docs/architecture/FULL-SYSTEM-ARCHITECTURE.md --format bullets

# Short prose summary
/summarize 04-ai-masters/meeting-prep-ed-robert-lenin.md --length short

# Table format summary
/summarize 10-team/context.md --format table
```
