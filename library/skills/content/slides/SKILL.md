---
name: slides
description: >
  Create animation-rich HTML presentations from scratch or convert PowerPoint.
  Progressive disclosure pipeline: content discovery, style discovery, generation.
  Zero-dependency single HTML file output. Anti-AI-slop guardrails for natural,
  professional presentations.
  Triggers on: "slides", "presentation", "slide deck", "create slides", "convert pptx", "html presentation"
---

# /slides

> Create animation-rich HTML presentations as zero-dependency single files.

## Purpose

Build complete HTML slide presentations from scratch (given a topic or outline) or convert existing PowerPoint files. Uses a progressive disclosure pipeline: first discover content structure, then discover visual style, then generate the final output. Produces a single self-contained HTML file with CSS animations, transitions, and keyboard navigation. Includes anti-AI-slop guardrails to prevent generic bullet points, stock phrases, and over-animated nonsense.

## Usage

```bash
# Create from topic
/slides --topic "RAG Pipeline Architecture" --audience engineers

# Create from outline
/slides --outline outline.md --style dark --animations minimal

# Convert PowerPoint to HTML
/slides --convert deck.pptx

# Convert with style override
/slides --convert deck.pptx --style "glassmorphic dark" --enhance

# Create with specific slide count
/slides --topic "Q1 Results" --audience executives --slides 12

# Preview mode (generate 3 slides first)
/slides --topic "API Design" --preview
```

## Arguments

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--topic` | string | — | Presentation topic (for from-scratch generation) |
| `--outline` | string | — | Path to markdown outline file |
| `--convert` | string | — | Path to PowerPoint file (.pptx) to convert |
| `--audience` | string | `general` | Target audience: `engineers`, `executives`, `sales`, `general` |
| `--style` | string | `clean` | Visual style: `clean`, `dark`, `glassmorphic`, `minimal`, `bold`, or custom CSS description |
| `--animations` | enum | `moderate` | Animation level: `none`, `minimal`, `moderate`, `rich` |
| `--slides` | int | auto | Target slide count |
| `--enhance` | flag | false | Enhance converted slides (improve layout, add animations) |
| `--preview` | flag | false | Generate first 3 slides for review before completing |
| `--output` | string | `presentation.html` | Output file path |
| `--aspect` | enum | `16:9` | Aspect ratio: `16:9`, `4:3` |
| `--notes` | flag | false | Include speaker notes (visible with `N` key) |

## Workflow

### Phase 1: Content Discovery
1. **Input analysis** — Parse the topic, outline, or PowerPoint content. Extract key messages, data points, and narrative structure.
2. **Structure** — Organize into a slide outline: title slide, section headers, content slides, and closing. Apply the story arc: hook, context, core content, takeaway.
3. **Content rules** — Apply anti-AI-slop guardrails:
   - No "In today's world..." or "Let's dive in" or "game-changer"
   - Maximum 5 bullet points per slide (prefer 3)
   - Every slide must have ONE clear takeaway
   - Data slides must have actual data, not vague claims
   - No orphan slides (every slide connects to the narrative)

### Phase 2: Style Discovery
4. **Audience calibration** — Adjust density, jargon level, and visual style for the target audience. Engineers get technical detail. Executives get high-level with numbers.
5. **Visual system** — Define: color palette, typography scale, spacing system, and animation library. Derive from `--style` parameter.
6. **Animation design** — Map animations to content purpose: entrance (reveal information progressively), emphasis (highlight key point), transition (move between topics). Never animate for decoration.

### Phase 3: Generation
7. **Generate HTML** — Build a single self-contained HTML file. Inline all CSS and JavaScript. No external dependencies. Include: slide navigation (arrow keys, click), progress indicator, fullscreen toggle (F key), speaker notes toggle (N key).
8. **Animate** — Apply CSS animations per the design. Use `@keyframes` and CSS transitions. Respect `prefers-reduced-motion`.
9. **Polish** — Final quality checks: consistent spacing, readable font sizes (minimum 24px body), proper contrast ratios, mobile-responsive, print stylesheet.
10. **Output** — Write the HTML file. Report slide count, file size, and feature list.

## Examples

### From-scratch presentation
```
/slides --topic "RAG Pipeline Architecture" --audience engineers --style dark --animations moderate

## Slides — RAG Pipeline Architecture

### Content Structure (12 slides)
1. Title: "RAG Pipeline Architecture"
2. Problem: Why vanilla LLMs fail on domain knowledge
3. Architecture overview: Retrieve → Augment → Generate
4. Retrieval deep-dive: Chunking strategies
5. Retrieval deep-dive: Embedding models + vector stores
6. Augmentation: Context assembly and ranking
7. Generation: Prompt construction with retrieved context
8. Evaluation: How to measure RAG quality
9. Failure modes: Common RAG pitfalls
10. Production considerations: Caching, latency, cost
11. Case study: Real metrics from production deployment
12. Takeaway + Resources

### Anti-slop checks
- ✓ No generic openers
- ✓ All slides have single takeaway
- ✓ Data slides contain specific numbers
- ✓ Animations serve content purpose

### Output
- File: presentation.html (47 KB)
- Slides: 12
- Animations: 23 (entrance: 15, emphasis: 5, transition: 3)
- Navigation: arrow keys, click, touch swipe
- Features: fullscreen (F), speaker notes (N), progress bar
```

## Output

```markdown
## Presentation Generated

- **File**: <path>.html
- **Slides**: N
- **File size**: N KB (zero dependencies)
- **Style**: <style>
- **Animations**: N total
- **Audience**: <audience>
- **Navigation**: Arrow keys, click, touch, fullscreen (F), notes (N)

### Slide Outline
1. <title> — <takeaway>
2. ...

### Quality Checks
- Anti-slop: PASS
- Contrast: PASS (WCAG AA)
- Motion: PASS (respects prefers-reduced-motion)
- Print: PASS (print stylesheet included)
```

## Dependencies

- Content source (topic, outline, or .pptx file)
- For PowerPoint conversion: ability to parse .pptx XML
- File system for writing output HTML
- No runtime dependencies in the output file (fully self-contained)
