---
name: review-interface
description: >
  Build custom annotation UIs for human review of agent traces, LLM outputs,
  and labeled data. Generates a self-contained HTML interface for reviewing,
  labeling, comparing, and exporting judgments. For calibrating evals, auditing
  agent behavior, and building gold-standard datasets.
  Triggers on: "review interface", "annotation ui", "labeling interface", "review ui", "human review"
---

# /review-interface

> Build custom annotation UIs for human review of agent outputs and traces.

## Purpose

Generate a self-contained HTML annotation interface tailored to a specific review task. Supports reviewing LLM outputs, agent execution traces, side-by-side comparisons, and data labeling. The interface loads data from a JSONL file, presents items one at a time with the configured annotation controls, tracks progress, and exports labeled results. No server required — runs entirely in the browser from a single HTML file.

## Usage

```bash
# Build review UI for eval outputs
/review-interface --data eval-results.jsonl --task "rate output quality" --labels pass,fail

# Build comparison UI (A vs B)
/review-interface --data comparisons.jsonl --task "which response is better" --mode compare

# Build trace review UI
/review-interface --data agent-traces.jsonl --task "identify failure point" --mode trace

# Custom annotation schema
/review-interface --data outputs.jsonl --schema annotation-schema.yaml

# Build with pre-filled labels (for review/correction)
/review-interface --data labeled.jsonl --labels pass,fail --prefilled
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--data` | string | required | Path to JSONL data file to review |
| `--task` | string | required | Description of the review task (shown in UI header) |
| `--labels` | string | — | Comma-separated label options (e.g., `pass,fail` or `good,okay,bad`) |
| `--mode` | enum | `single` | Review mode: `single` (one item), `compare` (A vs B), `trace` (step-by-step) |
| `--schema` | string | — | Path to custom annotation schema (YAML) |
| `--prefilled` | flag | false | Load existing labels for review/correction |
| `--output` | string | `review-interface.html` | Output HTML file path |
| `--items-per-page` | int | `1` | Items shown per page |
| `--randomize` | flag | false | Randomize item presentation order |
| `--blind` | flag | false | Hide metadata (model name, config) to reduce bias |

## Workflow

1. **Analyze data** — Parse the JSONL file. Identify fields: input, output, metadata, scores, trace steps. Determine which fields are reviewable vs. contextual.
2. **Configure annotation** — Based on `--labels`, `--schema`, or `--mode`, define the annotation controls: radio buttons (categorical), text input (free-form notes), sliders (continuous), checkboxes (multi-label), or side-by-side selectors (comparison).
3. **Design layout** — Build the review interface layout:
   - Header: task description, progress bar, item counter
   - Context panel: input/question/prompt (always visible)
   - Review panel: output(s) to evaluate (mode-dependent)
   - Annotation panel: label controls, notes field, confidence selector
   - Navigation: prev/next, skip, keyboard shortcuts
4. **Build interface** — Generate a single self-contained HTML file with inline CSS and JavaScript. Features:
   - Data loaded from embedded JSON or file input
   - Local storage for progress persistence (survives page refresh)
   - Keyboard shortcuts: 1-9 for labels, Enter for next, Backspace for prev, S for skip
   - Progress tracking: completed, skipped, remaining
   - Export: download labeled results as JSONL
   - Filter: show only unlabeled, show only labeled, show all
5. **Blind mode** — If `--blind` is set, strip model identifiers, configuration details, and any metadata that could bias the reviewer. Randomize A/B order in comparison mode.
6. **Output** — Write the HTML file. Report: total items, annotation schema, estimated review time.

## Examples

### Binary quality review
```
/review-interface --data eval-results.jsonl --task "Is this summary accurate?" --labels pass,fail

## Review Interface Generated

### Configuration
- Task: "Is this summary accurate?"
- Items: 200
- Labels: pass, fail
- Mode: single
- Keyboard: 1=pass, 2=fail, Enter=next, Backspace=prev

### Data Fields
- Input: source document (scrollable)
- Output: generated summary
- Annotation: pass/fail + optional notes

### Estimated Review Time
- At 30s per item: ~100 minutes
- At 15s per item: ~50 minutes

### Output: review-interface.html (82 KB)
```

### Side-by-side comparison
```
/review-interface --data comparisons.jsonl --task "Which response is better?" --mode compare --blind

## Review Interface Generated

### Configuration
- Task: "Which response is better?"
- Items: 150
- Mode: compare (A vs B, blinded)
- Labels: A is better, B is better, Tie
- Keyboard: 1=A, 2=B, 3=Tie, Enter=next

### Blind Mode
- Model names hidden
- Response order randomized per item
- No metadata visible during review
```

### Custom annotation schema
```yaml
# annotation-schema.yaml
fields:
  - name: quality
    type: radio
    options: [excellent, good, acceptable, poor]
    required: true
  - name: errors
    type: checkbox
    options: [factual-error, hallucination, incomplete, off-topic, formatting]
    required: false
  - name: notes
    type: text
    placeholder: "Optional notes..."
    required: false
  - name: confidence
    type: slider
    min: 1
    max: 5
    default: 3
```

## Output

```markdown
## Review Interface Generated

### File: <output>.html
### Size: N KB (self-contained, no dependencies)

### Configuration
- Task: <task description>
- Items: N
- Mode: <mode>
- Labels/Schema: <description>

### Features
- Progress persistence (localStorage)
- Keyboard shortcuts
- Export to JSONL
- Filter by label status
- Blind mode: <on/off>

### Estimated Review Time
- N items at ~Ns per item: ~N minutes
```

## Dependencies

- Data file (JSONL with items to review)
- Optional: annotation schema (YAML)
- No runtime dependencies (output is self-contained HTML)
- `/judge-prompt` — Upstream if building labels for judge calibration
- `/validate-evaluator` — Downstream consumer of exported human labels
- `/error-analysis` — Upstream if trace review is needed for failure diagnosis
