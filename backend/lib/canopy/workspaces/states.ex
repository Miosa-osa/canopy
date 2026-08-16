defmodule Canopy.Workspaces.States do
  @moduledoc """
  Public API for the per-workspace state store.

  Acts as the workspace's dictionary — any module can persist UI or runtime
  state scoped to a single workspace, keyed by a stable namespaced string.

  Examples of expected keys:
    * `"mosaic.layout"`            — JSON tree of the Mosaic pane layout
    * `"build.sideRail.section"`   — currently selected side-rail section
    * `"files.recentPaths"`        — list of recently opened file paths
    * `"build.density"`            — density preference (`comfortable` | `compact`)

  Limits (enforced here, not in the changeset):
    * `@max_value_bytes`           — 1 MB per stored JSON value
    * `@max_keys_per_workspace`    — 100 keys per workspace

  Soft-deleted workspaces keep their state so a restore reattaches the same UI.
  Use `delete_all/1` to drop everything when a workspace is hard-deleted.
  """

  import Ecto.Query

  alias Canopy.Repo
  alias Canopy.Workspaces.State

  @max_value_bytes 1_048_576
  @max_keys_per_workspace 100

  @type result :: {:ok, State.t()} | {:error, atom() | Ecto.Changeset.t()}

  # ---------------------------------------------------------------------------
  # Reads
  # ---------------------------------------------------------------------------

  @doc """
  Fetches the value stored under `(workspace_slug, key)`.

  Returns `{:ok, value}` (the decoded JSON map/list/scalar), or
  `{:error, :not_found}` if the row does not exist.
  """
  @spec get(String.t(), String.t()) :: {:ok, term()} | {:error, :not_found}
  def get(workspace_slug, key) when is_binary(workspace_slug) and is_binary(key) do
    case Repo.one(state_query(workspace_slug, key)) do
      nil -> {:error, :not_found}
      %State{value: value} -> {:ok, value}
    end
  end

  @doc """
  Returns every key/value pair for `workspace_slug` as a flat map
  `%{key => value}`. Returns `%{}` if the workspace has no state.
  """
  @spec list(String.t()) :: %{String.t() => term()}
  def list(workspace_slug) when is_binary(workspace_slug) do
    State
    |> where([s], s.workspace_slug == ^workspace_slug)
    |> Repo.all()
    |> Map.new(fn %State{key: k, value: v} -> {k, v} end)
  end

  # ---------------------------------------------------------------------------
  # Writes
  # ---------------------------------------------------------------------------

  @doc """
  Inserts or updates a `(workspace_slug, key)` pair with `value`.

  Enforces:
    * value JSON-encoded size ≤ 1 MB → `{:error, :value_too_large}`
    * ≤ 100 keys per workspace → `{:error, :too_many_keys}`
    * slug/key format → returned as `Ecto.Changeset` errors

  Returns `{:ok, %State{}}` on success.
  """
  @spec put(String.t(), String.t(), term()) :: result()
  def put(workspace_slug, key, value)
      when is_binary(workspace_slug) and is_binary(key) do
    with :ok <- validate_value_size(value),
         :ok <- validate_capacity(workspace_slug, key) do
      attrs = %{workspace_slug: workspace_slug, key: key, value: value}

      case Repo.one(state_query(workspace_slug, key)) do
        nil ->
          %State{}
          |> State.changeset(attrs)
          |> Repo.insert()

        existing ->
          existing
          |> State.changeset(attrs)
          |> Repo.update()
      end
    end
  end

  @doc """
  Removes a single `(workspace_slug, key)` entry.

  Returns `{:ok, %State{}}` on success or `{:error, :not_found}`.
  """
  @spec delete(String.t(), String.t()) :: {:ok, State.t()} | {:error, :not_found}
  def delete(workspace_slug, key) when is_binary(workspace_slug) and is_binary(key) do
    case Repo.one(state_query(workspace_slug, key)) do
      nil -> {:error, :not_found}
      state -> Repo.delete(state)
    end
  end

  @doc """
  Removes every state row for `workspace_slug`. Used when a workspace is
  hard-deleted. Returns `{:ok, count}`.
  """
  @spec delete_all(String.t()) :: {:ok, non_neg_integer()}
  def delete_all(workspace_slug) when is_binary(workspace_slug) do
    {count, _} =
      State
      |> where([s], s.workspace_slug == ^workspace_slug)
      |> Repo.delete_all()

    {:ok, count}
  end

  # ---------------------------------------------------------------------------
  # Limit accessors (used by controller for documentation/validation)
  # ---------------------------------------------------------------------------

  @doc "Returns the per-key value-size cap in bytes."
  @spec max_value_bytes() :: pos_integer()
  def max_value_bytes, do: @max_value_bytes

  @doc "Returns the per-workspace key-count cap."
  @spec max_keys_per_workspace() :: pos_integer()
  def max_keys_per_workspace, do: @max_keys_per_workspace

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp state_query(workspace_slug, key) do
    from s in State,
      where: s.workspace_slug == ^workspace_slug and s.key == ^key
  end

  defp validate_value_size(value) do
    case Jason.encode(value) do
      {:ok, encoded} ->
        if byte_size(encoded) <= @max_value_bytes do
          :ok
        else
          {:error, :value_too_large}
        end

      {:error, _reason} ->
        {:error, :invalid_value}
    end
  end

  defp validate_capacity(workspace_slug, key) do
    existing? =
      Repo.exists?(
        from s in State,
          where: s.workspace_slug == ^workspace_slug and s.key == ^key
      )

    if existing? do
      :ok
    else
      count =
        Repo.aggregate(
          from(s in State, where: s.workspace_slug == ^workspace_slug),
          :count,
          :id
        )

      if count >= @max_keys_per_workspace do
        {:error, :too_many_keys}
      else
        :ok
      end
    end
  end
end
