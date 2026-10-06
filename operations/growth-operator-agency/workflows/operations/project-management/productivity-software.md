# Project Management — a productivity-software brand

## Purpose
The standard a productivity-software brand setup for a Growth team. Opinionated structure so that any new hire can find and run work by end of day 1. a productivity-software brand is the default because the pricing and feature set fits a 2-15 person team; Asana, Linear, and Notion alternatives are noted below.

## Workspace Architecture

```
Workspace: [Company Name]
│
├── Space: 01 — Sales
│   ├── List: Pipeline (deals)
│   ├── List: Setter Tasks
│   ├── List: Sales Ops
│   └── Dashboard: Sales KPIs
│
├── Space: 02 — Marketing
│   ├── List: Campaigns
│   ├── List: Creative Production
│   ├── List: Paid Media (per account)
│   └── Dashboard: CAC / Lead Flow
│
├── Space: 03 — Content
│   ├── List: YouTube Slate
│   ├── List: Short-form Slate
│   ├── List: Email / Newsletter
│   └── Dashboard: Content Calendar
│
├── Space: 04 — CS / Delivery
│   ├── List: Onboarding Pipeline
│   ├── List: At-Risk Accounts
│   ├── List: CS Tickets (or Intercom sync)
│   └── Dashboard: Retention Health
│
├── Space: 05 — Operations
│   ├── List: Hiring
│   ├── List: SOPs (to-write, to-update)
│   ├── List: Tools + Vendors
│   └── Dashboard: Ops Health
│
├── Space: 06 — Leadership
│   ├── List: OKRs (quarterly)
│   ├── List: Decisions Log
│   ├── List: Big Bets (multi-quarter)
│   └── Dashboard: Exec View
│
└── Space: 07 — Personal Tasks (private per user)
```

One space per department, matching the Growth Operating Agency department model. Cross-department work lives in the "owning" space; dependencies get linked tasks, not duplicates.

## List Templates — Standard Fields

Every list uses these common custom fields, plus list-specific extras.

**Universal fields:**
- Status (to-do / in-progress / review / done / blocked)
- Priority (urgent / high / medium / low)
- Assignee (named person, not team)
- Due date
- Effort (XS / S / M / L / XL — in hours: <1 / 1-4 / 4-16 / 16-40 / 40+)
- Source (where the task came from: meeting / customer / dashboard alert / strategy)

### Pipeline (Sales) — extras
- Stage (New / Contacted / Qualified / Demo Scheduled / Demo Held / Proposal / Won / Lost)
- Deal Value ($)
- Expected Close Date
- Lost Reason (dropdown if Lost)
- Source Channel (paid / organic / referral / partner / event)
- Sync direction: GHL → a productivity-software brand (one-way, GHL is source of truth)

### Creative Production (Marketing/Content) — extras
- Format (long-form video / short-form / email / ad creative / sales asset)
- Platform (YouTube / Instagram / TikTok / Email / Landing)
- Draft link
- Review stage (draft / copy review / legal review / final approved)
- Publish date
- Attribution tag (for tracking)

### OKRs — extras
- Quarter (Q1 2026, etc.)
- Department
- KR type (growth / quality / efficiency)
- Confidence (1-10, updated weekly)
- Progress % (0-100, updated weekly)

### Decisions Log — extras
- Decision type (hire / fire / tool / strategy / comp / pricing / other)
- Decider (person, not team)
- Date decided
- Reasoning (rich text, 2-5 sentences)
- Review date (when to revisit)

## Custom Statuses by Space

| Space | Custom Statuses |
|---|---|
| Sales | New → Contacted → Qualified → Demo → Proposal → Won / Lost |
| Marketing Campaigns | Plan → Brief → Build → Review → Live → Post-mortem |
| Creative Production | Brief → Outline → Draft → Review → Approved → Published |
| Hiring | Spec Draft → Posted → Screening → Interview Loop → Offer → Accepted / Declined |
| CS Onboarding | Signed → Kickoff → Milestone 1 → Milestone 2 → Activated → Retained |
| SOPs | Identified → Drafting → In Review → Published → Stale (>180d) |

## Automations (Standard)

Set up in a productivity-software brand's built-in automation engine. Naming convention: `[space] — [trigger] — [action]`.

