# Automation — Booking to Show

## Purpose
Maximize show-rate on booked calls. Target: ≥ 65% show-rate. Automation runs from the moment a call is booked through the 15 minutes before call start. Every touch is tuned for (a) reducing reschedule friction, (b) raising commitment, (c) pre-framing value.

## Trigger
- Calendar booking event (Calendly, SavvyCal, native, Google Calendar)
- Webhook fires within 30s of booking

## End-State
- Call appears on both calendars
- Confirmation + reminder sequence scheduled
- Pre-call value asset delivered
- Lead tagged `booked:{date}` in CRM
- Slack / dashboard alert to sales owner

## Flow Diagram
```
[Booking webhook]
      │
      ▼
[Create calendar event + Zoom link]
      │
      ▼
[Send immediate confirmation email (T+0 min)]
      │
      ▼
[Tag CRM + alert sales owner]
      │
      ▼
[Schedule reminder sequence]
      │
      ├── T+24h after booking: value-asset email
      ├── T-48h before call: reminder email (confirm / reschedule)
      ├── T-24h before call: pre-frame email + calendar prompt
      ├── T-4h before call: SMS reminder
      ├── T-1h before call: SMS reminder + Zoom link
      └── T-15m before call: SMS final + "see you in 15"
      ▼
[Wait for call outcome webhook]
      │
      ├── Showed → /post-booking-nurture completes
      └── No-show → trigger no-show recovery sequence
```

## Step-by-Step

**Step 1. Confirmation (T+0)**
- Email subject: `{Your call with {us}} is confirmed — {date} at {time} {timezone}`
- Body includes: date/time, Zoom link, agenda bullet points, 1-click add-to-calendar, reschedule link, what-to-bring
- Fires within 60s of booking

**Step 2. CRM + Alert (T+0)**
- CRM record updated: `booked:{YYYY-MM-DD}`, `call-owner:{owner}`, `stage:call-booked`
- Slack alert: `#sales-calls` with lead name, enrichment summary, call time, booking form answers
- Calendar invite sent to sales owner

**Step 3. Value Asset (T+24h after booking)**
- Email delivers one high-value pre-call asset: short video (< 5 min), case study, or framework doc
- Asset answers the most common pre-call objection for this ICP
- Subject leverages curiosity not hype

**Step 4. T-48h Reminder**
- Email subject: `Quick check — still good for {day}?`
- One-click confirm + one-click reschedule
- If no click → flag in CRM for soft follow-up

**Step 5. T-24h Pre-Frame**
- Email that (a) reminds, (b) pre-frames the conversation value, (c) asks for one piece of context ("what's the biggest blocker right now?")
- Opens the relationship before the call

**Step 6. T-4h SMS**
- SMS: `{name} — we are on for {time} today. Zoom link: {link}. Reply R to reschedule.`
- Only if SMS opted in

**Step 7. T-1h SMS**
- SMS: `In an hour. Here's the Zoom: {link}. Looking forward.`

**Step 8. T-15m SMS**
- SMS: `See you at {time}. {link}.`

**Step 9. Post-Call Webhook**
- Sales owner tags outcome: showed / no-show / reschedule / cancelled
- Show → `/post-booking-nurture` hands off
- No-show → no-show recovery sequence fires (3 emails over 5 days, 1 SMS)

## Fillable Config
```yaml
calendar: {calendly | savvycal | native}
video: {zoom | meet | whereby}
sms_provider: {twilio | other}
sms_opt_in_required: true
confirmation:
  send_within_seconds: 60
  value_asset_url: {url}
reminders:
  value_asset_at_hours_post_booking: 24
  reminder_48h: true
  preframe_24h: true
  sms_4h: true
  sms_1h: true
  sms_15m: true
no_show_recovery:
  sequence: no-show-5day
slack_channel: '#sales-calls'
```

## Sample Filled
```yaml
calendar: calendly
video: zoom
sms_provider: twilio
sms_opt_in_required: true
confirmation:
  send_within_seconds: 60
  value_asset_url: https://example.com/pre-call-framework-video
reminders:
  value_asset_at_hours_post_booking: 24
  reminder_48h: true
  preframe_24h: true
  sms_4h: true
  sms_1h: true
  sms_15m: true
no_show_recovery:
  sequence: no-show-5day
slack_channel: '#sales-calls'
```

## Failure Modes + Handling
| Failure | Detection | Response |
|---|---|---|
| Calendar webhook misses | Daily reconciliation against calendar API | Manual catch-up + alert to re-test integration |
| Confirmation email delayed > 5 min | ESP send log | Alert ops; check deliverability |
| SMS not sent (opt-in missing) | CRM check | Skip SMS, increase email frequency |
| Zoom link broken | URL monitoring | Auto-generate new link; email update |
| Reschedule creates dupe | Calendar sync bug | Dedupe logic on booking ID |

## Compliance Checklist
- [ ] SMS opt-in captured explicitly (not bundled)
- [ ] SMS includes STOP instructions
- [ ] Frequency disclosure on opt-in ("up to 5 messages per booking")
- [ ] No-show recovery respects unsubscribe

## KPIs
- Show-rate (target: ≥ 65%)
- Reschedule rate (target: ≤ 15%)
- No-show rate (target: ≤ 20%)
- T-24h email open rate (target: ≥ 60%)
- T-4h SMS delivery rate (target: ≥ 98%)
- Value-asset click rate (target: ≥ 35%)

## Cross-references
- Skill: `skills/post-booking-nurture/`
- Upstream: `workflows/automations/lead-to-crm.md`
- Pipeline: `workflows/divisions/nurture-pipeline.md`
- Knowledge: `reference/knowledge/nurture.md`, `reference/knowledge/sales.md`

---
*v1.0 — 2026-04-19.*
