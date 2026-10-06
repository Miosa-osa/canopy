# Finance Tracker Schema

## Purpose
The spreadsheet schema (Google Sheets or Excel) every Growth team uses to track the financial state of the business. Owner: the Operator until ~$1M, then handed to a fractional CFO. Updates: weekly cash, monthly full close. This schema is the source of truth for the CFO's MBR deck.

## Workbook Structure (Tabs, in order)

| # | Tab | Cadence | Owner |
|---|---|---|---|
| 1 | Dashboard | Auto | Formula-driven |
| 2 | Revenue | Weekly | Ops Mgr |
| 3 | MRR / ARR | Weekly | Ops Mgr |
| 4 | Cash + Runway | Weekly | CFO / Operator |
| 5 | 13-Week Cash Forecast | Weekly | CFO |
| 6 | CAC / LTV / Payback | Monthly | Marketing Mgr |
| 7 | Cost of Goods / Delivery (60/30/10) | Monthly | CFO |
| 8 | Cost Categories (P&L) | Monthly | CFO |
| 9 | FTE Cost | Monthly | CFO |
| 10 | Vendor Spend | Monthly | Ops Mgr |
| 11 | Budget vs Actual | Monthly | CFO |
| 12 | Inputs (locked) | Annual | CFO |

---

## Tab 1 — Dashboard

Auto-calculated. Pulls from other tabs.

| Metric | Cell Source | Target | Current | Status |
|---|---|---|---|---|
| Cash | 'Cash + Runway'!B3 | >6 mo | formula | color-coded |
| Runway (months) | `=Cash / AVG(last 3 months burn)` | >6 | formula | color-coded |
| MRR | 'MRR / ARR'!B3 | per plan | formula | vs plan |
| ARR | `=MRR*12` | per plan | formula | vs plan |
| Net New MRR | 'MRR / ARR'!D3 | >0 | formula | trend |
| Gross Churn % | 'MRR / ARR'!E3 | <5% | formula | color-coded |
| Blended CAC | 'CAC / LTV'!B3 | <LTV/3 | formula | color-coded |
| LTV | 'CAC / LTV'!C3 | — | formula | — |
| LTV:CAC | `='CAC'!C3/'CAC'!B3` | >3 | formula | color-coded |
| CAC Payback (months) | 'CAC / LTV'!D3 | <12 | formula | color-coded |
| EBITDA Margin % | 'Budget'!X3 | stage-based | formula | vs target |

Color coding: green = on/above target, yellow = within 10%, red = off target.

---

## Tab 2 — Revenue (Weekly)

Columns:

| Week Ending | Net New Rev | Collected Rev | Recurring Rev | One-Time Rev | Refunds | Chargebacks | Net Revenue |
|---|---|---|---|---|---|---|---|

Formulas:
- `Net Revenue = (Collected Rev) - Refunds - Chargebacks`
- Running YTD in a side column: `=SUM($G$2:G2)` where G is Net Revenue

---

## Tab 3 — MRR / ARR (Weekly)

Columns:

| Week Ending | New MRR | Expansion MRR | Contraction MRR | Churn MRR | Net New MRR | Ending MRR | ARR |
|---|---|---|---|---|---|---|---|

Formulas:
- `Net New MRR = New + Expansion - Contraction - Churn`
- `Ending MRR = Prior Week Ending MRR + Net New MRR`
- `ARR = Ending MRR * 12`
- `Gross Churn % = Churn MRR / Prior Ending MRR`
- `Net Revenue Retention = (Ending MRR from prior cohort) / (Starting MRR from prior cohort)` — computed monthly

---

## Tab 4 — Cash + Runway (Weekly)

Columns:

| Week Ending | Operating Account | Savings / Reserve | AR | AP | Net Cash Position | Weekly Net Burn | Runway (months) |
|---|---|---|---|---|---|---|---|

Formulas:
- `Net Cash Position = Operating + Savings + AR - AP`
- `Weekly Net Burn = (Prior week Operating + Weekly Receipts) - Current Operating` (or use P&L-derived burn)
- `Runway (months) = Operating / (AVERAGE last 12 weeks' net burn * 4.33)` — use rolling 12-week burn, not a single month

**Reserve rule:** always keep 3 months of burn in Savings, untouched. Runway math includes only Operating.

---

## Tab 5 — 13-Week Cash Forecast (Weekly)

One row per week, 13 weeks forward.

| Week | Starting Cash | Expected Receipts | Expected Disbursements | Ending Cash | Variance to Plan |
|---|---|---|---|---|---|

Expected receipts break out: recurring, new deals committed, AR collections.
Expected disbursements break out: payroll, rent, SaaS, ads, contractors, taxes, other.

**Rule:** any week with <30 days operating cash at Ending Cash gets red-flagged. Runway conversation triggered with Operator.

---

## Tab 6 — CAC / LTV / Payback (Monthly)

Columns (one row per month):

| Month | Total Acq. Spend | New Customers | Blended CAC | Gross Margin % | LTV (lifetime) | LTV:CAC | CAC Payback (months) |
|---|---|---|---|---|---|---|---|

Formulas:
- `Blended CAC = Total Acquisition Spend / New Customers`
  - Acquisition spend = paid media + sales comp + marketing team cost allocable to acq.
- `LTV = Average Revenue Per Customer × Gross Margin % × Average Customer Lifetime (months)`
- `LTV:CAC = LTV / CAC` (target >3:1)
- `CAC Payback = CAC / (Average Monthly Gross Profit per Customer)` (target <12 months)

Side table: CAC by channel (Meta, Google, YouTube, organic, referral, partner, events) — allocable to named programs where possible.

---

