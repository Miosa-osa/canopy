# Team Collaboration

## Purpose
Operating norms for how a 2-15 person Growth team communicates, decides, and hands off work. Reduces the "Slack all day, ship nothing" failure mode by forcing defaults: async first, sync only for decisions, writing beats talking.

## Async vs Sync — Default Assignments

Async is the default. Sync is a tax, and the tax must be justified.

| Work Type | Default | Tool | Why |
|---|---|---|---|
| Status update | Async | Slack thread or Notion | Nobody needs to be in a room for "I shipped X" |
| Information sharing | Async | Loom + Notion | Search beats memory; watch at 1.5x |
| Yes/no decision | Async | Slack thread with RACI | Write the decision; approval in thread |
| Tradeoff decision with 3+ options | Sync | 30-min video call | Dialog beats writing for complex tradeoffs |
| 1:1 feedback | Sync | Video, camera on | Feedback without tone = damaged relationships |
| Brainstorm (open-ended) | Sync | 60-min whiteboard | Low-structure idea-gen is worse async |
| Kickoff for >2-week project | Sync | 45-min call | Alignment expensive to recover later |
| Retro | Sync | 60-min call, with pre-read | Needs dialog, pre-read cuts time in half |
| Incident response | Sync (war room) | Slack huddle + Notion | See `crisis-management.md` |

## Communication Channels — When to Use What

