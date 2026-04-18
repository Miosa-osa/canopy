# Canopy Migrations

## Standard migrations

Apply all standard migrations with:

    mix ecto.migrate

## Staged migrations (ops review required)

Some migrations are split into multiple steps and require manual coordination.
They are committed but must be applied in sequence during a maintenance window.

### session_messages partitioning (Tracks #76) — DEFERRED

> **Status (2026-04-18):** No partitioning code has been committed. The schema
> still uses the flat `session_messages` table. Revisit when the table exceeds
> 10M rows (projected ~6,700 active users at current growth rate).



Partition `session_messages` by `inserted_at` (monthly range) to handle
the 100M-row scaling cliff at ~6,700 users.

**Migration files:**

| File | Status | Notes |
|------|--------|-------|
| `20260418210000_create_session_messages_v2_partitioned.exs` | AUTO — safe to run now | Creates partitioned v2 table. Does not touch live table. |
| `20260418210100_backfill_session_messages_v2.exs` | MANUAL — off-hours only | Copies rows from old to new. Has guard: skips if v2 already populated. |
| `20260418210200_swap_session_messages.exs` | MANUAL — after backfill verified | Renames tables. Has guard: refuses if v2 is empty. |

**Runbook:**

1. Apply Migration A (runs via `mix ecto.migrate` — part of normal deploy).
2. Schedule off-hours window.
3. Verify Migration A: `SELECT COUNT(*) FROM session_messages_v2;` → should be 0.
4. Run Migration B: `mix ecto.migrate` (guard checks for empty destination).
5. Verify backfill: both tables should have same row count.
6. Run Migration C: `mix ecto.migrate` (guard checks v2 is non-empty).
7. Verify production traffic hitting partitioned table.
8. After 1 week of verified stability: `DROP TABLE session_messages_old CASCADE;`

## Upcoming partitioning (before 10k users)

The following tables hit scaling cliffs at 10k users, NOT 100. Track as
follow-ups. Create migrations before row counts exceed 10M rows.

| Table | Projected size at 10k users | Target partition range | Priority |
|-------|----------------------------|----------------------|----------|
| `governance_audit_log` | ~15M rows/month, unbounded | monthly by `occurred_at` | High — add before 10k users |
| `budget_spend_snapshots` | ~432M rows/year, no TTL | monthly by `snapshot_at` | High — add before 10k users |

## Partition maintenance

Monthly partitions are created automatically by `Canopy.Partitions.EnsureWorker`
(Oban cron: `0 3 1 * *` — 3 AM on the 1st of each month, 3 months ahead).

Manual invocation:

    mix canopy.partitions.ensure
    mix canopy.partitions.ensure --months-ahead 6
    mix canopy.partitions.ensure --table session_messages_v2