## Tab 7 — 60/30/10 Mix (Cost of Goods / Delivery)

The 60/30/10 rule for high-ticket coaching/consulting/info businesses:
- 60% = Delivery + team + COGS
- 30% = Marketing + sales
- 10% = Profit

Track this monthly. Drift from the mix signals where to look.

| Month | Revenue | COGS + Delivery ($) | COGS % | Marketing + Sales ($) | M+S % | Profit ($) | Profit % |
|---|---|---|---|---|---|---|---|

Formulas:
- `COGS % = (COGS + Delivery) / Revenue`
- Target: COGS ≤60% at $1M, trending to 50% at $5M
- Profit % target: 10% at $1M, 20%+ at $5M+

---

## Tab 8 — Cost Categories (P&L)

Standard service business P&L. Monthly.

| Category | Sub-category | Month 1 | Month 2 | Month 3 | YTD | % of Revenue |
|---|---|---|---|---|---|---|
| Revenue | New | | | | | |
| Revenue | Recurring | | | | | |
| Revenue | Other | | | | | |
| COGS | Delivery staff | | | | | |
| COGS | Coaches / contractors | | | | | |
| COGS | Platform / hosting | | | | | |
| Gross Profit | | =Rev - COGS | | | | |
| OpEx: Sales | Sales payroll + commission | | | | | |
| OpEx: Marketing | Paid ads | | | | | |
| OpEx: Marketing | Content / creative | | | | | |
| OpEx: Marketing | Tools | | | | | |
| OpEx: G&A | Rent | | | | | |
| OpEx: G&A | SaaS | | | | | |
| OpEx: G&A | Legal / accounting | | | | | |
| OpEx: G&A | Other | | | | | |
| EBITDA | | =GP - OpEx | | | | |

---

## Tab 9 — FTE Cost (Monthly)

One row per team member.

| Name | Role | Type (FTE/Contract) | Base/mo | Variable Target/mo | Total Comp | Benefits/Taxes Loaded (+25%) | Fully Loaded Cost |
|---|---|---|---|---|---|---|---|

Formulas:
- `Total Comp = Base + Variable Target`
- `Fully Loaded Cost = Total Comp * 1.25` (US; adjust for region)
- Sum at bottom: Total monthly team cost
- Side calc: `Revenue per FTE = Monthly Revenue / count(FTEs)` (target: $25k+/mo at maturity)

---

## Tab 10 — Vendor Spend (Monthly)

| Vendor | Category | Monthly Cost | Annual Cost | Owner | Renewal Date | In Contract (Y/N) | Last Reviewed |
|---|---|---|---|---|---|---|---|

- Sorted by cost descending
- Flagged: any vendor >$500/mo not reviewed in 90 days
- Rule: every vendor has an owner; orphaned subs get killed at monthly vendor review

---

## Tab 11 — Budget vs Actual (Monthly)

For each P&L line: `Budget | Actual | Variance $ | Variance % | Explanation`
- Variance >10% (either direction) requires written explanation
- Variance <10% = no explanation needed
- Reviewed at MBR every month

---

## Tab 12 — Inputs (Locked, Annual)

Constants the other sheets reference:
- Gross margin assumption per product/offer
- Benefits load %
- Target LTV:CAC
- Target CAC payback months
- Target cash reserve (months)
- Stage-based EBITDA target (per `mode-of-operations.md`)
- Approved vendors / categories

Locked for consistency; updated once a year at annual planning.

---

## Weekly Update Checklist (Operator or Ops Mgr, Fridays by 5pm)

- [ ] Revenue tab: week's numbers entered
- [ ] MRR/ARR tab: new/expansion/contraction/churn logged
- [ ] Cash tab: bank balances pulled from Operating + Savings
- [ ] 13-week forecast refreshed
- [ ] Dashboard reviewed — any red flags flagged in Slack #leadership

## Monthly Close Checklist (CFO, by business day 10)

- [ ] Books closed in QuickBooks/Xero
- [ ] All tabs reconciled to books
- [ ] CAC/LTV computed for the month
- [ ] 60/30/10 mix calculated and commented
- [ ] FTE cost roster matches HR/payroll
- [ ] Vendor spend reconciled
- [ ] Budget vs Actual with variance commentary
- [ ] Dashboard screenshot archived in Notion `/finance/monthly-snapshots/YYYY-MM/`
- [ ] MBR deck pre-populated

## Metrics / Success Criteria
- Books close by business day 10, 11/12 months
- Weekly cash tab updated by Friday 5pm PT, 48/52 weeks
- Variance commentary on 100% of P&L lines >10% off budget
- LTV:CAC target >3, measured monthly
- CAC payback <12 months, trending down
- Runway visible at a glance on Dashboard

## Failure Modes
- **Spreadsheet not reconciled to QuickBooks.** Fix: CFO ties out every tab at monthly close.
- **Runway calc uses last-month burn only.** Produces wild swings. Fix: rolling 12-week burn.
- **CAC excludes sales comp.** Understates truth. Fix: loaded CAC only.
- **FTE cost missing benefits.** Fix: 1.25x loading factor in the Inputs tab.
- **Vendor spend drift.** Forgotten $29/mo subs. Fix: monthly vendor review, every vendor has an owner.

## Cross-references
- Skills: `skills/monthly-close/`, `skills/13-week-cash/`, `skills/mbr-deck/`
- Frameworks: `frameworks/cac-model/`, `frameworks/ltv-model/`, `frameworks/60-30-10/`
- Other operations docs: `cadences-monthly.md`, `cadences-quarterly.md`, `daily-dashboard.md`, `mode-of-operations.md`

---
*v1.0 — 2026-04-19.*
