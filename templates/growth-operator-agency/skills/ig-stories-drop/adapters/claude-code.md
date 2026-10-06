---
description: Generate a 17-day Instagram Stories drop cycle (Whisper → Tease → Shout). Day-by-day 4-frame calendar, DM keyword system, freebie spec, funnel wireframe, application copy, scarcity close, email+SMS pairing, KPI plan.
argument-hint: [optional: launch date in YYYY-MM-DD, e.g. "/ig-stories-drop 2026-05-15"]
allowed-tools: Read, Write, Edit, Grep, Glob, WebFetch, Bash
---

# /ig-stories-drop — slash-command runtime Runtime Binding

Load and execute `skills/ig-stories-drop/SKILL.md` in the current workspace.

## Runtime behavior

1. **Read context:**
   - `SYSTEM.md`, `INVARIANTS.md`, `ENCODING.md`, `company.yaml`
   - `skills/ig-stories-drop/SKILL.md` (full body)
   - `spec/BANNED-VOCABULARY.md` (filter all story copy)
   - `_private/{client}/context-extract.md` if present (deep history)
   - `_private/{client}/drops/` for prior-cycle assets (avoid duplication)
   - `reference/frameworks/signal-theory/`, `reference/frameworks/primitives/`
   - `~/Downloads/IG Stories Launch System Value Extract.*` (the canonical playbook reference)

2. **Pre-flight check:**
   - Verify creator_identity_matrix ≥ 60, audience_intelligence_system ≥ 70, offer_architecture ≥ 60, copy_messaging ≥ 40
   - Verify `phrases_to_use` ≥ 15 entries (else flag `[VOICE-MATCH: pending /extract-voice]`)
   - Verify IG follower count ≥ 20K (else flag and recommend `/story-sequence` instead)
   - If `$ARGUMENTS` is a date, use it as Launch Day (Day 14). Backward-plan Days 1-17.

3. **Execute Phase 0 → Phase 7** per SKILL.md:
   - Phase 0: read context
   - Phase 1: cycle configuration (dates, keywords, freebie check)
   - Phase 2: voice calibration (phrases_to_use / phrases_to_avoid pull)
   - Phase 3: 17-day calendar — all frames
   - Phase 4: support assets (DM, freebie LP, funnel page, Typeform, email, SMS)
   - Phase 5: scarcity anatomy
   - Phase 6: measurement plan
   - Phase 7: handoff runbook

4. **Write output:**
   - `output/ig-stories-drop/{YYYY-MM-DD}-{client-slug}-cycle-{N}/`
     - `00-playbook.md` (the 10-section output from SKILL.md)
     - `01-calendar/` (one file per day, Day-01 through Day-17)
     - `02-dm-scripts.md`
     - `03-freebie-landing.md`
     - `04-funnel-page.md`
     - `05-application-copy.md`
     - `06-scarcity-sequence.md`
     - `07-email-sequence.md`
     - `08-sms-cadence.md`
     - `09-kpi-dashboard.md`
     - `10-measurement-plan.md`
   - Also write to `_private/{client}/drops/{YYYY-MM-cycle-N}/` for encoded source-of-truth

5. **Update company.yaml:**
   - Set `funnel_systems.active_funnels[*]` for this drop cycle as an active funnel entry
   - Add cycle milestones under `goals.initiatives[*].projects[*]`
   - Flag `foundations_status` updates if any compartments advance during composition

6. **Post-ship:**
   - Write `skills/ig-stories-drop/evidence/runs/{YYYY-MM-DD}-{client-slug}.md` with cycle params + forecast
   - Schedule Day 19 `/launch-report` trigger in `PROJECT-STATE.md` log
   - Output next-skill recommendation (usually `/show-rate-surgery` for post-application flow and `/ad-creative` for paid retargeting overlay)

## Arguments

If `$ARGUMENTS` is a date in `YYYY-MM-DD` format, treat it as **Launch Day** (Day 14 of the cycle). Backward-plan Days 1-17.
If `$ARGUMENTS` is empty, use launch date = today + 21 days (standard lead time).

`$ARGUMENTS`

## Tool usage patterns

- **Read** — SKILL.md, company.yaml, creator context extract, prior-cycle folders, IG Stories Launch System reference
- **Write** — 10+ output files for the cycle pack, evidence log
- **Edit** — company.yaml funnel updates, goals milestones, foundations_status
- **Grep** — pull `phrases_to_use`, `phrases_to_avoid`, `proven_hooks` from company.yaml
- **WebFetch** — if creator has a live website/funnel, fetch to verify structure
- **Bash** — create the nested output directory tree

## Quality gates

Before writing the cycle pack:
- All 17 days have 4 frames each
- ≥ 5 `phrases_to_use` appear across calendar copy
- Zero `phrases_to_avoid` present
- Banned-vocabulary filter passed
- Scarcity mechanism is genuine (spots-limit or deadline-limit is documented, not fabricated)
- Freebie outline maps to the first pillar of the paid offer
- Signal Score ≥ 0.8
- Creator review scheduled (drops are load-bearing, require human sign-off before going live)

## Failure handling

Follow `workflows/handoffs/quality-revision.md`:
- **Attempt 1**: auto-revise for voice match or gap filling
- **Attempt 2**: surface gap to creator (usually voice inadequacy — request 2 more content samples)
- **If both fail**: escalate to marketing-head + creator, log to `skills/ig-stories-drop/evidence/failure-modes.md`

## Cross-skill routing

- **Upstream prereq:** `/build-icp` + `/design-offer` + `/extract-voice` + (ideally) `/show-rate-surgery` deployed
- **Parallel:** `/ad-creative` — generate paid-retargeting creative for Shout phase
- **Parallel:** `/post-booking-nurture` — enrich the post-application email/SMS
- **Downstream:** `/launch-report` on Day 19 for debrief
- **Next cycle feeder:** lapsed applicants from this cycle become warm list for Cycle N+1

---
*the slash-command adapter v1.0 — binds to skills/ig-stories-drop/SKILL.md*
