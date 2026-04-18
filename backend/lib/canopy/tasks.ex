defmodule Canopy.Tasks do
  @moduledoc """
  Context for the Tasks domain.

  Single `tasks` table. Short IDs use a random 8-digit numeric suffix: `T-XXXXXXXX`.

  ## API

  - `list/1` — query with optional filters
  - `get/1` — by short_id
  - `create/1` — inserts, auto-generates short_id
  - `update/2` — by short_id
  - `delete/1` — hard delete by short_id
  - `assign/3` — set assignee_type + assignee_id
  - `complete/1` — mark done, set completed_at
  - `reopen/1` — mark todo, clear completed_at
  """

  import Ecto.Query, only: [from: 2, where: 3]

  alias Canopy.Repo
  alias Canopy.Tasks.Task

  @spec list(map()) :: [Task.t()]
  def list(filters \\ %{}) do
    limit = filters |> Map.get(:limit, 50) |> min(200)

    from(t in Task, order_by: [desc: t.updated_at], limit: ^limit)
    |> maybe_filter_status(filters)
    |> maybe_filter_assignee(filters)
    |> maybe_filter_project(filters)
    |> maybe_filter_parent(filters)
    |> maybe_filter_query(filters)
    |> Repo.all()
  end

  @spec get(String.t()) :: {:ok, Task.t()} | {:error, :not_found}
  def get(short_id) when is_binary(short_id) do
    case Repo.get_by(Task, short_id: short_id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  @spec create(map()) :: {:ok, Task.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    attrs_with_id = Map.put_new(attrs, :short_id, generate_short_id())

    %Task{}
    |> Task.changeset(attrs_with_id)
    |> Repo.insert()
  end

  @spec update(String.t(), map()) :: {:ok, Task.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update(short_id, attrs) do
    with {:ok, task} <- get(short_id) do
      task
      |> Task.changeset(attrs)
      |> Repo.update()
    end
  end

  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(short_id) do
    with {:ok, task} <- get(short_id) do
      Repo.delete!(task)
      :ok
    end
  end

  @spec assign(String.t(), String.t(), String.t()) ::
          {:ok, Task.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def assign(short_id, assignee_type, assignee_id) do
    update(short_id, %{assignee_type: assignee_type, assignee_id: assignee_id})
  end

  @spec complete(String.t()) :: {:ok, Task.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def complete(short_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    update(short_id, %{status: "done", completed_at: now})
  end

  @spec reopen(String.t()) :: {:ok, Task.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def reopen(short_id) do
    update(short_id, %{status: "todo", completed_at: nil})
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp generate_short_id do
    n = :rand.uniform(100_000_000) - 1
    "T-" <> String.pad_leading(Integer.to_string(n), 8, "0")
  end

  defp maybe_filter_status(query, %{status: s}) when is_binary(s),
    do: where(query, [t], t.status == ^s)

  defp maybe_filter_status(query, _), do: query

  defp maybe_filter_assignee(query, %{assignee_type: at, assignee_id: aid})
       when is_binary(at) and is_binary(aid),
       do: where(query, [t], t.assignee_type == ^at and t.assignee_id == ^aid)

  defp maybe_filter_assignee(query, %{assignee_type: at}) when is_binary(at),
    do: where(query, [t], t.assignee_type == ^at)

  defp maybe_filter_assignee(query, _), do: query

  defp maybe_filter_project(query, %{project_slug: ps}) when is_binary(ps),
    do: where(query, [t], t.project_slug == ^ps)

  defp maybe_filter_project(query, _), do: query

  defp maybe_filter_parent(query, %{parent_id: pid}) when is_binary(pid),
    do: where(query, [t], t.parent_id == ^pid)

  defp maybe_filter_parent(query, _), do: query

  defp maybe_filter_query(query, %{q: q}) when is_binary(q) and q != "" do
    pattern = "%#{String.replace(q, ["%", "_"], fn c -> "\\#{c}" end)}%"
    where(query, [t], ilike(t.title, ^pattern))
  end

  defp maybe_filter_query(query, _), do: query
end
