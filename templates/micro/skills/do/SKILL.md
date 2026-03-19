# /do

> The agent's primary skill. Customize this to match your agent's purpose.

## Usage

```
/do <input> [--format <format>] [--depth <brief|detailed>]
```

## What It Does

Executes the agent's primary task. Takes user input, processes it according to the
agent's domain expertise, and produces structured output.

Replace this description with your agent's specific capability:
- For a code reviewer: analyzes code and produces review feedback
- For an email responder: drafts email responses matching tone and context
- For a meeting summarizer: extracts action items and decisions from transcripts

## Implementation

1. **Parse input** — Extract the core request and any parameters.
2. **Validate** — Confirm the input is within scope and sufficient.
3. **Process** — Apply domain expertise to produce the output.
4. **Format** — Structure output using the deliverable template.
5. **Deliver** — Return the formatted result.

## Parameters

| Param | Default | Options | Description |
|-------|---------|---------|-------------|
| `--format` | `markdown` | `markdown`, `json`, `text` | Output format |
| `--depth` | `brief` | `brief`, `detailed` | Level of detail |

## Examples

```bash
# Basic usage
/do "Review this function for bugs"

# Detailed output
/do "Summarize this meeting transcript" --depth detailed

# JSON output for programmatic use
/do "Extract entities from this text" --format json
```

## Output Template

```markdown
## Result

### Summary
[Brief answer to the request]

### Details
[Structured breakdown — customize per domain]

### Confidence
[High | Medium | Low] — [reason if not High]
```
