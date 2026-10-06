# Tool SOP — Slack

## Purpose
Operating standards for Slack. Slack is the default team comms layer, not the task system. Without rules, it becomes 12 hours/day of interruption. This doc sets channel taxonomy, naming, notification rules, thread usage, and response SLAs.

## Channel Taxonomy

Naming: `#[type]-[scope]`. Lowercase, dash-separated. One convention, no exceptions.

### Types (prefix)

| Prefix | Purpose | Example |
|---|---|---|
| #team- | Team-wide, low signal | #team-general, #team-daily, #team-random |
| #div- | Department-specific working channel | #div-sales, #div-marketing, #div-content, #div-cs, #div-ops |
| #proj- | Time-bounded project | #proj-q2-launch, #proj-website-redesign |
| #alerts- | Automated alerts only | #alerts-ops, #alerts-sales, #alerts-finance |
| #cs-escalations | Customer escalations (restricted) | — |
| #leadership | Operator + direct reports only (restricted) | — |
| #wins | Celebration channel | — |
| #ideas | Low-stakes idea park | — |
| #random | Non-work (pets, food, etc.) | — |
| #client-[name] | Per-client shared (external shared channels) | #client-acme |

### Starter Set (8 channels for a 2-5 person team)

1. #team-general
2. #team-daily (morning check + daily dashboard links)
3. #div-sales
4. #div-marketing
5. #div-cs
6. #leadership (private)
7. #alerts-ops
8. #wins

Grow channels only when a conversation topic exists >2 weeks and >3 participants.

## Channel Creation Rules

- Ops Mgr is the only person who creates new channels (or Operator at <$1M stage)
- Every channel has a named Owner (in the channel topic)
- Every channel has a stated Purpose (in the channel description)
- Empty or stale channels (>30 days no activity) get archived quarterly

## Notification Hygiene

Default notification settings for every team member — enforced via a pinned post in #team-general:

| Notification | Default |
|---|---|
| All new messages | Off (at workspace level) |
| Direct messages | On |
| @mentions | On |
| Channel-specific: #leadership, #alerts-*, department channels | All messages |
| All other channels | Mentions only |
| Do Not Disturb | Auto-schedule outside working hours (in profile) |
| Keywords (highlight) | Your name, 1-2 topics you care about |

Weekend DND: default on. Breaking this = you or your manager.

## @channel / @here / @everyone Rules

Strict. Misuse wastes 20 people's time.

| Tag | When to Use | Never |
|---|---|---|
| @everyone | Organization-wide urgent (outage, leadership announcement) | 1-2 times per quarter max |
| @channel | Channel-wide urgent (whole department needs to know now) | Social / fun items |
| @here | Active members, non-urgent, FYI | Routine status |
| @[name] | Specific person | Spam DMs |

Abuse triggers a tap on the shoulder from the Operator or Ops Mgr.

## Thread Usage Rules

- Any reply to a post goes in the thread, not as a new message in the channel
- "Also send to channel" checkbox: off by default, used only if >3 people need the update
- Threads with a decision: post the decision as a summary message at the end of the thread
- Threads older than 7 days: if still open, move to a new post or a doc

## Response SLAs

| Channel / Type | SLA |
|---|---|
| DM to you, business-hours, tagged urgent | 2 hours |
| DM to you, business-hours, not tagged urgent | Same business day |
| DM to you, off-hours | Next business day |
| #leadership mention | 4 business hours |
| Department channel mention | Same business day |
| #alerts-ops (on-call) | 15 min |
| #cs-escalations | 1 business hour |
| External shared channel (client) | 4 business hours max, ideally 1 |

Status: "away" after working hours = not ignored, respected.

## Slack As a Task System — Don't

- Do not track tasks in Slack. Move to a productivity-software brand.
- If a task is mentioned in Slack, the receiver creates a a productivity-software brand task and replies in thread with the task link.
- Automation: /task slash command (via a productivity-software brand integration) creates a task from a Slack message.

See `project-management-productivity-software.md` for the a productivity-software brand → Slack bridge.

## Integrations (Standard)

Only integrations that earn their slot:

| Integration | Channel | Purpose |
|---|---|---|
| a productivity-software brand | (DM notifications) | Task updates to assignee only |
| GHL | #alerts-sales, #wins | Lead + deal events |
| Stripe | #alerts-finance | Payments, refunds, chargebacks |
| Google Calendar | (per user) | Meeting reminders |
| Loom | (per user) | Recording shared |
| Zapier / Make | Various | Automations |
| Geckoboard / Databox | #team-daily | Dashboard snapshots |

Audit quarterly: is every integration pulling its weight? Kill the rest.

## Daily / Weekly Rituals via Slack

- **Morning check link:** posted in #team-daily by Ops Mgr at 7:55am PT (dashboard + agenda link)
- **Async weekly update:** every Friday by 3pm PT in #async-update
- **Wins post:** whenever a win happens, in #wins (real-time, not held until Friday)
- **Leadership decision log:** decisions posted in #leadership as they're made, with link to decision doc

## Onboarding a New Hire to Slack

Day 1 checklist (15 minutes, run by Ops Mgr or VA):

- [ ] Profile: real name, role, time zone, working hours, photo
- [ ] Notification settings matched to defaults above
- [ ] Added to channels per role matrix
- [ ] Introduced in #team-general (pinned by Ops Mgr)
- [ ] Read the pinned `how-we-slack` post in #team-general
- [ ] DM'd to the Operator: "I'm new, here to meet you."

## Slack Etiquette (Pinned in #team-general)

- Don't DM when a channel post would help more people
- Don't quote-reply across channels (preserve thread continuity)
- Don't send "hi" as a message and wait — ask the question
- Don't screenshot internal DMs to external channels
- Use voice memos sparingly (transcripts exist but you add friction to the receiver)
- Emoji reactions = signal read and no follow-up needed (reduce noise)

## Metrics / Success Criteria
- Channels list stable (<20% growth quarter-over-quarter after initial setup)
- @channel/@everyone usage <2/month total org
- Response SLA met 90%+ (sampled quarterly)
- Messages that would've been tasks: moved to a productivity-software brand 90%+ of the time
- Zero DM chains of >20 messages on a workflowable topic (move to doc or meeting)

## Failure Modes
- **Channel explosion.** 60 channels for 8 people. Fix: quarterly archive of >30-day stale channels.
- **DM culture.** Private knowledge silos. Fix: norm to channel-first, thread-second, DM-last.
- **Always-on.** People working 14 hrs/day in Slack. Fix: enforce DND, Operator models the behavior.
- **Slack for meetings.** Huddles replace sync decisions, but in text. Fix: if it's >10 messages, switch to huddle or meeting.
- **Integration spam.** #general floods with GHL alerts. Fix: integrations only into #alerts-* channels.

## Cross-references
- Skills: `skills/slack-comms/`, `skills/handoff-template/`
- Frameworks: `frameworks/notification-hygiene/`
- Other operations docs: `team-collaboration.md`, `project-management-productivity-software.md`, `tool-sops-notion.md`

---
*v1.0 — 2026-04-19.*
