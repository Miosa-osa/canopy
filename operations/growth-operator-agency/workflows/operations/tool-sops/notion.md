# Tool SOP — Notion

## Purpose
Notion is the team's long-term memory: SOPs, playbooks, decisions, meeting notes, client records. Slack is ephemeral; Notion is durable. This SOP defines the workspace structure, page templates, permissions, tagging, search, and archive rules so that anything written 2 years ago is still findable in 30 seconds.

## Workspace Structure

Top-level pages (one per area). Mirrors the Growth Operating Agency departments + operating needs.

```
/ Home
├── 01 — Company
│   ├── Mission + Values
│   ├── Org Chart
│   ├── Benefits + Policies
│   ├── Brand Guide
│   └── FAQ (for new hires)
│
├── 02 — Operations
│   ├── SOPs (by department)
│   ├── Meeting Notes (by cadence)
│   ├── Decisions Log
│   ├── Incidents (crisis post-mortems)
│   └── OKRs (current + archive)
│
├── 03 — Sales
│   ├── Playbook
│   ├── Scripts + Objection Library
│   ├── Pipeline Reporting
│   └── Win/Loss Library
│
├── 04 — Marketing
│   ├── Positioning
│   ├── Campaign Archive
│   ├── Creative Library
│   └── Analytics / Attribution
│
├── 05 — Content
│   ├── Content Plans (monthly)
│   ├── Content Calendar (live)
│   ├── Briefs Library
│   └── Hook / Title Library
│
├── 06 — Customer Success
│   ├── Playbook
│   ├── Client Records (restricted)
│   ├── Onboarding Templates
│   └── NPS + Feedback Log
│
├── 07 — Finance
│   ├── Monthly Snapshots (restricted)
│   ├── Budget + Plan (restricted)
│   ├── Vendor Inventory
│   └── Comp Bands (restricted)
│
├── 08 — People
│   ├── Team Directory
│   ├── Hiring (by role, active + archive)
│   ├── Onboarding Plans (by role)
│   ├── Reviews (per-person, restricted)
│   └── Policies
│
└── 09 — Archive
    ├── Year YYYY
    └── Year YYYY-1
```

## Page Templates (Ship With Workspace)

### SOP Template

```
# SOP: [Name]

**Owner:** [name]
**Last updated:** [date]
**Review cadence:** quarterly / 6-mo / yearly

## Purpose
[1-2 sentences — what problem this SOP solves]

## Trigger
[When does this SOP run — event, schedule, threshold]

## Inputs
- [list]

## Steps
1. [step]
2. [step]
3. [step]

## Outputs
- [list]

## Edge cases
- [case] → [action]

## Related
- [Link to related SOP or framework]

## Change log
- [date] — [change] — [who]
```

### Meeting Notes Template

```
# [Meeting name] — [date]

**Attendees:** [list]
**Driver:** [name]

## Agenda
- [item]

## Notes
[rich text notes]

## Decisions
1. [decision] — owner: [name]
2. [decision] — owner: [name]

## Actions
- [ ] [action] — [owner] — [due]

## Parked
- [item] — follow-up by [who]

## Recording
[Loom or Zoom link]
```

### Decision Log Entry

```
# Decision: [short title]

**Date:** [date]
**Decider:** [name]
**Type:** hire / fire / tool / strategy / comp / pricing / other

## Context
[What was the situation? 2-4 sentences]

## Options considered
1. [option] — pros / cons / effort
2. [option] — pros / cons / effort
3. [option] — pros / cons / effort

## Decision
[What was decided]

## Reasoning
[Why]

## Review date
[When to revisit — usually 90-180 days out]
```

### Client Record Template (restricted)

```
# Client: [name]

**Status:** Active / At-risk / Churned / Paused
**Signed:** [date]
**Program:** [offer]
**CS owner:** [name]

## Milestones
- [ ] [milestone] — [date]

## Touchpoints Log
[date — channel — summary]

## Risk signals
[bullet list]

## Upsell / referral opportunities
[bullet list]
```

## Permissions Model

Three tiers, enforced at the parent-page level:

| Tier | Access | Pages |
|---|---|---|
| Public (all team) | Read + comment | Company, Sales, Marketing, Content, Operations (SOPs) |
| Leadership | Read + edit | Decisions Log (edit), OKRs, Positioning |
| Restricted | Named list only | Finance, Reviews, Client Records, Comp Bands |

