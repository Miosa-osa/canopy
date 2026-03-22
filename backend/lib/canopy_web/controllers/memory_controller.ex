defmodule CanopyWeb.MemoryController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.MemoryEntry
  import Ecto.Query

  def index(conn, params) do
    workspace_id = params["workspace_id"]
    agent_id = params["agent_id"]
    category = params["category"]
    limit = min(String.to_integer(params["limit"] || "50"), 200)
    offset = String.to_integer(params["offset"] || "0")

    query =
      from e in MemoryEntry,
        order_by: [desc: e.inserted_at],
        limit: ^limit,
        offset: ^offset

    query = if workspace_id, do: where(query, [e], e.workspace_id == ^workspace_id), else: query
    query = if agent_id, do: where(query, [e], e.agent_id == ^agent_id), else: query
    query = if category, do: where(query, [e], e.category == ^category), else: query

    entries = Repo.all(query)
    json(conn, %{entries: Enum.map(entries, &serialize/1)})
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(MemoryEntry, id) do
      nil -> conn |> put_status(404) |> json(%{error: "not_found"})
      entry -> json(conn, %{entry: serialize(entry)})
    end
  end

  def create(conn, params) do
    changeset = MemoryEntry.changeset(%MemoryEntry{}, params)

    case Repo.insert(changeset) do
      {:ok, entry} ->
        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(entry.workspace_id),
          %{event: "memory.created", entry_id: entry.id, key: entry.key}
        )

        conn |> put_status(201) |> json(%{entry: serialize(entry)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(MemoryEntry, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      entry ->
        changeset = MemoryEntry.changeset(entry, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            Canopy.EventBus.broadcast(
              Canopy.EventBus.workspace_topic(updated.workspace_id),
              %{event: "memory.updated", entry_id: updated.id, key: updated.key}
            )

            json(conn, %{entry: serialize(updated)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(MemoryEntry, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      entry ->
        Repo.delete!(entry)

        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(entry.workspace_id),
          %{event: "memory.deleted", entry_id: id}
        )

        json(conn, %{ok: true})
    end
  end

  def namespaces(conn, params) do
    workspace_id = params["workspace_id"]

    query = from m in MemoryEntry, select: {m.category, count(m.id)}, group_by: m.category
    query = if workspace_id, do: where(query, [m], m.workspace_id == ^workspace_id), else: query

    results = Repo.all(query)

    json(conn, %{
      namespaces:
        Enum.map(results, fn {name, count} ->
          %{name: name || "default", count: count}
        end)
    })
  end

  def search(conn, params) do
    q = params["q"] || ""
    workspace_id = params["workspace_id"]
    pattern = "%#{q}%"

    query =
      from e in MemoryEntry,
        where:
          ilike(e.key, ^pattern) or
            ilike(e.content, ^pattern) or
            fragment("array_to_string(?, ',') ILIKE ?", e.tags, ^pattern),
        order_by: [desc: e.inserted_at],
        limit: 50

    query = if workspace_id, do: where(query, [e], e.workspace_id == ^workspace_id), else: query

    entries = Repo.all(query)
    json(conn, %{entries: Enum.map(entries, &serialize/1), query: q})
  end

  defp serialize(%MemoryEntry{} = e) do
    %{
      id: e.id,
      key: e.key,
      content: e.content,
      value: e.content,
      type: e.category,
      category: e.category,
      tags: e.tags || [],
      workspace_id: e.workspace_id,
      agent_id: e.agent_id,
      agent_name: nil,
      created_at: e.inserted_at,
      inserted_at: e.inserted_at,
      updated_at: e.updated_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
