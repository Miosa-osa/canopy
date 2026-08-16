defmodule Canopy.Build do
  @moduledoc """
  Public API for the **Build super-super-module**.

  Build is Canopy's agentic development cockpit at `/build`. It composes the
  Mosaic layout shell, the Block Stream, the Code Editor / File Viewer / Diff
  / Terminal / MCP panes, the Composer footer, and the **Conductor** runtime
  agent into a single operational environment.

  This module owns persistence and ranking for *saved layouts only*. The
  panes themselves live in the existing super-modules (Sessions, Workspaces,
  Files, Sandboxes, Analytics) — Build never reimplements them. Consequently
  this context is intentionally narrow: layout CRUD, use-telemetry, intent →
  suggestion ranking, and the per-workspace default-layout pointer.

  ## Architecture

  ```
  user / Conductor ─create/load─▶ Canopy.Build.Layout (saved Mosaic JSON)
  user opens layout ─record─▶ Canopy.Build.LayoutUse (telemetry)
  user states intent ─rank─▶ Canopy.Build.suggest_layout/1
  ```

  Conductor's `build.*` tool surface (see `Canopy.Tools.Build`) calls this
  module exclusively — no direct Repo access from tools. Pane creation
  itself happens client-side via the queries layer; Conductor's tools emit
  structured instructions the frontend's PaneContent dispatcher honors.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Build.Layout
  alias Canopy.Build.LayoutUse
  alias Canopy.Repo

  require Logger

  @default_limit 100
  @suggest_limit 3

  # ---------------------------------------------------------------------------
  # Layouts (CRUD)
  # ---------------------------------------------------------------------------

  @doc """
  Lists layouts with optional filters.

  Options:
  - `:scope` — `"personal" | "team" | "workspace"`
  - `:owner_id` — UUID of the owning user
  - `:workspace_slug` — for workspace-scoped layouts
  - `:include_archived` — boolean (default `false`)
  - `:limit` — default 100
  """
  @spec list_layouts(keyword()) :: [Layout.t()]
  def list_layouts(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    include_archived = Keyword.get(opts, :include_archived, false)

    base =
      from(l in Layout,
        order_by: [desc: l.last_used_at, asc: l.name],
        limit: ^limit
      )

    base
    |> filter(:scope, opts[:scope])
    |> filter(:owner_id, opts[:owner_id])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> maybe_exclude_archived(include_archived)
    |> Repo.all()
  end

  @doc "Fetches a single layout by id. Returns nil if missing."
  @spec get_layout(Ecto.UUID.t()) :: Layout.t() | nil
  def get_layout(id), do: Repo.get(Layout, id)

  @doc "Fetches a single layout by id, raising if missing."
  @spec get_layout!(Ecto.UUID.t()) :: Layout.t()
  def get_layout!(id), do: Repo.get!(Layout, id)

  @doc """
  Fetches a single layout by slug + scope (+ optional owner_id).

  Slug is unique per (slug, scope, owner_id) so all three are required for
  a deterministic lookup. Pass `nil` for `owner_id` for `"workspace"` and
  `"team"` scopes.
  """
  @spec get_layout_by_slug(String.t(), keyword()) :: Layout.t() | nil
  def get_layout_by_slug(slug, opts \\ []) do
    scope = Keyword.get(opts, :scope, "personal")
    owner_id = Keyword.get(opts, :owner_id)

    query =
      from(l in Layout, where: l.slug == ^slug and l.scope == ^scope)

    query =
      if is_nil(owner_id) do
        from(l in query, where: is_nil(l.owner_id))
      else
        from(l in query, where: l.owner_id == ^owner_id)
      end

    Repo.one(query)
  end

  @doc "Creates a layout."
  @spec create_layout(map()) :: {:ok, Layout.t()} | {:error, Ecto.Changeset.t()}
  def create_layout(attrs) do
    %Layout{} |> Layout.changeset(attrs) |> Repo.insert()
  end

  @doc "Updates a layout with the given patch map."
  @spec update_layout(Layout.t(), map()) :: {:ok, Layout.t()} | {:error, Ecto.Changeset.t()}
  def update_layout(%Layout{} = layout, attrs) do
    layout |> Layout.changeset(attrs) |> Repo.update()
  end

  @doc """
  Soft-deletes a layout by setting `archived_at`. The row stays in place so
  historical `LayoutUse` rows don't dangle.
  """
  @spec archive_layout(Layout.t()) :: {:ok, Layout.t()} | {:error, Ecto.Changeset.t()}
  def archive_layout(%Layout{} = layout) do
    update_layout(layout, %{archived_at: DateTime.utc_now()})
  end

  # ---------------------------------------------------------------------------
  # Use telemetry
  # ---------------------------------------------------------------------------

  @doc """
  Records that a layout was opened. Bumps `use_count` and `last_used_at`
  on the parent layout, then inserts a `LayoutUse` row for ranking input.
  """
  @spec record_use(Layout.t(), keyword()) :: {:ok, LayoutUse.t()} | {:error, term()}
  def record_use(%Layout{} = layout, opts \\ []) do
    now = DateTime.utc_now()

    # Atomic increment — avoids read-modify-write race when the same caller
    # holds a stale `layout` struct across multiple record_use/2 calls.
    from(l in Layout, where: l.id == ^layout.id)
    |> Repo.update_all(
      inc: [use_count: 1],
      set: [last_used_at: now, updated_at: now]
    )

    %LayoutUse{}
    |> LayoutUse.changeset(%{
      layout_id: layout.id,
      user_id: opts[:user_id],
      workspace_slug: opts[:workspace_slug],
      intent: opts[:intent],
      opened_at: now
    })
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # Suggestions
  # ---------------------------------------------------------------------------

  @doc """
  Suggests up to 3 layouts for a stated intent.

  Ranking signal = `use_count_score + name_match_score + description_match_score`
  where each match score is `2.0` for an exact substring hit (case-insensitive)
  on the corresponding field, `0.0` otherwise; `use_count_score` is
  `log2(use_count + 1)` to keep heavy-use layouts surfaced without
  swamping the match signal.

  Archived layouts are always excluded.
  """
  @spec suggest_layout(String.t(), keyword()) :: [%{layout: Layout.t(), score: float()}]
  def suggest_layout(intent, opts \\ []) when is_binary(intent) do
    limit = Keyword.get(opts, :limit, @suggest_limit)

    candidates =
      list_layouts(
        Keyword.merge(
          [include_archived: false, limit: 200],
          Keyword.take(opts, [:scope, :owner_id, :workspace_slug])
        )
      )

    needle = String.downcase(String.trim(intent))

    candidates
    |> Enum.map(fn layout -> %{layout: layout, score: score(layout, needle)} end)
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(limit)
  end

  defp score(%Layout{} = layout, needle) when needle == "" do
    %{layout | name: layout.name || ""}
    |> use_score()
  end

  defp score(%Layout{} = layout, needle) do
    name_score =
      if layout.name && String.contains?(String.downcase(layout.name), needle), do: 2.0, else: 0.0

    desc_score =
      if layout.description &&
           String.contains?(String.downcase(layout.description), needle),
         do: 1.0,
         else: 0.0

    name_score + desc_score + use_score(layout)
  end

  defp use_score(%Layout{use_count: nil}), do: 0.0
  defp use_score(%Layout{use_count: 0}), do: 0.0

  defp use_score(%Layout{use_count: n}) when is_integer(n) and n > 0 do
    :math.log2(n + 1)
  end

  # ---------------------------------------------------------------------------
  # Default layout per workspace
  # ---------------------------------------------------------------------------

  @doc """
  Returns the default layout for a workspace, or `nil` if none is set.

  Resolution order:
    1. The most-recently-used `"workspace"`-scoped layout pinned to that
       workspace_slug whose name is `"default"` (canonical handle).
    2. The most-recently-used non-archived `"workspace"`-scoped layout for
       that workspace_slug.
    3. `nil` — caller falls back to the empty starter layout.
  """
  @spec default_layout(String.t()) :: Layout.t() | nil
  def default_layout(workspace_slug) when is_binary(workspace_slug) do
    canonical =
      Repo.get_by(Layout,
        workspace_slug: workspace_slug,
        scope: "workspace",
        slug: "default"
      )

    case canonical do
      %Layout{archived_at: nil} = layout ->
        layout

      _ ->
        list_layouts(
          scope: "workspace",
          workspace_slug: workspace_slug,
          include_archived: false,
          limit: 1
        )
        |> List.first()
    end
  end

  @doc """
  Sets a layout as the canonical workspace default by renaming its slug to
  `"default"` (within the workspace scope). Returns `{:ok, layout}` on
  success.
  """
  @spec set_default(Layout.t(), String.t()) ::
          {:ok, Layout.t()} | {:error, Ecto.Changeset.t()}
  def set_default(%Layout{} = layout, workspace_slug) when is_binary(workspace_slug) do
    update_layout(layout, %{
      slug: "default",
      scope: "workspace",
      workspace_slug: workspace_slug
    })
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp filter(query, _field, nil), do: query
  defp filter(query, _field, ""), do: query

  defp filter(query, field, value) do
    from(q in query, where: field(q, ^field) == ^value)
  end

  defp maybe_exclude_archived(query, true), do: query

  defp maybe_exclude_archived(query, false) do
    from(q in query, where: is_nil(q.archived_at))
  end
end