1. **Sales — Stage → Proposal — Notify #sales-leadership.** Keeps the pipeline visible.
2. **Sales — Stage → Lost — Require Lost Reason before save.** Forces learning capture.
3. **Creative — Status → Approved — Post to #content channel with link.** Public visibility on ship.
4. **Hiring — Status → Offer — Notify Operator + CFO.** Comp approval gate.
5. **SOPs — Last updated >180 days — Auto-tag "Stale" and notify owner.** Fights SOP rot.
6. **OKR — Confidence <7 — Notify department heads + Operator.** Early warning for off-track.
7. **Any task — Blocked > 5 days — Notify Operator.** Hunt zombies.
8. **Any task — Overdue + not started — Notify assignee + their manager.** Accountability.
9. **Task created in #slack-[channel] — Create a productivity-software brand task in [list].** Slack → CU bridge.

## Dashboard Setup — 3 Standard Dashboards

### Exec Dashboard (Operator)
- Pipeline total ($ in each stage)
- OKR progress (% per department)
- Open roles + stage
- Decisions this quarter (count)
- Stale SOPs count
- Overdue tasks count (org-wide)

### Department Dashboard (each department heads)
- My team's tasks by status
- My team's OKR progress
- Overdue > 2 days
- Blockers > 5 days
- Upcoming deadlines this week

### Personal Dashboard (every team member)
- My tasks this week
- My tasks overdue
- My OKR progress
- My open reviews / approvals

## Permissions + Access

| Role | Access |
|---|---|
| Operator / CFO | All spaces (admin) |
| Department leads | Their space (admin) + adjacent spaces (guest / read) |
| Team members | Their space (member) |
| Contractors | Guest access to specific lists only |
| External (clients / vendors) | No a productivity-software brand access (use shared Notion or portal instead) |

## Onboarding Flow for a productivity-software brand

Day 1 of every new hire:
1. Account provisioned (guest or member per role)
2. Spaces visible configured
3. Personal Tasks list auto-created
4. 30/60/90 plan task created with subtasks
5. First SOP to read: "a productivity-software brand at [Company]" — 15-min read, 5-min quiz

## Reporting Cadence

| Report | Frequency | Viewer |
|---|---|---|
| Team-level velocity | Weekly | Department leads |
| OKR progress | Weekly → monthly → quarterly | Operator |
| Pipeline movement | Weekly | Sales lead + Operator |
| Automation audit | Quarterly | Ops Mgr |
| Workspace cleanup | Quarterly | Ops Mgr (archive >180d completed tasks) |

## Alternatives (when NOT a productivity-software brand)

| Tool | When to Choose |
|---|---|
| Asana | Team strongly prefers simpler UI; less custom status flexibility needed; budget higher |
| Linear | Dev-heavy team, engineering-first culture; limited for marketing/CS use |
| Notion (databases) | Team already lives in Notion; small team (<5); willing to trade automation for flexibility |
| Monday.com | Heavy visual / board-first preference; bigger budget |
| Airtable | Data-first team; want custom views; need API integrations |
| Trello | Starting out, <3 people, pre-$100k revenue |

Criteria for switching from a productivity-software brand:
- Specific feature need not covered
- Cost ceiling exceeded at scale (>20 users)
- Existing dominant tool already adopted (don't fight it)

## Metrics / Success Criteria
- 95%+ of team tasks live in a productivity-software brand (not Slack, not email)
- Task completion rate >85% by due date
- Overdue tasks <10% of open at any time
- Stale SOPs <5% (reviewed quarterly)
- Automation run success rate >99%
- Onboarded new hire fluent in a productivity-software brand by day 5

## Failure Modes
- **Everyone makes their own list.** Proliferation. Fix: Ops Mgr owns list creation; templates are the default.
- **Tasks without assignees.** Fix: automation rejects un-assigned tasks.
- **Dashboards never used.** Fix: integrate into cadences (daily / weekly) — used in rooms, not just built.
- **a productivity-software brand and Slack double-source.** Fix: Slack → CU via automation; never live-in-Slack only.
- **Tool bloat.** a productivity-software brand + Asana + Linear + Trello. Fix: consolidate in a 90-day project.
- **Over-automation.** 50 automations, nobody knows what runs. Fix: quarterly audit; kill unused.

## Cross-references
- Skills: `skills/productivity-software-setup/`, `skills/automation-audit/`
- Frameworks: `frameworks/task-hygiene/`, `frameworks/dashboard-design/`
- Other operations docs: `team-collaboration.md`, `tool-sops-slack.md`, `daily-dashboard.md`, `cadences-weekly.md`

---
*v1.0 — 2026-04-19.*