Permissions inherit down. Changes audited quarterly by Ops Mgr.

Guest access (contractors, clients): limited to specific pages, never top-level spaces. Revoked within 48h of role end.

## Tagging System

Notion databases (SOPs, Decisions, Meeting Notes, Content) use consistent tags for search.

### Universal tags
- Department: sales / marketing / content / cs / ops / finance / people / exec
- Status: draft / active / stale / archived
- Confidentiality: public / internal / restricted

### Database-specific tags

| Database | Extra tags |
|---|---|
| SOPs | frequency (daily / weekly / monthly / ad-hoc), owner |
| Decisions | decision type, status (open / decided / revisited) |
| Meeting Notes | cadence (daily / weekly / monthly / quarterly), meeting name |
| Content | format, platform, status, theme |
| Client Records | status, cohort, CS owner |

Tags set at page creation via template defaults. Consistent tags = reliable search.

## Search Practice

Notion search is strong but brittle without discipline.

**Good:** "SOP onboarding client"
**Bad:** "that thing we wrote about new clients"

Rules:
- Page titles include the key noun + modifier ("SOP — Client Onboarding" not "Onboarding")
- Rich text bodies start with the specific topic (Notion weights first paragraphs)
- Use the `/link` command to cross-reference rather than duplicating content
- Pin a "Finding things in Notion" guide in #team-general with the 10 most-searched topics

## Archive Rules

Pages archive, not delete. Quarterly audit by Ops Mgr.

- **Stale SOPs:** if not reviewed in 180 days, auto-tagged "Stale." Owner notified. If still stale at 270 days, moved to Archive.
- **Meeting notes:** older than 1 year moved to /09 Archive/YYYY
- **Completed projects:** full project page moved to Archive 90 days after close
- **Client records:** never archived while client is active; moved to Archive 1 year after churn (compliance caveat: consult legal)

## Templates as a Database Feature

Notion's template feature: every database has a template. Creators click "+ New from template" rather than "New page." This is enforced by:

- Making the database's default view "Create new → [Template]"
- Hiding raw "New" button via database settings
- Ops Mgr audits new pages monthly for template compliance

## Daily / Weekly Notion Practices

| Practice | Cadence | Who |
|---|---|---|
| Meeting notes captured in Notion | Live during meeting | Driver |
| Decisions logged | Within 24h of decision | Decider or Ops Mgr |
| SOPs reviewed | Per SOP's cadence (set on the SOP itself) | SOP owner |
| Workspace audit | Quarterly | Ops Mgr |
| New hire: read through Company + their department | Day 1-2 | New hire |

## Integrations

- **Slack:** share Notion link in channel, unfurls nicely
- **a productivity-software brand:** link Notion SOP from a productivity-software brand task when the task executes an SOP
- **Google Calendar:** meeting invites include Notion notes link 24h in advance
- **Loom:** Looms embed in Notion pages for video SOPs

## Metrics / Success Criteria
- Page creation 90%+ from templates (audited quarterly)
- Stale SOPs <5% of SOP library
- Search success: team reports finding docs in <60 sec for 85%+ of searches
- Decision log has ≥1 entry/week (signal decisions are happening + captured)
- Permissions audit quarterly, 0 orphaned guests

## Failure Modes
- **Wiki sprawl.** Every topic becomes a page; search dies. Fix: templates + tagging + quarterly audit.
- **Duplicate truth.** Same SOP in 3 places. Fix: link, don't copy; enforce one canonical source per topic.
- **Permissions drift.** Ex-contractor still has access. Fix: offboarding checklist + quarterly audit.
- **Notion as task system.** Checkboxes masquerade as tasks. Fix: tasks in a productivity-software brand; Notion is documentation.
- **Stale everything.** SOPs untouched for 2 years. Fix: the Stale auto-tag, owner notifications.

## Cross-references
- Skills: `skills/sop-writer/`, `skills/notion-template/`
- Frameworks: `frameworks/page-structure/`, `frameworks/permissions-model/`
- Other operations docs: `team-collaboration.md`, `tool-sops-slack.md`, `project-management-productivity-software.md`

---
*v1.0 — 2026-04-19.*
