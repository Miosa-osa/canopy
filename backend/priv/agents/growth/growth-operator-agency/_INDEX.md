# Agents — Roster

> 41 agent persona files. Each is thin — identity + skills array + reporting chain. Business logic lives in `../skills/` and `../reference/frameworks/`; agents are personas that invoke skills.
>
> **Runtime:** all agents declare `adapter: any` — they work on any runtime that reads markdown + YAML.

## The reporting chain

```
growth-ceo (orchestrator)
├── foundations-head
│   ├── researcher
│   ├── niche-architect
│   ├── icp-builder
│   ├── offer-architect
│   └── brand-voice
├── marketing-head
│   ├── content-strategist
│   ├── youtube-producer
│   ├── short-form
│   ├── stories-producer
│   ├── twitter-writer
│   ├── linkedin-writer
│   ├── paid-ads
│   └── lead-magnet-designer (dual-report with nurture-head)
├── nurture-head
│   ├── email-copywriter
│   ├── webinar-producer
│   ├── show-rate-ops
│   └── post-launch-analyst (dual-report with launch-head)
├── sales-head
│   ├── vsl-builder (primary VSL architect, 5-variant selector)
│   ├── vsl-writer (executes variant chosen by vsl-builder)
│   ├── funnel-architect
│   ├── sales-scripter
│   ├── sales-ops
│   └── competitor-analyst
├── launch-head
│   └── launch-manager
├── partnerships-head
│   ├── jv-outreach
│   ├── affiliate-architect
│   └── referral-designer
└── scale-head
    ├── sop-builder
    ├── talent-recruiter
    ├── client-success
    ├── revenue-analyst
    ├── financial-modeler
    └── case-study-producer
```

## Roster by department

### Orchestrator (1)
| Agent | Skills | Tier |
|---|---|---|
| [`growth-ceo`](growth-ceo.md) | (delegates all) | L5 — top of chain |

### Foundations (6)
| Agent | Primary skill(s) | Reports to |
|---|---|---|
| [`foundations-head`](foundations-head.md) | (orchestrates 5 foundations skills) | growth-ceo |
| [`researcher`](researcher.md) | `/research` | foundations-head |
| [`niche-architect`](niche-architect.md) | `/build-positioning` | foundations-head |
| [`icp-builder`](icp-builder.md) | `/build-icp` | foundations-head |
| [`offer-architect`](offer-architect.md) | `/design-offer` | foundations-head |
| [`brand-voice`](brand-voice.md) | `/extract-voice` | foundations-head |

### Marketing (8)
| Agent | Primary skill(s) | Reports to |
|---|---|---|
| [`marketing-head`](marketing-head.md) | (orchestrates marketing skills) | growth-ceo |
| [`content-strategist`](content-strategist.md) | `/content-calendar` | marketing-head |
| [`youtube-producer`](youtube-producer.md) | `/write-youtube` | marketing-head |
| [`short-form`](short-form.md) | `/write-reel` | marketing-head |
| [`stories-producer`](stories-producer.md) | `/story-sequence` | marketing-head |
| [`twitter-writer`](twitter-writer.md) | `/write-x-thread` | marketing-head |
| [`linkedin-writer`](linkedin-writer.md) | `/write-linkedin-post` | marketing-head |
| [`paid-ads`](paid-ads.md) | `/ad-creative` | marketing-head |

### Nurture (5)
| Agent | Primary skill(s) | Reports to |
|---|---|---|
| [`nurture-head`](nurture-head.md) | (orchestrates nurture skills) | growth-ceo |
| [`email-copywriter`](email-copywriter.md) | `/email-sequence`, `/post-booking-nurture` | nurture-head |
| [`webinar-producer`](webinar-producer.md) | `/webinar-script` | nurture-head |
| [`show-rate-ops`](show-rate-ops.md) | `/post-booking-nurture` | nurture-head |
| [`lead-magnet-designer`](lead-magnet-designer.md) | `/lead-magnet` | marketing-head + nurture-head |

### Sales (7)
| Agent | Primary skill(s) | Reports to |
|---|---|---|
| [`sales-head`](sales-head.md) | (orchestrates sales skills) | growth-ceo |
| [`vsl-builder`](vsl-builder.md) | `/build-vsl` (architect) | sales-head |
| [`vsl-writer`](vsl-writer.md) | `/build-vsl` (writer — executes variant) | sales-head |
| [`funnel-architect`](funnel-architect.md) | `/build-funnel` | sales-head |
| [`sales-scripter`](sales-scripter.md) | (sales script skills) | sales-head |
| [`sales-ops`](sales-ops.md) | (sales operations skills) | sales-head |
| [`competitor-analyst`](competitor-analyst.md) | `/competitor-intel` | sales-head |

### Launch (3)
| Agent | Primary skill(s) | Reports to |
|---|---|---|
| [`launch-head`](launch-head.md) | (orchestrates launch skills) | growth-ceo |
| [`launch-manager`](launch-manager.md) | `/plan-launch` | launch-head |
| [`post-launch-analyst`](post-launch-analyst.md) | `/launch-report` | launch-head + nurture-head |

### Partnerships (4)
| Agent | Primary skill(s) | Reports to |
|---|---|---|
| [`partnerships-head`](partnerships-head.md) | (orchestrates partnerships skills) | growth-ceo |
| [`jv-outreach`](jv-outreach.md) | `/jv-webinar-proposal` | partnerships-head |
| [`affiliate-architect`](affiliate-architect.md) | `/affiliate-program` | partnerships-head |
| [`referral-designer`](referral-designer.md) | `/referral-program` | partnerships-head |

### Scale (7)
| Agent | Primary skill(s) | Reports to |
|---|---|---|
| [`scale-head`](scale-head.md) | (orchestrates scale skills) | growth-ceo |
| [`sop-builder`](sop-builder.md) | `/build-sop` | scale-head |
| [`talent-recruiter`](talent-recruiter.md) | `/hiring-brief` | scale-head |
| [`client-success`](client-success.md) | `/retention-check` | scale-head |
| [`revenue-analyst`](revenue-analyst.md) | `/revenue-report` | scale-head |
| [`financial-modeler`](financial-modeler.md) | (financial modeling) | scale-head |
| [`case-study-producer`](case-study-producer.md) | `/case-study` | scale-head |

## Frontmatter schema

Every agent file MUST have:

```yaml
---
name: "Display Name"
id: agent-slug
role: orchestrator | lead | strategist | specialist | architect | analyst
title: "Display Title"
reportsTo: parent-agent-id | null
budget: <USD per month>
color: "#hex"
emoji: "🎬"
adapter: any
signal: S=(mode, genre, type, format, structure)
tools: [read, write, search, delegate?]
skills: [skill-slug, ...]
context_tier: l0 | l1 | full
department: foundations | marketing | nurture | sales | launch | partnerships | scale | null
---
```

Body sections: Identity (Personality + Memory + Experience) → Core Mission → Critical Rules → Handoff Protocol.

## Cross-References

- `../skills/_INDEX.md` — skill catalog this roster invokes
- `../SYSTEM.md` — routing logic + boot sequence
- `../INVARIANTS.md` — the 14 sacred rules every agent inherits
- `../reference/knowledge/` — department-level shared knowledge

---
*v1.0.0 — 2026-04-21 — 41 agents (1 director + 7 department heads + 33 specialists).*

*Growth Operating Agency — a Heuresis workspace template. [heuresis.ai](https://heuresis.ai)*
