# Ideate

## Command
/ideate <topic> [--pillar <pillar>] [--count <n>]

## Purpose
Generate content ideas with angle, target audience, platform fit, and SEO potential.

## Arguments
| Arg | Type | Required | Description |
|-----|------|----------|-------------|
| topic | string | Yes | Topic area to ideate around |
| --pillar | string | No | Content pillar to align with |
| --count | integer | No | Number of ideas to generate. Default: 5 |

## Output
Genre: pitch
Format: Markdown idea cards

Produces:
1. **Content Ideas** -- each with title, angle, audience, format, platform, SEO keyword
2. **Priority Ranking** -- ordered by estimated impact (search volume + relevance + gap)
3. **Calendar Fit** -- where each idea fits in the editorial calendar

## Agent Activation
1. **seo-specialist** (wave 1): Keyword research for topic area
2. **editor-in-chief** (wave 1): Audience alignment and editorial calendar fit

## Process
```
1. SEO specialist researches keyword opportunities around the topic
2. Editor-in-chief evaluates audience need and calendar gaps
3. Generate ideas that combine search demand with audience interest
4. Rank by estimated impact
5. Check against existing content to avoid duplication
```

## Examples
```
/ideate "content marketing"
/ideate "AI automation" --pillar thought-leadership --count 10
/ideate "remote work" --pillar evergreen-seo
```
