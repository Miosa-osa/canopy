defmodule Canopy.Goals do
  @moduledoc """
  Context for the Goals domain.

  Orchestrator-facing unit. High-level objectives spanning many issues/tasks.
  Short IDs use a random 8-digit numeric suffix: `G-XXXXXXXX`.

  ## API

  - `list/1`         — query with optional filters
  - `get/1`          — by short_id or uuid
  - `create/1`       — inserts, auto-generates short_id
  - `update/2`       — by short_id
  - `set_progress/2` — update progress_pct
  - `achieve/1`      — mark achieved, set achieved_at
  - `cancel/1`       — mark cancelled
  - `delete/1`       — hard delete by short_id
  """

  import Ecto.Query, only: [from: 2, where: 3]

  alias Canopy.Goals.Goal
  alias Canopy.Repo

  @spec list(map()) :: [Goal.t()]
  def list(filters \\ %{}) do
    limit = filters |> Map.get(:limit, 50) |> min(200)

    from(g in Goal, order_by: [desc: g.updated_at], limit: ^limit)
    |> maybe_filter_status(filters)
    |> maybe_filter_workspace(filters)
    |> maybe_filter_owner(filters)
    |> maybe_filter_query(filters)
    |> Repo.all()
  end

  @spec get(String.t()) :: {:ok, Goal.t()} | {:error, :not_found}
  def get(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} ->
        case Repo.get(Goal, id) do
          nil -> {:error, :not_found}
          goal -> {:ok, goal}
        end

      :error ->
        case Repo.get_by(Goal, short_id: id) do
          nil -> {:error, :not_found}
          goal -> {:ok, goal}
        end
    end
  end

  @spec create(map()) :: {:ok, Goal.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    normalized = normalize_keys(attrs)
    attrs_with_id = Map.put_new(normalized, :short_id, generate_short_id())

    %Goal{}
    |> Goal.changeset(attrs_with_id)
    |> Repo.insert()
  end

  @spec update(String.t(), map()) :: {:ok, Goal.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update(id, attrs) do
    with {:ok, goal} <- get(id) do
      goal
      |> Goal.changeset(attrs)
      |> Repo.update()
    end
  end

  @spec set_progress(String.t(), integer()) ::
          {:ok, Goal.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def set_progress(id, pct) when is_integer(pct) do
    update(id, %{progress_pct: pct})
  end

  @spec achieve(String.t()) :: {:ok, Goal.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def achieve(id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    update(id, %{status: "achieved", achieved_at: now, progress_pct: 100})
  end

  @spec cancel(String.t()) :: {:ok, Goal.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def cancel(id) do
    update(id, %{status: "cancelled"})
  end

  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(id) do
    with {:ok, goal} <- get(id) do
      Repo.delete!(goal)
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp generate_short_id do
    n = :rand.uniform(100_000_000) - 1
    "G-" <> String.pad_leading(Integer.to_string(n), 8, "0")
  end

  @known_string_keys ~w(short_id title description status priority owner_type owner_id
                        workspace_slug project_slug target_date achieved_at progress_pct success_criteria)

  @spec normalize_keys(map()) :: map()
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

  defp maybe_filter_status(query, %{status: s}) when is_binary(s),
    do: where(query, [g], g.status == ^s)

  defp maybe_filter_status(query, _), do: query

  defp maybe_filter_workspace(query, %{workspace_slug: ws}) when is_binary(ws),
    do: where(query, [g], g.workspace_slug == ^ws)

  defp maybe_filter_workspace(query, _), do: query

  defp maybe_filter_owner(query, %{owner_type: ot, owner_id: oid})
       when is_binary(ot) and is_binary(oid),
       do: where(query, [g], g.owner_type == ^ot and g.owner_id == ^oid)

  defp maybe_filter_owner(query, %{owner_id: oid}) when is_binary(oid),
    do: where(query, [g], g.owner_id == ^oid)

  defp maybe_filter_owner(query, _), do: query

  defp maybe_filter_query(query, %{q: q}) when is_binary(q) and q != "" do
    pattern = "%#{String.replace(q, ["%", "_"], fn c -> "\\#{c}" end)}%"
    where(query, [g], ilike(g.title, ^pattern))
  end

  defp maybe_filter_query(query, _), do: query
end
