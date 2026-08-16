# Drive starter content — wiring instructions

The Drive super-module ships empty. `Canopy.Drive.Starter` populates the
Personal scope with a small, useful tree on first boot so `/drive` is not a
blank page. This doc explains how the seeder is wired and how to operate it.

## What the seed installs

All entries are Personal scope. Team scope is intentionally empty —
workspaces curate their own shared content.

```
Personal/
├── Starter prompts/      5 prompts (explain code, refactor, tests, perf, commit msg)
├── Starter workflows/    3 workflow placeholders (squash N, undo last, run all tests)
├── Starter rules/        3 rules (match style, no emojis, parameterized queries)
├── MCP Servers/          empty folder (placeholder for Phase B registry)
└── Getting started       1 root-level welcome prompt
```

Total: 16 entries (4 folders + 6 prompts + 3 workflows + 3 rules).

## 1. seeds.exs — appended call

`backend/priv/repo/seeds.exs` ends with a call to `Canopy.Drive.Starter.seed!()`
after the existing seed sections (runtimes, workspaces, agents, templates,
etc). Standard `mix ecto.setup` and `mix run priv/repo/seeds.exs` runs cover
the Drive starter automatically.

## 2. Standalone Mix task — `mix canopy.seed.drive`

`backend/lib/mix/tasks/canopy.seed.drive.ex` exposes the same call as a
dedicated task. Use it when you want to refresh starter content without
rerunning the full database seeder:

```bash
cd backend && mix canopy.seed.drive
```

The task prints `inserted / skipped / errored` counts and exits 0 unless an
entry hit a hard error (logged to the app log).

## 3. Idempotency strategy

Slug uniqueness within `(scope, parent_id)` is the dedup key. The seeder
flow on each entry:

1. Resolve `parent_id` from the in-run `parents_acc` map (folder slugs to
   uuids), falling back to a DB lookup of the parent slug at the root for
   re-run scenarios.
2. Call `Drive.get_by_slug(slug, scope: scope, parent_id: ...)`.
3. If a row already exists → log `skip`, register its id in `parents_acc`
   so children can resolve, continue.
4. If not → call `Drive.create/1` with the validated attrs.

`Drive.create/1` itself is unchanged — the seeder uses the public API
exclusively. Per-kind body validation (workflow needs `routine_id`, prompt
needs `body` + `variables`, rule needs `body` + `applies_to`) is enforced
by the existing `Canopy.Drive.Entry.changeset/2`.

## 4. Workflow → routine linking

`kind=workflow` entries link to `Canopy.Routines.Routine` rows by
`routine_id`. The seeder runs a single `Repo.all` for routines whose `name`
matches one of the starter workflow names:

| Starter workflow slug          | Linked routine `name`             |
|--------------------------------|------------------------------------|
| `squash-the-last-n-commits`    | `Squash the last N commits`        |
| `undo-last-git-commit`         | `Undo last git commit`             |
| `run-all-tests`                | `Run all tests`                    |

If a routine with the matching name exists, its uuid is wired into
`body["routine_id"]`. Otherwise the entry is created as a placeholder with
`body["routine_id"] = nil` and a `placeholder_note` that explains how to
wire it up. Re-running the seeder after the routine is created will **not**
back-fill the link (slug-based skip preserves user edits) — operators must
either manually edit the entry or delete and re-seed.

This keeps the seeder runnable in any environment, including fresh installs
where no routines exist yet.

## 5. User edits are preserved on re-seed

The slug-based skip means the seeder never touches a row once it exists.
If a user edits the body of "Explain this code" to fit their workflow,
`mix canopy.seed.drive` will skip that entry on the next run.

This is covered by `test/canopy/drive/starter_test.exs` —
`"user edits to a starter entry are preserved on re-seed"`.

## 6. MCP server registry — Phase B

`kind=mcp_server` requires `body["mcp_server_id"]` per the schema's
per-kind validation. Until a real MCP server registry lands, no
`kind=mcp_server` entries are seeded. The `MCP Servers` folder is created
empty so the slot is visible in the tree.

When the registry is added, append `mcp_server`-kind entries to
`Canopy.Drive.Starter.entries/0` with `parent_slug: "mcp-servers"` and
`body: %{"mcp_server_id" => "<registry-id>"}`.

## 7. Future: versioning starter content

Right now the seeder is one-shot per slug — once an entry exists the
seeder leaves it alone, even if the upstream definition changes. This is
correct for protecting user edits but blocks legitimate upgrades (e.g.,
fixing a typo in a starter prompt body).

The proposed solution (deferred — not implemented yet) is a `version`
field on each starter entry (in `entries/0`) and a `starter_version`
field on `drive_entries.body`. On re-seed:

- If `entry.version > db_row.body["starter_version"]`:
  - And the body is otherwise unchanged from the previous starter
    (compare against a `starter_signature` hash also written into body):
    update the row with the new content and bump `starter_version`.
  - Else (user has edited): leave the row alone, log a warning.

The implementation is mechanical but introduces enough surface area
(content hashing, migration of existing rows) that we're shipping
slug-based skip first. Track in `tasks/todo.md` when the first content
update goes upstream.

## 8. Verification

After wiring:

```bash
cd backend && mix test test/canopy/drive/starter_test.exs
cd backend && mix canopy.seed.drive   # idempotent, run twice to confirm skip
```

Tests cover: deterministic `entries/0`, full first-run insert, no-op
re-run, hierarchy correctness, per-kind body validation, and partial-run
recovery (folder pre-exists, children fill in).

## 9. Removing or renaming starter content

If you remove an entry from `entries/0`, existing rows in the DB are
**not** deleted. Operators must either:

1. Delete the row manually via `/api/v1/drive/:id` (DELETE) or the UI, or
2. Add a one-shot data migration that targets the slug.

Renaming (changing the `name` while keeping the `slug`) is fine — but the
new name will not propagate to existing rows for the same reason
versioning doesn't (slug-based skip). See section 7.
