defmodule Canopy.Tools.Drive do
  @moduledoc """
  Drive tool surface for the **Vault** agent (Drive curator).

  Exposes `drive.*` tools that wrap `Canopy.Drive` API calls into the
  canonical tool-handler signature so they can be invoked by any runtime
  adapter via MCP or system-prompt injection.

  ## Tool list

  - `drive.list`    — list entries (filter by scope/parent/kind/archived)
  - `drive.get`     — fetch a single entry by id
  - `drive.create`  — create an entry (any kind)
  - `drive.update`  — update an entry's name / body / tags
  - `drive.move`    — reparent an entry
  - `drive.archive` — soft-archive
  - `drive.search`  — full-text across name + body
  - `drive.import`  — Phase B placeholder (returns not_implemented)
  """

  use Canopy.Tool

  alias Canopy.Drive

  # ---------------------------------------------------------------------------
  # Tool declarations
  # ---------------------------------------------------------------------------

  tool("drive.list",
    description: """
    List drive entries with optional filters. Returns entries ordered by
    position then name.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "scope" => %{"type" => "string", "enum" => ["personal", "team"]},
        "parent_id" => %{"type" => "string", "description" => "UUID or 'root'"},
        "kind" => %{"type" => "string"},
        "archived" => %{"type" => "string", "enum" => ["true", "false", "all"]},
        "limit" => %{"type" => "integer"}
      }
    },
    handler: {__MODULE__, :list, []},
    requires: [:drive]
  )

  tool("drive.get",
    description: "Fetch a single drive entry by id.",
    parameters: %{
      "type" => "object",
      "properties" => %{"id" => %{"type" => "string"}},
      "required" => ["id"]
    },
    handler: {__MODULE__, :get, []},
    requires: [:drive]
  )

  tool("drive.create",
    description: """
    Create a new drive entry. `kind` selects the body interpretation:
    folder, workflow, prompt, notebook, env_vars, mcp_server, or rule.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "kind" => %{"type" => "string"},
        "scope" => %{"type" => "string", "enum" => ["personal", "team"]},
        "parent_id" => %{"type" => "string"},
        "body" => %{"type" => "object"},
        "tags" => %{"type" => "array", "items" => %{"type" => "string"}}
      },
      "required" => ["slug", "name", "kind", "scope"]
    },
    handler: {__MODULE__, :create, []},
    requires: [:drive]
  )

  tool("drive.update",
    description: "Update an existing drive entry's name, body, or tags.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "body" => %{"type" => "object"},
        "tags" => %{"type" => "array", "items" => %{"type" => "string"}}
      },
      "required" => ["id"]
    },
    handler: {__MODULE__, :update, []},
    requires: [:drive]
  )

  tool("drive.move",
    description: "Reparent a drive entry under a new folder (or root).",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "parent_id" => %{
          "type" => "string",
          "description" => "Target folder id, or null/'root' for top level"
        }
      },
      "required" => ["id"]
    },
    handler: {__MODULE__, :move, []},
    requires: [:drive]
  )

  tool("drive.archive",
    description: "Soft-archive a drive entry. Restorable via update.",
    parameters: %{
      "type" => "object",
      "properties" => %{"id" => %{"type" => "string"}},
      "required" => ["id"]
    },
    handler: {__MODULE__, :archive, []},
    requires: [:drive]
  )

  tool("drive.search",
    description: "Full-text search drive entries by name and body.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "query" => %{"type" => "string"},
        "scope" => %{"type" => "string"},
        "kind" => %{"type" => "string"},
        "limit" => %{"type" => "integer"}
      },
      "required" => ["query"]
    },
    handler: {__MODULE__, :search, []},
    requires: [:drive]
  )

  tool("drive.import",
    description: """
    Phase B placeholder: import from external sources (Notion, Drive, etc.).
    Currently returns `{:error, :not_implemented}`.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "source" => %{"type" => "string"},
        "scope" => %{"type" => "string"}
      }
    },
    handler: {__MODULE__, :import, []},
    requires: [:drive]
  )

  # ---------------------------------------------------------------------------
  # Handlers
  # ---------------------------------------------------------------------------

  @doc false
  def list(args) do
    opts =
      []
      |> put_opt(:scope, args["scope"])
      |> put_opt(:kind, args["kind"])
      |> put_opt(:parent_id, parse_parent(args["parent_id"]))
      |> put_opt(:archived, parse_archived(args["archived"]))
      |> put_opt(:limit, args["limit"])

    entries = Drive.list(opts)
    {:ok, %{count: length(entries), entries: Enum.map(entries, &serialize/1)}}
  end

  @doc false
  def get(%{"id" => id}) do
    case Drive.get(id) do
      nil -> {:error, :not_found}
      entry -> {:ok, serialize(entry)}
    end
  end

  @doc false
  def create(args) do
    case Drive.create(coerce_keys(args)) do
      {:ok, entry} -> {:ok, serialize(entry)}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  @doc false
  def update(%{"id" => id} = args) do
    case Drive.get(id) do
      nil ->
        {:error, :not_found}

      entry ->
        attrs = args |> Map.delete("id") |> coerce_keys()

        case Drive.update(entry, attrs) do
          {:ok, updated} -> {:ok, serialize(updated)}
          {:error, changeset} -> {:error, format_errors(changeset)}
        end
    end
  end

  @doc false
  def move(%{"id" => id} = args) do
    case Drive.get(id) do
      nil ->
        {:error, :not_found}

      entry ->
        case Drive.move(entry, parse_parent(args["parent_id"])) do
          {:ok, updated} -> {:ok, serialize(updated)}
          {:error, :cycle} -> {:error, "would create a cycle"}
          {:error, changeset} -> {:error, format_errors(changeset)}
        end
    end
  end

  @doc false
  def archive(%{"id" => id}) do
    case Drive.get(id) do
      nil ->
        {:error, :not_found}

      entry ->
        case Drive.archive(entry) do
          {:ok, archived} -> {:ok, serialize(archived)}
          {:error, changeset} -> {:error, format_errors(changeset)}
        end
    end
  end

  @doc false
  def search(%{"query" => query} = args) do
    opts =
      []
      |> put_opt(:scope, args["scope"])
      |> put_opt(:kind, args["kind"])
      |> put_opt(:limit, args["limit"])

    entries = Drive.search(query, opts)
    {:ok, %{count: length(entries), entries: Enum.map(entries, &serialize/1)}}
  end

  @doc false
  def import(_args), do: {:error, :not_implemented}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp put_opt(opts, _key, nil), do: opts
  defp put_opt(opts, key, value), do: [{key, value} | opts]

  defp parse_parent(nil), do: nil
  defp parse_parent(""), do: nil
  defp parse_parent("root"), do: :root
  defp parse_parent(id) when is_binary(id), do: id
  defp parse_parent(_), do: nil

  defp parse_archived("true"), do: true
  defp parse_archived("false"), do: false
  defp parse_archived("all"), do: :all
  defp parse_archived(_), do: nil

  defp coerce_keys(args) when is_map(args) do
    args
    |> Enum.map(fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      pair -> pair
    end)
    |> Map.new()
  rescue
    ArgumentError -> args
  end

  defp serialize(entry) do
    %{
      id: entry.id,
      slug: entry.slug,
      name: entry.name,
      kind: entry.kind,
      scope: entry.scope,
      parent_id: entry.parent_id,
      body: entry.body,
      owner_id: entry.owner_id,
      tags: entry.tags,
      position: entry.position,
      archived_at: entry.archived_at,
      inserted_at: entry.inserted_at,
      updated_at: entry.updated_at
    }
  end

  defp format_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
  end
end
