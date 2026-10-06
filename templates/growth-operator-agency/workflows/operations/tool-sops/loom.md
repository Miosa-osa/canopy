# Tool SOP — Loom

## Purpose
Loom replaces most meetings that could have been a message, and most messages that should have been a meeting. When used well, it cuts meeting hours 30-40% and compresses SOP creation time from hours to under 30 minutes per SOP. This doc defines when to Loom vs. meet, how to record well, where Looms live, and how the team reviews async.

## When to Loom (Decision Tree)

```
Need to share information or get feedback?
│
├── One-way information → LOOM
├── Need dialog / brainstorm → MEETING
├── Feedback on artifact → LOOM + Notion comment thread
├── Decision with 2-3 options → LOOM (pitch) + async vote
├── Decision with many options / high stakes → MEETING
├── Demo / walkthrough → LOOM
├── Performance feedback → MEETING (never Loom)
├── Hard news (firing, restructuring) → MEETING (never Loom)
├── Status update → NEITHER — async written update
└── Celebration → LOOM or Slack post (keeps energy)
```

## Recording Standards

Every Loom follows this 3-part structure. Team members who skip it get a gentle redo request.

### 1. Intro (15-30 seconds)
- State your name (new viewers may not know you)
- State the purpose of the Loom (1 sentence: "This is a walkthrough of X, so you can Y by Z")
- State the ask (what do you need from the viewer — watch, approve, comment, forward?)

### 2. Content (length depends on purpose)
- Short (under 3 min): quick updates, approvals, FYIs
- Medium (3-10 min): walkthroughs, demos, feedback-on-artifact
- Long (10-30 min): training, SOPs, deep context transfers
- Over 30 min: split into chapters or make a meeting instead

### 3. CTA (15 seconds)
- State what you want viewers to do
- State the deadline for action
- Thank them for watching

## Quality Baseline

Every Loom hits these:

- **Webcam on** (the human connection matters; exception: long SOP screen-record)
- **Mic near mouth** (AirPods fine; don't use laptop mic for anything >2 min)
- **Clear screen** (close personal tabs, notifications off, Slack DND on)
- **No over-editing** (async beats polish; ship at 90%)
- **Chapters for anything >5 min** (Loom auto-chapters help; add manually if needed)
- **Transcript on** (automatic — use it as pre-read + searchability)

## Templates by Loom Type

### Status / Update Loom (≤3 min)

```
0:00 — "Hey team, [name] here. Quick update on [project]."
0:15 — Numbers / status (screenshare dashboard or doc)
1:30 — What's next this week
2:30 — Any blockers / asks
2:45 — "Questions? DM me or drop a thread on this Loom. Thanks."
```

### Feedback-on-Artifact Loom (3-10 min)

```
0:00 — "I'm giving feedback on [artifact]. You are [creator]. Context: [why this matters]."
0:30 — Open the artifact. Walk through page by page / section by section.
For each item: what's working, what to change, why.
End — "Overall: [ship / ship with changes / rework]. Priority fixes: [top 3]."
CTA — "Reply in a Loom back, or DM me."
```

### SOP Recording Loom (5-20 min)

```
0:00 — "This is the SOP for [task]. Owner: [name]. Last updated: [date]."
0:30 — "When does this SOP run?" — trigger
1:00 — "Inputs you need" — list
1:30 — "The steps" — perform them live while narrating
End — "Outputs produced: [list]. Edge cases: [list]. Questions: [person]."
```

The SOP Loom is then transcribed, the transcript is edited into a written SOP in Notion, and the Loom is embedded as the video demonstration. See `tool-sops-notion.md`.

### Decision Pitch Loom (3-7 min)

```
0:00 — "I'm proposing [decision]. Voters: [list]. Deadline: [date]."
0:30 — Situation: what's going on
1:30 — Options: 2-3 options, each with pros / cons / cost
4:00 — Recommendation and why
5:30 — Ask: vote in thread by [deadline]; I'll tally and announce.
```

## Library Organization

Looms live in two places:

**1. Loom folder structure (inside Loom):**
```
/ [Company Workspace]
├── Decisions
├── SOPs (by department)
├── Team Updates
├── Feedback / Reviews
├── Training / Onboarding
├── Client Recordings (restricted)
└── Archive
```

**2. Embedded in Notion:**
- Any Loom that's part of an SOP, decision, or playbook gets embedded into the Notion page
- Naked Loom links in Slack = ephemeral; if it matters, embed it in Notion
- Rule: if a Loom is referenced 3+ times, it belongs in Notion

## Async Review Cadence

Receiving Looms:

- **Watch SLA:** 24 business hours for team-internal, 48 hours for contractor-inbound
- **Reply SLA:** same as watch, with substantive thread comment or Loom reply
- **Skip speed:** 1.5x or 2x is fine and expected; nobody takes offense
- **Comments:** use timestamped comments (Loom native) so discussion stays contextual

Weekly discipline (Fridays):
- Every team member reviews their Loom inbox
- Zero >7-day unwatched business-relevant Looms

## When Loom Fails (Use a Meeting Instead)

Symptoms that say "stop making Looms, book a meeting":
- 4+ Loom exchanges on one topic with no decision
- Emotion in the Loom (frustration reads worse on video than in person)
- Complex tradeoffs where people need to see each other's reactions
- Anyone says "I'm confused about the Loom"

## Access + Sharing

- Team workspace: all full-time members have edit access
- Contractors: view access to specific folders only
- Clients: individual share links with passwords, never workspace access
- Public share: disabled by default; Operator approves exceptions
- Download: disabled by default (prevents leakage)

## Onboarding: New Hire Watches

A Loom starter pack for every new hire:

| Loom | Length | Purpose |
|---|---|---|
| Welcome from Operator | 5 min | Culture, mission, hello |
| "How we work" | 15 min | Cadences, tools, async norms |
| "Our customer" | 10 min | ICP, pain, why we exist |
| "Our offer" | 10 min | What we sell, pricing, positioning |
| Department overview (theirs) | 15-30 min | Their team's playbook |

New hire's first Loom back: a 2-min "introducing myself" to #team-general, watched at 8:00am morning check on day 1.

## Metrics / Success Criteria
- Looms in the workspace library: growing 5-10/week at a 5-person team
- Meeting hours: reduced 30-40% 6 months after Loom adoption
- Loom watch SLA met 90%+ (sampled)
- SOP creation time: <30 min per SOP (record → transcript → edit)
- Loom → Notion embed rate for SOPs: 100%

## Failure Modes
- **30-min rambly Looms.** Not watched. Fix: training on 3-part structure; 10-min soft cap.
- **Loom as avoidance.** Using Loom to dodge a hard conversation. Fix: explicit rule — performance, firing, grievance = meetings, never Loom.
- **Naked Loom links.** Nobody finds it 2 weeks later. Fix: embed in Notion if it's a durable artifact.
- **Un-watched Looms pile up.** Fix: Friday 30-min inbox review ritual.
- **Loom replaces real writing.** 15-min Loom for what should have been 2 paragraphs. Fix: "could this be a paragraph?" gut-check before recording.

## Cross-references
- Skills: `skills/loom-sop/`, `skills/async-feedback/`
- Frameworks: `frameworks/3-part-loom/`, `frameworks/async-decision/`
- Other operations docs: `team-collaboration.md`, `tool-sops-notion.md`, `tool-sops-slack.md`

---
*v1.0 — 2026-04-19.*
