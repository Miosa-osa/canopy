# Daily Dashboard

## Purpose
The one screen the Operator and leads look at every morning. Three layers — leading indicators (today's inputs), lagging indicators (yesterday's outputs), and operational health (is the machine running). If the dashboard isn't ready by 7:50am PT, morning check runs blind — the dashboard owner is a named role.

## Dashboard Structure — Three Layers

### Layer 1 — Leading Indicators (today / this week's inputs)

These predict revenue. Watch them daily; they move before revenue moves.

| Metric | Target (illustrative) | Owner | Update Frequency | Source |
|---|---|---|---|---|
| Leads (new, 24h) | 40/day | Marketing Mgr | Hourly | GHL / ad platforms |
| MQLs (qualified, 24h) | 15/day | Marketing Mgr | Hourly | GHL tagging |
| DMs sent (24h) | 300/day | Sales lead | Setter huddle | Setter log |
| DM → reply rate | >25% | Sales lead | Daily | Setter log |
| Calls booked (next 7 days) | 30 on calendar | Sales lead | Real-time | GHL / calendar |
| Show rate (7-day rolling) | >65% | Sales lead | Daily | GHL |
| Call → close rate (7-day) | >25% | Sales lead | Daily | GHL |
| Pipeline added ($, 7-day) | 3x monthly target | Sales lead | Daily | GHL |
| CAC (7-day rolling) | within target | Marketing Mgr | Daily | Ad platforms + GHL |

### Layer 2 — Lagging Indicators (yesterday's outcomes)

These are what actually happened. They confirm or deny the leading reads.

| Metric | Target | Owner | Update Frequency | Source |
|---|---|---|---|---|
| Revenue closed (24h) | per month/30 | Sales lead | Daily 8am | GHL / Stripe |
| Revenue collected (24h) | >95% of closed | Sales lead | Daily 8am | Stripe / AR |
| Cash (end of day) | per 13-wk model | Operator / CFO | Daily | Bank |
| AR aging (>30 days) | <5% of AR | CFO / Ops Mgr | Weekly | Books |
| New customers (24h) | per plan | Sales lead | Daily | GHL |
| Refunds / chargebacks (24h) | <1% of revenue | CS Mgr | Daily | Stripe |
| NPS (7-day rolling sample) | >50 | CS Mgr | Weekly | Survey tool |

### Layer 3 — Operational Health

Is the machine actually running. These aren't revenue metrics — they're symptoms of drift.

| Metric | Target | Owner | Update Frequency | Source |
|---|---|---|---|---|
| CS tickets open | <20 | CS Mgr | Real-time | Help desk (Intercom/Zendesk) |
| CS ticket aging >48h | 0 | CS Mgr | Real-time | Help desk |
| Content published (24h) | per plan | Content Mgr | Daily 8am | Notion / platforms |
| Content on-time publish rate (7-day) | >90% | Content Mgr | Daily | Notion calendar |
| Ads running (all accounts) | per plan | Ad Buyer | Real-time | Meta / Google / etc. |
| Automations failing | 0 | Ops Mgr / Dev | Real-time | Zapier / Make / GHL |
| Open roles in pipeline | per hiring plan | Ops Mgr | Weekly | Hiring tracker |

---

## Dashboard Tool Options

| Tool | Strengths | Costs | When to Use |
|---|---|---|---|
| Google Sheets + Glide/Supermetrics | Cheap, flexible, fast to build | $0-$100/mo | $0-$1M stage |
| Databox | Pre-built connectors, mobile app, alerts | $50-$300/mo | $1M-$3M stage |
| Geckoboard | Big-screen friendly, TV-in-office setup | $40-$200/mo | Stand-up TV dashboards |
| Metabase (self-hosted or cloud) | SQL-powered, dense, free self-hosted | $0-$200/mo | $3M+ with a Developer |
| Klipfolio | Deep connector library, formula engine | $100-$400/mo | Custom KPIs from many sources |
| GHL native dashboards | Free if using GHL, limited | included | First draft at $0-$500k |
| Notion dashboards (manual) | Integrates with docs, basic | $0-$20/user | Internal + low-volume |

**Recommended path:**
- Build v1 in Google Sheets + conditional formatting + daily refresh (Supermetrics for ads).
- Graduate to Databox at $1M when multi-source data needs automation.
- Graduate to Metabase at $3M once a Developer or data-savvy Ops Mgr exists.

## Dashboard Refresh Owner

