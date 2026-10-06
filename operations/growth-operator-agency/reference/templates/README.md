# Reference Templates — Output Document Skeletons

> **Purpose:** artifact templates used as output skeletons by skills. Each skill's Output Format section references one of these. A template is the empty doc the creator (or an agent on their behalf) fills in.

## How to use

1. A skill runs and produces a filled-in instance of one of these templates at `output/{skill-slug}/{YYYY-MM-DD}-{artifact}.md`.
2. If you want to draft by hand, copy the raw template body into a new file under `output/{skill}/{date}-{name}.md` and fill the bracketed fields.
3. Every section marked `[FILL]` is a required field. `[OPTIONAL]` sections can be skipped with explicit justification.
4. Tables use `|` delimiters. Preserve the header row.
5. Where a template exposes a score or gate, the skill's SKILL.md defines the pass threshold.

## Index

### Foundations outputs

| # | Template | Source skill | Sections |
|---|---|---|---|
| 1 | [`market-research-brief.md`](./market-research-brief.md) | `/research` | 9 |
| 2 | [`icp-document.md`](./icp-document.md) | `/build-icp` | 13 |
| 3 | [`positioning-document.md`](./positioning-document.md) | `/build-positioning` | 7 |
| 4 | [`offer-document.md`](./offer-document.md) | `/design-offer` | 12 |
| 5 | [`brand-voice-document.md`](./brand-voice-document.md) | `/extract-voice` | 10 |

### Sales outputs

| # | Template | Source skill | Sections |
|---|---|---|---|
| 6 | [`vsl-script-template.md`](./vsl-script-template.md) | `/build-vsl` | 15-step |
| 7 | [`vsl-script-three-phase.md`](./vsl-script-three-phase.md) | `/build-vsl` (variant) | 3-phase |
| 8 | [`sales-page-template.md`](./sales-page-template.md) | `/build-funnel` (long-form variant) | long-form |
| 9 | [`funnel-blueprint-template.md`](./funnel-blueprint-template.md) | `/build-funnel` | 7-archetype |

### Nurture outputs

| # | Template | Source skill | Sections |
|---|---|---|---|
| 10 | [`webinar-script-three-secrets.md`](./webinar-script-three-secrets.md) | `/webinar-script` (variant) | three-secrets |
| 11 | [`webinar-script-challenge.md`](./webinar-script-challenge.md) | `/webinar-script` (variant) | multi-day-challenge |
| 12 | [`email-sequence-template.md`](./email-sequence-template.md) | `/email-sequence` | 8-email-type |
| 13 | [`lead-magnet-brief.md`](./lead-magnet-brief.md) | `/lead-magnet` | 9-type |

### Marketing outputs

| # | Template | Source skill | Sections |
|---|---|---|---|
| 14 | [`ad-creative-brief.md`](./ad-creative-brief.md) | `/ad-creative` | 8-ad-type |
| 15 | [`content-calendar-template.md`](./content-calendar-template.md) | `/content-calendar` | 30-day-4-pillar |

### Launch + scale outputs

| # | Template | Source skill | Sections |
|---|---|---|---|
| 16 | [`launch-plan-template.md`](./launch-plan-template.md) | `/plan-launch` | 5-phase |
| 17 | [`post-launch-report.md`](./post-launch-report.md) | `/launch-report` | analysis |
| 18 | [`case-study-template.md`](./case-study-template.md) | `/case-study` | before-after + ODO |
| 19 | [`testimonial-capture-kit.md`](./testimonial-capture-kit.md) | `/case-study` (capture phase) | video + written |

## When to create a template here

Create a template file in this directory when:

1. The output artifact is produced by one or more skills and the schema is stable across creator instantiations.
2. The template is referenced from one or more `SKILL.md` Output Format sections.
3. The template survives multiple runs without structural drift.

Single-skill ephemeral templates live inside that skill's own folder at `skills/{skill}/reference/template.md`.

## Relationship to other reference folders

- `../frameworks/` — methodology (the WHY behind a template)
- `../examples/` — completed example deliverables (calibration targets)
- `../knowledge/` — shared domain knowledge across skills
- `../../skills/{skill}/SKILL.md` — the canonical Output Format per skill (authoritative if conflicts with a template here)

## Filling templates by hand vs by skill

Skills fill templates with compartment-hydrated values, voice-accurate language, and gate-validated economics. Hand-filling a template is fine for a draft, but it does not pass the signal-score gate, the banned-vocab check, or the blind-output test until the skill re-runs on it.

---

*Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
