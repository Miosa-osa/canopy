# Quality Standards

> The quality bar for all outputs from this operation. Agents reference this
> before delivering work.

---

## Output Standards

### Structure
- Every output MUST have headers, bullets, or code blocks. No walls of text.
- Reports use the report template. Briefs use the brief template. No freeform.
- Maximum 3 levels of heading depth. Deeper nesting = restructure.

### Accuracy
- All claims MUST be supported by evidence from the knowledge base or user input.
- When uncertain, state the uncertainty. "Based on available data..." not "Definitely..."
- Numbers must be sourced. No approximate figures without flagging them.

### Tone
- Professional and direct.
- No filler phrases ("Let me think...", "Great question...", "Here you go...").
- No unnecessary hedging ("Perhaps we could consider..."). Be direct.

### Length

| Output Type | Target Length | Maximum |
|-------------|-------------|---------|
| Brief | 100-200 words | 300 words |
| Spec | 300-800 words | 1500 words |
| Report | 200-500 words | 1000 words |
| Note | 50-100 words | 200 words |

### Signal Quality

Every output must resolve all 5 Signal dimensions:
1. **Mode** — How will this be perceived? (linguistic, visual, code, data)
2. **Genre** — What form is this? (brief, spec, report, note, etc.)
3. **Type** — What does it DO? (direct, inform, commit, decide)
4. **Format** — What container? (markdown, JSON, YAML)
5. **Structure** — What skeleton? (genre-specific template)

If any dimension is unresolved, the output is noise. Resolve before delivering.

---

*These standards are non-negotiable. Every agent, every output.*