Name the role. Don't skip this.

| Layer | Refresh By | Owner |
|---|---|---|
| Leading | 7:50am PT | Ops Mgr (or VA in early stage) |
| Lagging | 7:50am PT | Ops Mgr or CFO for cash |
| Operational health | Live; reviewed 7:50am PT | Ops Mgr |

Owner posts "Dashboard ready" in #team-daily by 7:55am every working day. Missed = escalated at morning check.

## Alerting Rules

Set in your dashboard tool (Databox, Geckoboard) or via Zapier if on Sheets.

| Signal | Threshold | Alert |
|---|---|---|
| Cash below 3-mo runway equivalent | red | Slack #leadership + Operator DM |
| Daily closed revenue $0 on a sales day | after 3pm PT | Slack #sales-leadership |
| CAC 7-day rolling >20% over target | red | Slack #marketing |
| Show rate 7-day <55% | red | Slack #sales |
| CS tickets open >30 | yellow | Slack #cs-internal |
| Automation failed >1h | red | Slack #alerts-ops + Ops Mgr DM |
| Ad account spend paused | red | Slack #marketing + Ad Buyer DM |
| AR aging item >60 days | red | Slack #finance |

## Dashboard Review Ritual

- **8:00am daily** — full team sees dashboard at morning check (15 min max, see `cadences-daily.md`)
- **Friday 3pm all-hands** — week's dashboard trend (not just today's state)
- **Monthly MBR day 5** — full month review with commentary (see `cadences-monthly.md`)

## Dashboard Design Rules

1. **One screen.** If it doesn't fit on a laptop display, it's not a daily dashboard.
2. **Numbers + targets + status color.** No raw numbers without context.
3. **No custom time windows per metric.** Standardize: 24h, 7-day rolling, MTD.
4. **Owner name next to each metric.** No orphan metrics.
5. **Link to deep-dive view.** Click a metric, go to the source.
6. **Refresh timestamp visible.** "Updated 7:48am" — if stale, obvious.

## Starter Dashboard Layout (ASCII)

```
+------------------------- DAILY DASHBOARD — Updated 7:48am PT ------------------------+
|                                                                                      |
|  LEADING                      | LAGGING                  | OPERATIONAL               |
|  Leads 24h:   38 / 40         | Revenue 24h:  $12,400    | CS open:      14 / <20    |
|  MQLs 24h:    13 / 15         | Collected:    $11,800    | CS aging>48h:  0 / 0      |
|  DMs 24h:     312 / 300       | Cash:         $284k      | Content OTD:  3 / 3       |
|  Reply rate:  27% / >25%      | Runway:       6.2 mo     | Ads running:  12 / 12     |
|  Calls 7d:    32 / 30         | Refunds:      $0         | Autom. fails: 0 / 0       |
|  Show rate:   68% / >65%      | New custs:    2 / 2      | Open roles:   3 / 3       |
|  Close rate:  27% / >25%      | NPS 7d:       58 / >50   |                           |
|  Pipeline:    $95k / $90k     | AR >30:       3.1% / <5% |                           |
|  CAC 7d:      $780 / <$900    |                          |                           |
|                                                                                      |
+--------------------------------------------------------------------------------------+
```

## Metrics / Success Criteria
- Dashboard ready by 7:50am 95%+ of working days
- No stale metric >24h on a daily-refresh tab
- Alerts fire within 15 min of threshold breach
- Owner named for every metric (100%)
- Operator checks dashboard every working day (tracked informally)

## Failure Modes
- **Dashboard is metric soup.** 30+ metrics, nobody reads it. Fix: 20 max, grouped in 3 layers.
- **Stale data.** Metric hasn't updated since last week. Fix: timestamp every metric; stale = auto-red.
- **No owner.** Number bad, nobody acts. Fix: owner column, mandatory.
- **Dashboard doesn't match the books.** Revenue on dash ≠ CFO's close. Fix: source-of-truth rules; dash is derived.
- **Operator ignores alerts.** Dashboards become wallpaper. Fix: alert volume triage quarterly; fewer, louder alerts.

## Cross-references
- Skills: `skills/dashboard-builder/`, `skills/alerting-rules/`
- Frameworks: `frameworks/leading-lagging-ops/`
- Other operations docs: `cadences-daily.md`, `finance-tracker-schema.md`, `tool-sops-ghl.md`, `project-management-productivity-software.md`

---
*v1.0 — 2026-04-19.*
