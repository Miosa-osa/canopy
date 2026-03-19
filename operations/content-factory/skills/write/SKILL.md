# Write

## Command
/write <brief_title> [--format blog|guide|case-study|newsletter]

## Purpose
Produce content from brief to polished draft with SEO optimization and metadata.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| brief_title | string | Yes | Title or ID of the content brief |
| --format | string | No | Content format. Default: blog |

## Output
Genre: article
Format: Markdown draft with metadata

Produces:
1. **Draft Content** -- complete written piece per brief specifications
2. **5 Headline Options** -- for editor selection and testing
3. **Meta Description** -- under 160 characters, SEO-optimized
4. **Internal/External Links** -- placed naturally in content
5. **Social Excerpt** -- 1-2 sentence teaser for social promotion

## Agent Activation
1. **writer** (wave 1): Research + draft production
2. **seo-specialist** (wave 2): SEO optimization review

## Process
```
1. Load content brief from editor-in-chief
2. Writer researches and produces first draft
3. Writer self-edits (cut 20%, check readability, verify keywords)
4. SEO specialist reviews keyword placement and optimization
5. Submit to editor-in-chief for editorial review
```

## Examples
```
/write "7 SEO Mistakes That Kill Rankings"
/write "Q1 Customer Success Story" --format case-study
/write "Weekly Insights #42" --format newsletter
```
