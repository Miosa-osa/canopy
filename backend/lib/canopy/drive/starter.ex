defmodule Canopy.Drive.Starter do
  @moduledoc """
  Seeds first-boot **starter content** into the Drive super-module.

  Drive ships empty. New workspaces get a small Personal-scope starter tree —
  a few folders, prompts, workflow placeholders, and rules — so the `/drive`
  route is not a blank page on first login. Team scope stays empty by design;
  workspaces curate their own shared content.

  ## What gets seeded

      Personal/
      ├── Starter prompts/     (5 prompt entries)
      ├── Starter workflows/   (3 workflow placeholders, linked to routines if available)
      ├── Starter rules/       (3 rule entries)
      ├── MCP Servers/         (empty folder, ready for future MCP registry)
      └── Getting started      (1 prompt-kind welcome entry at root)

  Total: 4 folders + 5 prompts + 3 workflows + 3 rules + 1 welcome = 16 entries.

  ## Idempotency

  Slug uniqueness within `(scope, parent_id)` is the dedup key. Re-running
  `seed!/0` looks up each entry by slug under its (resolved) parent and skips
  if already present. User edits to a starter entry's body are **not**
  clobbered — slug-based skip means we never touch existing rows on re-seed.

  ## Workflow linking

  `kind=workflow` entries point at `Canopy.Routines.Routine` rows by `routine_id`.
  When a routine with the matching seed-name is already present (the demo
  routines from `priv/repo/seeds.exs`), we wire its uuid into the body.
  Otherwise the body is `%{"routine_id" => nil}` and the entry doubles as a
  placeholder until an operator wires up the routine. This satisfies per-kind
  body validation (the key must be present) while letting the seed run before
  routines exist.

  ## MCP servers

  No MCP server registry exists yet (Phase B). The `MCP Servers` folder is
  seeded empty as a hook for the future registry — the folder itself is
  always created so users see the slot.

  ## Calling

      Canopy.Drive.Starter.seed!()

  Or via `mix canopy.seed.drive`. Always safe to re-run.
  """

  require Logger

  alias Canopy.Drive
  alias Canopy.Repo
  alias Canopy.Routines.Routine

  import Ecto.Query, only: [from: 2]

  @scope "personal"

  # ---------------------------------------------------------------------------
  # Public entry point
  # ---------------------------------------------------------------------------

  @doc """
  Seeds Personal-scope starter content.

  Returns a `{inserted, skipped, errored}` tuple of counts. Never raises —
  individual create failures are logged and counted as `errored`, the rest of
  the seed continues. Safe to re-run.
  """
  @spec seed!() :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def seed! do
    Logger.info("[Canopy.Drive.Starter] Seeding starter content (scope=#{@scope})...")

    routines_by_name = load_routines_by_name()
    parents = %{}

    {parents, counts} =
      Enum.reduce(entries(), {parents, {0, 0, 0}}, fn entry, {parents_acc, counts_acc} ->
        seed_entry(entry, parents_acc, counts_acc, routines_by_name)
      end)

    {inserted, skipped, errored} = counts
    _ = parents

    Logger.info(
      "[Canopy.Drive.Starter] Done. inserted=#{inserted} skipped=#{skipped} errored=#{errored}"
    )

    counts
  end

  # ---------------------------------------------------------------------------
  # Static entry list
  # ---------------------------------------------------------------------------

  @doc """
  Returns the static, deterministic list of starter entries.

  Each entry is `%{slug, name, kind, scope, parent_slug, body, tags}` where
  `parent_slug` is `nil` for root entries. Order matters — folders precede
  their children so parent-id resolution succeeds at insert time.

  This is data, not behavior. Tests assert this list directly.
  """
  @spec entries() :: [map()]
  def entries do
    [
      # ── Root folders (created first so children can resolve parent_id) ────
      %{
        slug: "starter-prompts",
        name: "Starter prompts",
        kind: "folder",
        scope: @scope,
        parent_slug: nil,
        body: %{},
        tags: ["starter"]
      },
      %{
        slug: "starter-workflows",
        name: "Starter workflows",
        kind: "folder",
        scope: @scope,
        parent_slug: nil,
        body: %{},
        tags: ["starter"]
      },
      %{
        slug: "starter-rules",
        name: "Starter rules",
        kind: "folder",
        scope: @scope,
        parent_slug: nil,
        body: %{},
        tags: ["starter"]
      },
      %{
        slug: "mcp-servers",
        name: "MCP Servers",
        kind: "folder",
        scope: @scope,
        parent_slug: nil,
        body: %{},
        tags: ["starter", "mcp"]
      },

      # ── Root-level welcome prompt ─────────────────────────────────────────
      %{
        slug: "getting-started-with-canopy",
        name: "Getting started with Canopy",
        kind: "prompt",
        scope: @scope,
        parent_slug: nil,
        tags: ["starter", "onboarding"],
        body: %{
          "body" => """
          Welcome to Canopy.

          Drive is your unified shell for typed knowledge: folders, prompts,
          workflows, notebooks, env vars, MCP servers, and rules. Everything
          here is searchable, scoped (Personal vs Team), and pluggable into
          your agent runtimes.

          ## Quick tour

          - **Starter prompts** — reusable prompt templates with `{{variable}}`
            placeholders. Drop them into any session.
          - **Starter workflows** — saved command runs you can re-invoke from
            the palette.
          - **Starter rules** — directives that flow into agent system prompts
            scoped by `applies_to`.
          - **MCP Servers** — placeholder folder for Model Context Protocol
            server entries (Phase B).

          ## Next steps

          1. Edit any starter entry — your changes are kept across re-seeds.
          2. Right-click → New to add your own prompts and rules.
          3. Drag entries between folders to reorganize.
          4. Switch to Team scope to share with your workspace.

          Drive entries are tracked in the `drive_entries` table; the API
          lives at `/api/v1/drive`.
          """,
          "variables" => []
        }
      },

      # ── Starter prompts (5) ──────────────────────────────────────────────
      %{
        slug: "explain-this-code",
        name: "Explain this code",
        kind: "prompt",
        scope: @scope,
        parent_slug: "starter-prompts",
        tags: ["starter", "code"],
        body: %{
          "body" => """
          Read the file at `{{file_path}}` and explain what it does.

          Cover:
          - Top-level purpose in one sentence
          - Key data structures and types
          - Control flow / lifecycle
          - Notable design choices and trade-offs
          - Any non-obvious gotchas a new contributor should know

          Be concise. Use code references in `path:line` form. Skip
          boilerplate explanations the reader already knows.
          """,
          "variables" => [
            %{"name" => "file_path", "description" => "Absolute or repo-relative file path"}
          ]
        }
      },
      %{
        slug: "refactor-for-readability",
        name: "Refactor for readability",
        kind: "prompt",
        scope: @scope,
        parent_slug: "starter-prompts",
        tags: ["starter", "refactor"],
        body: %{
          "body" => """
          Refactor the following code for readability without changing
          observable behavior:

          ```
          {{selection}}
          ```

          Constraints:
          - Preserve the public API and side effects
          - Smaller functions with single responsibility
          - Clearer names — a good name removes the need for a comment
          - Remove duplication only when it does not introduce coupling
          - Keep the existing testing framework and conventions

          Output the refactored code plus a short rationale.
          """,
          "variables" => [
            %{"name" => "selection", "description" => "Code selection to refactor"}
          ]
        }
      },
      %{
        slug: "generate-tests-for-this-function",
        name: "Generate tests for this function",
        kind: "prompt",
        scope: @scope,
        parent_slug: "starter-prompts",
        tags: ["starter", "tests"],
        body: %{
          "body" => """
          Write a test suite for `{{function_name}}`.

          Cover:
          - Happy path with realistic inputs
          - Boundary values and edge cases (empty, max, off-by-one)
          - Null / undefined / missing inputs
          - Error conditions and exception paths
          - Async behavior or race conditions when applicable

          Match the testing framework already used in the codebase. Use
          Arrange / Act / Assert structure. Mock at the boundary, not deep
          in the stack.
          """,
          "variables" => [
            %{"name" => "function_name", "description" => "Fully-qualified function name"}
          ]
        }
      },
      %{
        slug: "find-performance-issues",
        name: "Find performance issues",
        kind: "prompt",
        scope: @scope,
        parent_slug: "starter-prompts",
        tags: ["starter", "performance"],
        body: %{
          "body" => """
          Audit the current code path for performance issues.

          Look for:
          - N+1 query patterns or repeated round trips
          - Unnecessary allocations in hot loops
          - Blocking I/O on a request path that should be async
          - Missing indexes on new query patterns
          - Unbounded loops or recursion without a base case
          - Large objects held in memory longer than needed

          For each finding: severity, location, evidence, suggested fix.
          Skip micro-optimizations that do not move a real metric.
          """,
          "variables" => []
        }
      },
      %{
        slug: "write-commit-message",
        name: "Write commit message",
        kind: "prompt",
        scope: @scope,
        parent_slug: "starter-prompts",
        tags: ["starter", "git"],
        body: %{
          "body" => """
          Write a commit message for the following diff:

          ```diff
          {{diff}}
          ```

          Format: Conventional Commits — `<type>(<scope>): <subject>`.

          Rules:
          - Subject in imperative mood, lowercase, no period, ≤ 72 chars
          - Body explains the WHY, not the WHAT (the diff shows what)
          - One logical change per commit
          - Mention breaking changes with a `BREAKING CHANGE:` footer if any
          """,
          "variables" => [
            %{"name" => "diff", "description" => "Unified diff of staged changes"}
          ]
        }
      },

      # ── Starter workflows (3 — link to routine if exists) ───────────────
      %{
        slug: "squash-the-last-n-commits",
        name: "Squash the last N commits",
        kind: "workflow",
        scope: @scope,
        parent_slug: "starter-workflows",
        tags: ["starter", "git"],
        # `routine_id` resolved at seed time from `routines_by_name`. If the
        # routine does not exist, body stays `%{"routine_id" => nil}` and the
        # workflow is a placeholder.
        body: %{"routine_id" => nil, "routine_name" => "Squash the last N commits"},
        link_routine_name: "Squash the last N commits",
        placeholder_note: """
        This workflow is a placeholder. Wire it up by creating a routine with
        the matching name, then re-run `mix canopy.seed.drive` to link.
        """
      },
      %{
        slug: "undo-last-git-commit",
        name: "Undo last git commit",
        kind: "workflow",
        scope: @scope,
        parent_slug: "starter-workflows",
        tags: ["starter", "git"],
        body: %{"routine_id" => nil, "routine_name" => "Undo last git commit"},
        link_routine_name: "Undo last git commit",
        placeholder_note: """
        This workflow is a placeholder. Wire it up by creating a routine with
        the matching name, then re-run `mix canopy.seed.drive` to link.
        """
      },
      %{
        slug: "run-all-tests",
        name: "Run all tests",
        kind: "workflow",
        scope: @scope,
        parent_slug: "starter-workflows",
        tags: ["starter", "tests"],
        body: %{"routine_id" => nil, "routine_name" => "Run all tests"},
        link_routine_name: "Run all tests",
        placeholder_note: """
        This workflow is a placeholder. Wire it up by creating a routine with
        the matching name, then re-run `mix canopy.seed.drive` to link.
        """
      },

      # ── Starter rules (3) ────────────────────────────────────────────────
      %{
        slug: "match-existing-code-style",
        name: "Match existing code style",
        kind: "rule",
        scope: @scope,
        parent_slug: "starter-rules",
        tags: ["starter", "style"],
        body: %{
          "body" => """
          Match the existing code style of the file or module you are editing.

          - Inspect adjacent files before introducing new conventions.
          - Use the same naming, indentation, and import ordering.
          - Do not introduce new dependencies without justification.
          - When in doubt, follow the most-recent commits in the same path.

          Consistency outranks personal preference.
          """,
          "applies_to" => ["*"]
        }
      },
      %{
        slug: "no-emojis-in-code",
        name: "No emojis in code",
        kind: "rule",
        scope: @scope,
        parent_slug: "starter-rules",
        tags: ["starter", "style"],
        body: %{
          "body" => """
          Do not include emoji characters in source code, identifiers, error
          messages, or log output.

          Allowed exceptions:
          - Markdown documentation where an emoji clarifies intent
          - User-facing UI strings explicitly designed with iconography
          - Test fixtures that test emoji handling

          Default: plain ASCII. Code review will flag emoji additions.
          """,
          "applies_to" => ["*"]
        }
      },
      %{
        slug: "always-use-parameterized-queries",
        name: "Always use parameterized queries",
        kind: "rule",
        scope: @scope,
        parent_slug: "starter-rules",
        tags: ["starter", "security", "backend"],
        body: %{
          "body" => """
          Database access must use parameterized queries. Never concatenate
          or interpolate user input into SQL strings.

          - Ecto: use `from(... where: ^value)` or `Repo.query("SELECT ...", [arg])`
          - Raw SQL drivers: use the driver's prepared-statement API
          - Reject any code that builds query strings via `<>` / `++` / sprintf

          Violations are SQL-injection bugs by definition. Code review must
          block them before merge.
          """,
          "applies_to" => ["backend-*"]
        }
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Per-entry seeding
  # ---------------------------------------------------------------------------

  defp seed_entry(entry, parents_acc, {ins, skip, err}, routines_by_name) do
    parent_id = resolve_parent_id(entry, parents_acc)

    case Drive.get_by_slug(entry.slug, scope: entry.scope, parent_id: parent_id_lookup(parent_id)) do
      %_{} = existing ->
        Logger.debug("[Canopy.Drive.Starter] skip #{entry.slug} (already exists)")

        # Even if it exists, register its id so children can resolve.
        new_parents =
          if entry.kind == "folder",
            do: Map.put(parents_acc, entry.slug, existing.id),
            else: parents_acc

        {new_parents, {ins, skip + 1, err}}

      nil ->
        attrs = build_attrs(entry, parent_id, routines_by_name)

        case Drive.create(attrs) do
          {:ok, created} ->
            Logger.info("[Canopy.Drive.Starter] inserted #{entry.kind}/#{entry.slug}")

            new_parents =
              if entry.kind == "folder",
                do: Map.put(parents_acc, entry.slug, created.id),
                else: parents_acc

            {new_parents, {ins + 1, skip, err}}

          {:error, %Ecto.Changeset{} = cs} ->
            Logger.warning(
              "[Canopy.Drive.Starter] failed #{entry.kind}/#{entry.slug}: #{inspect(cs.errors)}"
            )

            {parents_acc, {ins, skip, err + 1}}
        end
    end
  end

  defp resolve_parent_id(%{parent_slug: nil}, _parents), do: nil

  defp resolve_parent_id(%{parent_slug: slug, scope: scope}, parents) do
    case Map.get(parents, slug) do
      nil ->
        # Parent not in this run's accumulator — look it up in the DB. This
        # handles re-seed where the parent already exists from a prior run.
        case Drive.get_by_slug(slug, scope: scope, parent_id: :root) do
          nil -> nil
          %{id: id} -> id
        end

      id ->
        id
    end
  end

  # `Drive.get_by_slug/2` treats `nil` parent_id as "any" — we want "root".
  # When parent_id is nil pass `:root`; otherwise pass the uuid as-is.
  defp parent_id_lookup(nil), do: :root
  defp parent_id_lookup(id), do: id

  defp build_attrs(entry, parent_id, routines_by_name) do
    body = resolve_body(entry, routines_by_name)

    %{
      slug: entry.slug,
      name: entry.name,
      kind: entry.kind,
      scope: entry.scope,
      parent_id: parent_id,
      body: body,
      tags: Map.get(entry, :tags, [])
    }
  end

  defp resolve_body(%{kind: "workflow"} = entry, routines_by_name) do
    routine_name = Map.get(entry, :link_routine_name)
    routine_id = routines_by_name[routine_name]

    base = entry.body || %{}
    note = Map.get(entry, :placeholder_note)

    base
    |> Map.put("routine_id", routine_id)
    |> maybe_put_placeholder_note(routine_id, note)
  end

  defp resolve_body(entry, _routines), do: entry.body || %{}

  defp maybe_put_placeholder_note(body, nil, note) when is_binary(note),
    do: Map.put(body, "placeholder_note", note)

  defp maybe_put_placeholder_note(body, _routine_id, _note), do: body

  # ---------------------------------------------------------------------------
  # Routine lookup — best-effort
  # ---------------------------------------------------------------------------

  # Returns a map of routine name => uuid for any routine whose name matches
  # one of the workflow entries' `link_routine_name`. If the table does not
  # exist yet (early dev) the query is wrapped to avoid crashing the seeder.
  defp load_routines_by_name do
    wanted =
      entries()
      |> Enum.filter(&(&1.kind == "workflow"))
      |> Enum.map(& &1.link_routine_name)
      |> Enum.reject(&is_nil/1)

    case wanted do
      [] ->
        %{}

      names ->
        try do
          Repo.all(from(r in Routine, where: r.name in ^names, select: {r.name, r.id}))
          |> Map.new()
        rescue
          _e ->
            Logger.warning(
              "[Canopy.Drive.Starter] routine lookup failed; workflows will be placeholders"
            )

            %{}
        end
    end
  end
end
