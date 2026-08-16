defmodule Canopy.Projects do
  @moduledoc """
  Context for the Projects domain.

  Projects are named containers that group Issues, Tasks, and Goals.
  They belong to a workspace and are identified by a human-readable slug.

  ## API

  - `list/1`      — filter by workspace_slug, status
  - `get/1`       — by slug
  - `get_summary/1` — by slug, with counts (issues, tasks, goals, sessions)
  - `create/1`    — inserts, auto-slugifies from name when slug omitted
  - `update/2`    — by slug
  - `archive/1`   — sets status :archived + archived_at
  - `unarchive/1` — restores to :active
  - `delete/1`    — dissociates work items before deletion (no cascade)
  """

  import Ecto.Query, only: [from: 2, where: 3]

  alias Canopy.Projects.Project
  alias Canopy.Repo

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec list(map()) :: [Project.t()]
  def list(filters \\ %{}) do
    limit = filters |> Map.get(:limit, 100) |> min(500)

    from(p in Project, order_by: [desc: p.updated_at], limit: ^limit)
    |> maybe_filter_workspace(filters)
    |> maybe_filter_status(filters)
    |> Repo.all()
  end

  @spec get(String.t()) :: {:ok, Project.t()} | {:error, :not_found}
  def get(slug) when is_binary(slug) do
    case Repo.get_by(Project, slug: slug) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end

  @type summary_t :: %{
          project: Project.t(),
          issues_count: non_neg_integer(),
          tasks_count: non_neg_integer(),
          goals_count: non_neg_integer(),
          sessions_count: non_neg_integer()
        }

  @spec get_summary(String.t()) :: {:ok, summary_t()} | {:error, :not_found}
  def get_summary(slug) when is_binary(slug) do
    with {:ok, project} <- get(slug) do
      counts = fetch_counts(slug)
      {:ok, Map.merge(%{project: project}, counts)}
    end
  end

  @spec create(map()) :: {:ok, Project.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    normalized = normalize_keys(attrs)

    %Project{}
    |> Project.changeset(normalized)
    |> Repo.insert()
  end

  @spec update(String.t(), map()) ::
          {:ok, Project.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update(slug, attrs) do
    with {:ok, project} <- get(slug) do
      project
      |> Project.changeset(normalize_keys(attrs))
      |> Repo.update()
    end
  end

  @spec archive(String.t()) :: {:ok, Project.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def archive(slug) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    update(slug, %{status: "archived", archived_at: now})
  end

  @spec unarchive(String.t()) :: {:ok, Project.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def unarchive(slug) do
    update(slug, %{status: "active", archived_at: nil})
  end

  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(slug) do
    with {:ok, project} <- get(slug) do
      dissociate_work_items(slug)
      Repo.delete!(project)
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Private — filtering
  # ---------------------------------------------------------------------------

  defp maybe_filter_workspace(query, %{workspace_slug: ws}) when is_binary(ws),
    do: where(query, [p], p.workspace_slug == ^ws)

  defp maybe_filter_workspace(query, _), do: query

  defp maybe_filter_status(query, %{status: s}) when is_binary(s),
    do: where(query, [p], p.status == ^s)

  defp maybe_filter_status(query, _), do: query

  # ---------------------------------------------------------------------------
  # Private — counts via subqueries (single round-trip)
  # ---------------------------------------------------------------------------

  defp fetch_counts(project_slug) do
    issues_count =
      Repo.one(
        from(i in "issues",
          where: i.project_slug == ^project_slug,
          select: count(i.id)
        )
      ) || 0

    tasks_count =
      Repo.one(
        from(t in "tasks",
          where: t.project_slug == ^project_slug,
          select: count(t.id)
        )
      ) || 0

    goals_count =
      Repo.one(
        from(g in "goals",
          where: g.project_slug == ^project_slug,
          select: count(g.id)
        )
      ) || 0

    %{
      issues_count: issues_count,
      tasks_count: tasks_count,
      goals_count: goals_count,
      sessions_count: 0
    }
  end

  # ---------------------------------------------------------------------------
  # Private — dissociation on delete
  # ---------------------------------------------------------------------------

  defp dissociate_work_items(project_slug) do
    Repo.update_all(
      from(t in "tasks", where: t.project_slug == ^project_slug),
      set: [project_slug: nil]
    )

    Repo.update_all(
      from(i in "issues", where: i.project_slug == ^project_slug),
      set: [project_slug: nil]
    )

    Repo.update_all(
      from(g in "goals", where: g.project_slug == ^project_slug),
      set: [project_slug: nil]
    )
  end

  # ---------------------------------------------------------------------------
  # Private — key normalisation (string → atom)
  # ---------------------------------------------------------------------------

  @known_string_keys ~w(slug name description workspace_slug status color icon
                        owner_type owner_id target_date archived_at)

  defp normalize_keys(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn
      {k, v}, acc when is_atom(k) ->
        Map.put(acc, k, v)

      {k, v}, acc when is_binary(k) and k in @known_string_keys ->
        Map.put(acc, String.to_existing_atom(k), v)

      _, acc ->
        acc
    end)
  end
end
