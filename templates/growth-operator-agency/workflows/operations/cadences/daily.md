# Daily Cadences

## Purpose
The daily rhythm for a Growth team. Five cadences keep the business moving without pulling everyone into meetings. Most run async; only the morning check is live. If your team is spending more than 45 minutes/day in daily cadences, you've added meetings that shouldn't exist.

## Cadence Overview

| Cadence | Time (PT) | Duration | Format | Participants |
|---|---|---|---|---|
| Morning check | 8:00am | 15 min | Live standup | Full team |
| Async update | By 10:00am | 5 min/person | Written Slack | Full team |
| DM Setter cadence | 9:00am + 2:00pm | 10 min each | Async | Setters + Sales lead |
| Sales daily | 4:30pm | 15 min | Live standup | Setters + Closers + Sales lead |
| CS daily | 4:00pm | 15 min | Live standup | CS team |

Times shown in Pacific. Shift to your team's dominant time zone; protect a 3-hour team overlap for the live cadences.

---

## 1. Morning Check (8:00am PT, 15 min)

**Participants:** Full team, Operator drives
**Agenda (strict, 15 min hard stop):**
- 0:00-0:05 — Numbers: yesterday's revenue, calls booked, pipeline added (1 slide or Slack post)
- 0:05-0:12 — Round robin: each person gives 1 focus for the day (1 sentence each, 30 sec max)
- 0:12-0:15 — Operator announces the one thing that matters today

**Outputs:**
- Slack post in #team-daily with the numbers + focus list
- Action items go into a productivity-software brand, not the meeting notes
- Any topic that needs >60 seconds is parked to a follow-up call booked in the meeting

**Rules:**
- Camera on for full-time staff, off OK for contractors
- No laptops open except for the Driver (Operator)
- Starts on the dot; late = you join silently, don't re-open prior topic

---

## 2. Async Update (By 10:00am PT, 5 min each)

**Participants:** Everyone, posted to #async-update channel
**Format (Slack post, copy this template):**

```
🟢 [name] — [date]
Yesterday: [1-2 bullets on what shipped]
Today: [1-2 bullets on focus]
Blocks: [none / specific ask + who]
Number I own today: [metric + target]
```

**Outputs:**
- Searchable log of team activity
- Replaces most "what are you working on?" DMs
- Operator reads all updates by 11am

**Rules:**
- Not a status for the boss — it's for teammates to stay aligned
- If you miss your async update, flag in #async-update by end of day
- Blocks older than 24h get escalated by the author

---

## 3. DM Setter Cadence (9:00am + 2:00pm PT, 10 min each)

**Participants:** Setters + Sales lead (Closer or Ops Mgr)
**9:00am huddle agenda (10 min):**
- Yesterday's numbers: DMs sent, replies, calls booked, show rate (2 min)
- Today's target: DMs to send, calls to book (2 min)
- Script/offer changes for today (2 min)
- Objection of the day + reframe (3 min)
- Volume pacing check (1 min)

**2:00pm check-in agenda (10 min):**
- Pacing vs target (AM actuals) (3 min)
- One win from the morning + one learn (4 min)
- Afternoon plan adjustment (3 min)

**Outputs:**
- Setter scoreboard updated (Notion or a productivity-software brand dashboard)
- New objection + reframe added to objection library
- Slack post in #sales-pipeline with end-of-day totals

**Rules:**
- Huddles on Zoom with cameras on — builds the energy a setter floor needs
- Walk-on music + wins read aloud = not optional, this is intentional culture
- Missed huddle = no commission counted for that day's bookings

---

## 4. Sales Daily (4:30pm PT, 15 min)

**Participants:** Setters + Closers + Sales lead
**Agenda:**
- 0:00-0:03 — Revenue today: closed amount, collected amount, pipeline added
- 0:03-0:08 — Closer round: each Closer reports calls taken, closes, key objections
- 0:08-0:11 — Setter round: each Setter reports bookings, show rate, top lead qualifier
- 0:11-0:14 — Tomorrow's pipeline: who's on the calendar, any risks
- 0:14-0:15 — Coaching moment: 1 lesson from today, named by Sales lead

**Outputs:**
- Pipeline dashboard updated (GHL or CRM, see `tool-sops-ghl.md`)
- Next-day calendar confirmed with call owners
- Coaching topic logged for Friday sales review

**Rules:**
- 15 min hard stop
- Coaching goes 1:1 after the cadence, not in the room
- Numbers are public; frame objections as learnings

---

## 5. CS Daily (4:00pm PT, 15 min)

**Participants:** CS Mgr + coaches + any active CS reps
**Agenda:**
- 0:00-0:03 — Ticket status: open, resolved today, aging >48h (CS Mgr)
- 0:03-0:08 — At-risk client review: any red/yellow accounts (round robin)
- 0:08-0:12 — Wins + case-study candidates
- 0:12-0:14 — Tomorrow's calls: who's running what, any escalations
- 0:14-0:15 — NPS or feedback pulse (1 item)

**Outputs:**
- Ticket queue clean-status in Slack #cs-internal
- At-risk list updated in CS tracker
- Case-study candidates flagged to Content Mgr (handoff per `team-collaboration.md`)

**Rules:**
- At-risk always first, wins always last — mood matters
- Escalations requiring Operator flagged in #cs-escalations within 1 hour of the call ending
- No client names shared in cross-team channels, only in CS channels

---

## Operator's Day (Reference)

What the Operator actually does during the daily rhythm.

| Time | Activity |
|---|---|
| 7:45am | Personal prep: review dashboards, one priority for the team |
| 8:00am | Morning check (leads) |
| 8:30am-11:00am | Deep work block (most important 1 thing) |
| 11:00am-12:00pm | 1:1s (one per day, rotating across reports) |
| 12:00-1:00pm | Lunch / walk / think |
| 1:00-4:00pm | Meetings, decisions, operator work |
| 4:00pm | CS daily (listens only, does not drive) |
| 4:30pm | Sales daily (listens only, does not drive) |
| 5:00-6:00pm | End-of-day: recap, tomorrow's top 1, inbox to zero |

If the Operator is driving both sales and CS daily cadences, you are still in Build/Systemize mode — see `mode-of-operations.md`.

## Metrics / Success Criteria
- Morning check start time ≤8:00am PT, 90%+ of days
- Async update completion rate >95%
- Sales daily completed before 5:00pm PT, 90%+ of days
- Total daily meeting load per person <45 min
- Setter huddle attendance >95%
- Escalations flagged within 1 hour of the triggering cadence

## Failure Modes
- **Cadence creep.** 15 min becomes 35 min. Fix: hard-stop timer, topics get parked.
- **Numbers not ready.** Morning check starts without numbers. Fix: dashboard auto-refresh by 7:50am; owner is named.
- **Async update skipped.** Fix: weekly review in Friday leadership — missed updates visible.
- **Sales daily becomes coaching.** Fix: coaching moves to 1:1 after the cadence.
- **CS daily hides red accounts.** Fix: red/yellow list is written, not spoken — you can't hide in writing.

## Cross-references
- Skills: `skills/daily-standup/`, `skills/async-update/`
- Frameworks: `frameworks/meeting-hygiene/`, `frameworks/setter-scorecard/`
- Other operations docs: `cadences-weekly.md`, `team-collaboration.md`, `daily-dashboard.md`, `tool-sops-slack.md`

---
*v1.0 — 2026-04-19.*
