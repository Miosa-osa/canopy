defmodule Canopy.Drive do
  @moduledoc """
  Public API for the Drive super-module.

  Drive is the unified shell of typed knowledge entries — a tree of
  Folders / Workflows / Prompts / Notebooks / Env vars / MCP servers / Rules
  rooted at one of two scopes (Personal | Team). It is the operational data
  layer for **Vault**, the Drive curator agent.

  ## What Drive is — and is not

  Drive does **not** replace existing primitives. For polymorphic entries
  whose body is a foreign-key envelope, the underlying record lives in its
  own context:

  - `kind=workflow`   → `Canopy.Routines.Routine`
  - `kind=notebook`   → `Canopy.Sessions.Block`
  - `kind=env_vars`   → `Canopy.Vault` credential rows
  - `kind=mcp_server` → MCP server registry (Phase B)

  Only `kind=prompt` and `kind=rule` introduce new primitives. `kind=folder`
  is a pure organizational container with no body.

  ## Operations

  - `list/1` — filter by scope, parent_id, kind, archived
  - `get/1`, `get_by_slug/1`
  - `create/1`, `update/2`, `archive/1`, `restore/1`
  - `move/2` — change `parent_id`
  - `reorder/2` — write new positions for a sibling group in one transaction
  - `tree/1` — build a nested tree for a scope
  - `search/2` — full-text on name + jsonb body
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Drive.Entry
  alias Canopy.Repo

  @default_limit 200
  @max_limit 1000

  # ---------------------------------------------------------------------------
  # Read
  # ---------------------------------------------------------------------------

  @doc """
  Lists drive entries with filters.

  Options:
  - `:scope` — `"personal"` | `"team"`
  - `:parent_id` — uuid or `:root` (top-level only)
  - `:kind` — restrict to a single kind
  - `:archived` — `true` (archived only), `false` (active only, default), `:all`
  - `:limit` — default 200, capped at 1000
  """
  @spec list(keyword()) :: [Entry.t()]
  def list(opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_limit) |> min(@max_limit)
    archived = Keyword.get(opts, :archived, false)

    from(e in Entry,
      order_by: [asc: e.position, asc: e.name],
      limit: ^limit
    )
    |> filter(:scope, opts[:scope])
    |> filter(:kind, opts[:kind])
    |> filter_parent(opts[:parent_id])
    |> filter_archived(archived)
    |> Repo.all()
  end

  @doc "Fetches a single entry by id. Returns `nil` if not found."
  @spec get(Ecto.UUID.t()) :: Entry.t() | nil
  def get(id), do: Repo.get(Entry, id)

  @doc "Fetches a single entry by id. Raises `Ecto.NoResultsError` if missing."
  @spec get!(Ecto.UUID.t()) :: Entry.t()
  def get!(id), do: Repo.get!(Entry, id)

  @doc """
  Fetches a single entry by slug, optionally scoped.

  Returns the first match. Slugs are unique within `(scope, parent_id)`, so
  callers wanting a specific entry should also pass `:scope` and
  `:parent_id`.
  """
  @spec get_by_slug(String.t(), keyword()) :: Entry.t() | nil
  def get_by_slug(slug, opts \\ []) when is_binary(slug) do
    query = from(e in Entry, where: e.slug == ^slug, limit: 1)

    query
    |> filter(:scope, opts[:scope])
    |> filter_parent(opts[:parent_id])
    |> Repo.one()
  end

  # ---------------------------------------------------------------------------
  # Write
  # ---------------------------------------------------------------------------

  @doc "Creates a new entry."
  @spec create(map()) :: {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    attrs = attrs |> stringify_keys() |> maybe_assign_position()
    %Entry{} |> Entry.changeset(attrs) |> Repo.insert()
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  @doc "Updates an entry."
  @spec update(Entry.t(), map()) :: {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def update(%Entry{} = entry, attrs) do
    entry |> Entry.changeset(attrs) |> Repo.update()
  end

  @doc "Soft-archives an entry by stamping `archived_at`."
  @spec archive(Entry.t()) :: {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def archive(%Entry{} = entry) do
    update(entry, %{archived_at: DateTime.utc_now()})
  end

  @doc "Restores an archived entry by clearing `archived_at`."
  @spec restore(Entry.t()) :: {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def restore(%Entry{} = entry) do
    update(entry, %{archived_at: nil})
  end

  @doc """
  Moves an entry under a new parent.

  Pass `nil` (or `:root`) to move to the top of the entry's scope.
  """
  @spec move(Entry.t(), Ecto.UUID.t() | nil | :root) ::
          {:ok, Entry.t()} | {:error, Ecto.Changeset.t() | :cycle}
  def move(%Entry{id: id} = entry, new_parent_id) do
    new_parent_id = if new_parent_id == :root, do: nil, else: new_parent_id

    cond do
      new_parent_id == id ->
        {:error, :cycle}

      new_parent_id && would_create_cycle?(id, new_parent_id) ->
        {:error, :cycle}

      true ->
        update(entry, %{parent_id: new_parent_id})
    end
  end

  @doc """
  Reorders a sibling group atomically.

  Accepts a list of `{id, position}` pairs (or a list of ids — the index
  becomes the position). Wraps the writes in a transaction so partial
  reorders never persist.
  """
  @spec reorder(any(), [{Ecto.UUID.t(), non_neg_integer()}] | [Ecto.UUID.t()]) ::
          {:ok, non_neg_integer()} | {:error, Ecto.Changeset.t()}
  def reorder(_scope, ordering) when is_list(ordering) do
    pairs =
      ordering
      |> Enum.with_index()
      |> Enum.map(fn
        {{id, pos}, _idx} when is_binary(id) and is_integer(pos) -> {id, pos}
        {id, idx} when is_binary(id) -> {id, idx}
      end)

    Repo.transaction(fn ->
      Enum.each(pairs, fn {id, pos} ->
        case Repo.get(Entry, id) do
          nil ->
            Repo.rollback(:not_found)

          entry ->
            case update(entry, %{position: pos}) do
              {:ok, _} -> :ok
              {:error, cs} -> Repo.rollback(cs)
            end
        end
      end)

      length(pairs)
    end)
  end

  @doc """
  Returns a nested tree for a single scope.

  Each node is a map with `:entry` and `:children`. Order is by `position`
  then `name`. Archived entries are excluded by default; pass
  `archived: :all` to include them.
  """
  @spec tree(keyword()) :: [map()]
  def tree(opts \\ []) do
    scope = Keyword.fetch!(opts, :scope)
    archived = Keyword.get(opts, :archived, false)

    entries =
      from(e in Entry,
        where: e.scope == ^scope,
        order_by: [asc: e.position, asc: e.name]
      )
      |> filter_archived(archived)
      |> Repo.all()

    by_parent = Enum.group_by(entries, & &1.parent_id)
    build_tree(Map.get(by_parent, nil, []), by_parent)
  end

  defp build_tree(entries, by_parent) do
    Enum.map(entries, fn entry ->
      %{
        entry: entry,
        children: build_tree(Map.get(by_parent, entry.id, []), by_parent)
      }
    end)
  end

  @doc """
  Full-text search across name and stringified body.

  Uses Postgres `ILIKE` against `name` and the JSONB body cast to text.
  For larger workspaces this should migrate to a tsvector column; the
  current implementation is correct but linear in row count.
  """
  @spec search(String.t(), keyword()) :: [Entry.t()]
  def search(term, opts \\ []) when is_binary(term) do
    pattern = "%#{escape_like(term)}%"
    limit = opts |> Keyword.get(:limit, @default_limit) |> min(@max_limit)

    from(e in Entry,
      where:
        ilike(e.name, ^pattern) or
          fragment("CAST(? AS text) ILIKE ?", e.body, ^pattern),
      order_by: [asc: e.name],
      limit: ^limit
    )
    |> filter(:scope, opts[:scope])
    |> filter(:kind, opts[:kind])
    |> filter_archived(Keyword.get(opts, :archived, false))
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp filter(query, _field, nil), do: query

  defp filter(query, field, value) do
    from(q in query, where: field(q, ^field) == ^value)
  end

  defp filter_parent(query, nil), do: query

  defp filter_parent(query, :root) do
    from(q in query, where: is_nil(q.parent_id))
  end

  defp filter_parent(query, parent_id) when is_binary(parent_id) do
    from(q in query, where: q.parent_id == ^parent_id)
  end

  defp filter_archived(query, false) do
    from(q in query, where: is_nil(q.archived_at))
  end

  defp filter_archived(query, true) do
    from(q in query, where: not is_nil(q.archived_at))
  end

  defp filter_archived(query, :all), do: query
  defp filter_archived(query, _), do: filter_archived(query, false)

  defp maybe_assign_position(attrs) do
    if Map.has_key?(attrs, :position) or Map.has_key?(attrs, "position") do
      attrs
    else
      scope = Map.get(attrs, :scope) || Map.get(attrs, "scope")
      parent_id = Map.get(attrs, :parent_id) || Map.get(attrs, "parent_id")

      next_pos = next_position(scope, parent_id)
      # Use string key to avoid mixing atom and string keys downstream.
      Map.put(attrs, "position", next_pos)
    end
  end

  defp next_position(nil, _), do: 0

  defp next_position(scope, parent_id) do
    base = from(e in Entry, where: e.scope == ^scope, select: max(e.position))

    query =
      if is_nil(parent_id) do
        from(q in base, where: is_nil(q.parent_id))
      else
        from(q in base, where: q.parent_id == ^parent_id)
      end

    case Repo.one(query) do
      nil -> 0
      n -> n + 1
    end
  end

  defp would_create_cycle?(entry_id, ancestor_id) do
    case Repo.get(Entry, ancestor_id) do
      nil -> false
      %Entry{parent_id: nil} -> false
      %Entry{parent_id: ^entry_id} -> true
      %Entry{parent_id: pid} -> would_create_cycle?(entry_id, pid)
    end
  end

  defp escape_like(term) do
    term
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
