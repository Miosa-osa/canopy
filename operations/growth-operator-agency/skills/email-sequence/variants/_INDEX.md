# Email Sequence Variants — Index

> 8 per-variant playbooks for /email-sequence. Each file runs 200 to 400 lines. Each file declares scope, triggers, cadence, conversion event, open-rate and click-rate targets, subject-line bank, P.S. bank, segmentation logic, benchmarks, failure modes, and next-sequence routing.

## Variant Catalog

| # | Variant | File | Length | Window | Best For |
|---|---|---|---|---|---|
| 1 | **Welcome** | `welcome-sequence.md` | 5 to 7 emails | 14 days | Onboarding new opt-ins; deliver lead magnet; plant mechanism |
| 2 | **Nurture** | `nurture-sequence.md` | 20 to 30 emails | 45 to 90 days | Long-form belief installation; move problem-aware to product-aware |
| 3 | **Launch** | `launch-sequence.md` | 7 to 14 emails | 7 to 14 days | Dated offer window; whisper-tease-shout plus final 24h compression |
| 4 | **Webinar Promotion** | `webinar-promotion-sequence.md` | 5 to 8 pre + 3 to 5 post | 14 days total | Pre-webinar registration and show-up, post-webinar close |
| 5 | **Re-engagement** | `re-engagement-sequence.md` | 5 to 8 emails | 21 to 30 days | Reactivate dormant subscribers; auto-scrub the unresponsive |
| 6 | **Application** | `application-sequence.md` | 3 to 5 emails | 0 to 7 days | Post-application pre-call nurture; raise show-up rate |
| 7 | **Post-Purchase** | `post-purchase-sequence.md` | 5 to 10 emails | 90 days | New buyer onboarding, first-win engineering, ascension bridge |
| 8 | **Broadcast** | `broadcast-playbook.md` | 1 email per send | Weekly or bi-weekly | 10 one-off formats for the steady-state of the list |

## Variant Selection Decision Tree

```
IF subscriber just opted in on a lead magnet:
    → welcome-sequence

ELIF subscriber completed welcome but did not buy:
    → nurture-sequence

ELIF offer window is open and dated:
    → launch-sequence

ELIF a webinar is on the calendar:
    → webinar-promotion-sequence (pre + post)

ELIF subscriber has not opened in 60 to 90 days:
    → re-engagement-sequence

ELIF subscriber submitted an application and booked a call:
    → application-sequence

ELIF subscriber just purchased:
    → post-purchase-sequence

ELIF none of the above, send into the weekly steady-state:
    → broadcast-playbook (pick one of 10 formats)
```

## Upstream and Downstream Routing

| Variant | Typical Upstream | Typical Downstream |
|---|---|---|
| welcome-sequence | /lead-magnet, /landing-page, /ad-creative | nurture-sequence, application-sequence, or direct to launch-sequence if window open |
| nurture-sequence | welcome-sequence | launch-sequence, webinar-promotion-sequence, application-sequence, re-engagement-sequence |
| launch-sequence | nurture-sequence (list must be 35 percent warm) | post-purchase-sequence (buyers), nurture-sequence (non-buyers) |
| webinar-promotion-sequence | /webinar-script | post-purchase-sequence (buyers), nurture-sequence (non-buyers) |
| re-engagement-sequence | nurture-sequence (cold tag) or welcome-sequence (cold tag) | broadcast (re-engaged), nurture (re-engaged), off-list (scrubbed) |
| application-sequence | /landing-page with application form, /ad-creative pointing at application | post-purchase-sequence (buyers), nurture-sequence (non-buyers) |
| post-purchase-sequence | launch-sequence, application-sequence, webinar-promotion-sequence | ascension post-purchase-sequence (ascenders), retention loop (stay), referral loop (referrers) |
| broadcast-playbook | /content-calendar | Usually none; occasional tag-based routing |

## Universal Rules (apply to every variant)

Every variant must:
- Use 3 or more `phrases_to_use` per email (2 or more for re-engagement)
- Pass the full banned-vocabulary sweep
- Carry CAN-SPAM footer, physical address, unsubscribe link
- Use the creator's first name as sender, never a generic brand alias
- Single CTA per email, no stacking
- Real urgency only; no invented deadlines
- Pause overlapping sequences for the active variant's window

## Benchmarks Snapshot

| Variant | Open Rate | Click Rate | Unsub Rate |
|---|---|---|---|
| welcome | 45 to 60 percent | 8 to 15 percent | 1.5 to 3 percent cumulative |
| nurture | 35 to 50 percent | 5 to 10 percent | 4 to 7 percent cumulative |
| launch | 40 to 55 percent (final 24h spikes to 55 to 70) | 10 to 20 percent | 3 to 6 percent |
| webinar | 45 to 65 percent | 15 to 30 percent registration, 4 to 10 percent close | 2 to 4 percent |
| re-engagement | 12 to 25 percent | 2 to 6 percent | 25 to 50 percent (the point) |
| application | 65 to 85 percent | 20 to 40 percent | under 1 percent |
| post-purchase | 55 to 75 percent | 15 to 30 percent | under 1 percent |
| broadcast | 35 to 55 percent | 4 to 10 percent | under 0.5 percent per send |

---
*v1.0 — email-sequence variants index.*
