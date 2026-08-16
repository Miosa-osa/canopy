# /write

> Generate content in the correct genre for the target receiver.

## Usage
```
/write <genre> --for <person> [--topic "<topic>"] [--tone <tone>]
```

## What It Does
Produces content using the Signal Theory framework: resolves all 5 dimensions (Mode, Genre, Type, Format, Structure), applies the correct genre skeleton, and matches the receiver's decoding capacity. Looks up the person's preferred genre from the people registry.

## Implementation
1. **Resolve receiver** -- look up person in people registry (CLAUDE.md or 10-team/context.md).
2. **Select genre** -- use the specified genre or infer from receiver preference.
3. **Load genre skeleton** -- apply the structured template (brief, spec, plan, pitch, etc.).
4. **Assemble context** -- `/assemble` relevant topic context if needed.
5. **Generate** -- produce content matching genre structure, receiver bandwidth, and tone.
6. **Validate** -- check against the 6 encoding principles (mode-message alignment, entropy preservation, etc.).

Supported genres: brief, spec, plan, transcript, note, pitch, proposal, report, email, social-post, outline, changelog, ADR.

## Examples
```bash
# Write a brief for a salesperson
/write brief --for "sales rep" --topic "Q2 pricing update"

# Write a spec for a developer (with explicit constraints)
/write spec --for "lead developer" --topic "authentication flow"

# Write a pitch for a client
/write pitch --for "prospect" --topic "platform demo"
```