| Channel | Use For | Response SLA |
|---|---|---|
| Slack DM | Urgent, personal, <24h decision needed | 2 working hours |
| Slack channel (#team-general) | Team-wide info, non-urgent | Same day |
| Slack channel (#department-*) | Department-specific work | Same day |
| Slack channel (#alerts-*) | Automated alerts, on-call | 15 min on-call, 2h off |
| Loom | Demos, walkthroughs, async feedback | 24h to watch + reply |
| Notion doc comment | Structured feedback on deliverable | 48h |
| Email | External only (clients, vendors) | 24h |
| Video call | Decisions, feedback, sensitive topics | Scheduled |
| Phone call | Reserved for genuine emergency | Immediate |

See `tool-sops-slack.md`, `tool-sops-loom.md`, `tool-sops-notion.md` for depth.

## Meeting Hygiene — The 5 Rules

1. **Every meeting has a written agenda in the calendar invite.** No agenda = cancelled meeting, no consequence to the canceler.
2. **Every meeting has a named Driver.** Driver runs the clock, assigns actions, writes recap within 24h.
3. **Default duration is 25 or 50 minutes**, not 30 or 60. 5-minute buffer protects the next meeting.
4. **Pre-read for any meeting >30 minutes.** Sent 24h in advance. First 5 minutes of meeting is silent reading if anyone shows up unprepared.
5. **Every meeting ends with: "Who owns what by when?"** Actions captured live, posted in Slack channel same day.

### Meeting Recap Template (24h after meeting)

```
Meeting: [name]
Date: [date]
Attendees: [names]
Decisions made:
  1. [decision] — owner: [name]
  2. [decision] — owner: [name]
Actions:
  - [ ] [action] — [owner] — [due date]
  - [ ] [action] — [owner] — [due date]
Parked (not decided today): [items + who follows up]
Link to full notes: [Notion URL]
```

## RACI by Decision Type

RACI = Responsible, Accountable, Consulted, Informed. A=1 and only 1.

| Decision Type | R | A | C | I |
|---|---|---|---|---|
| Hire any role | Hiring mgr | Operator | CFO, team lead | Full team |
| Fire any role | Direct mgr | Operator | HR/legal | Full team (post-fact) |
| Comp change >10% | Direct mgr | Operator | CFO | Affected person |
| New tool spend >$200/mo | Requester | Operator | CFO | Team |
| Content publish (owned channels) | Content Mgr | Content Mgr | Operator (spot-check) | Team |
| Content publish (PR/press) | PR lead | Operator | Legal if applicable | Team |
| Pricing change | Ops Mgr | Operator | CFO, Closer | CS team + customers |
| Customer refund >$500 | CS Mgr | CS Mgr | Operator (FYI) | Finance |
| Customer refund >$5k | CS Mgr | Operator | CFO | Finance |
| New service offer | Operator | Operator | Closer, CS Mgr, CFO | Full team |
| Campaign launch | Marketing Mgr | Marketing Mgr | Operator | Team |
| Paid ad budget change >20% | Ad Buyer | Marketing Mgr | CFO | Operator |
| Roadmap priority change | Ops Mgr | Operator | Department leads | Full team |

Disagreements escalate to the Accountable. If Accountable disagrees with Consulted, Accountable decides and documents why.

## Handoff Pattern — The 4-Part Handoff

When work crosses roles (e.g., Setter → Closer, Closer → CS, Content Mgr → Video Editor), use this format. No exceptions.

```
HANDOFF: [from role] → [to role]
Context:
  - Who: [person/account name]
  - What's happened so far: [2-3 bullets]
  - Deadline / urgency: [date + why]
Artifact(s):
  - [Link to recording]
  - [Link to doc]
  - [Link to CRM record]
Request (what you need from receiver):
  - [specific ask, 1 line]
Success criteria:
  - [how we know the handoff worked, 1 line]
```

Post in the destination channel (e.g., #sales-pipeline, #cs-onboarding), not DM. Visibility catches errors early.

## Documentation Standards

- **Every process done 3x gets a written SOP.** See `skills/sop-writer/`.
- **SOPs live in Notion**, organized by department (see `tool-sops-notion.md`).
- **SOP format:** Purpose → Trigger → Inputs → Steps (numbered) → Outputs → Edge cases → Owner → Last updated.
- **Review cadence:** each SOP owner reviews their SOPs every 90 days. Stale = older than 180 days, flagged in monthly business review.
- **Loom-first documentation:** record the task while doing it; transcribe; edit into SOP. Much faster than writing from scratch — most SOPs ship in under 30 minutes this way.

## Written Weekly Update (Every Report, Every Friday by 3pm Local)

Replaces "what did you do this week" in 1:1s. One Slack post in #weekly-updates, or one Notion page.

```
WEEKLY UPDATE — [name] — Week of [date]
1. Numbers I own (actual / target):
   - [metric]: [actual] / [target]
2. Shipped this week:
   - [item]
3. Shipping next week:
   - [item]
4. Blocks / asks:
   - [specific ask + who from]
5. One thing I learned:
   - [one line]
```

## Time Zones + Working Hours

- Declare working hours in Slack profile. Format: `Working hours: 9am-6pm PT`.
- "Do not disturb" on Slack outside working hours is respected, not rewarded-for-violating.
- Overlap window: if team spans time zones, protect a minimum 3-hour daily overlap window (written in the team handbook).
- Meetings scheduled inside overlap window only, unless pre-agreed.

## Metrics / Success Criteria
- Meeting load per person <10 hours/week
- 90%+ meetings have pre-circulated agenda
- SOP library grows by 2+ SOPs/month in first year
- Weekly update completion rate >95%
- Slack response SLA met 90%+ of the time (sampled monthly)
- Async-first: <30% of decisions require a live meeting (sampled quarterly)

## Failure Modes
- **Slack becomes the task system.** Fix: move work to a productivity-software brand, treat Slack as a notification layer.
- **Meetings multiply.** Fix: quarterly meeting audit; cancel anything without a clear owner + agenda.
- **Decisions re-litigated.** Fix: enforce "decisions made" section in recaps; point back when re-opened.
- **Documentation debt.** Fix: SOP-writing block, 2h/week, non-negotiable, on Operator's calendar.
- **Heroes and bottlenecks.** One person knows everything, handoffs fail when they're out. Fix: mandatory backup owner on every SOP.

## Cross-references
- Skills: `skills/sop-writer/`, `skills/meeting-recap/`, `skills/async-update/`
- Frameworks: `frameworks/raci/`, `frameworks/handoff-template/`
- Other operations docs: `team-leadership.md`, `tool-sops-slack.md`, `tool-sops-loom.md`, `tool-sops-notion.md`, `cadences-daily.md`

---
*v1.0 — 2026-04-19.*
