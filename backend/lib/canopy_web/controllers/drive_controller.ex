defmodule CanopyWeb.DriveController do
  @moduledoc """
  HTTP API for the Drive super-module.

  Routes:
    GET    /api/v1/drive                      — list entries (filtered)
    POST   /api/v1/drive                      — create entry
    GET    /api/v1/drive/tree                 — nested tree for a scope
    GET    /api/v1/drive/search               — full-text search
    GET    /api/v1/drive/:id                  — show entry
    PATCH  /api/v1/drive/:id                  — update entry
    POST   /api/v1/drive/:id/archive          — soft-archive
    POST   /api/v1/drive/:id/restore          — restore archived
    POST   /api/v1/drive/:id/move             — reparent
    POST   /api/v1/drive/reorder              — batch reorder a sibling group
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Drive
  alias CanopyWeb.Schemas.DriveSchema

  action_fallback CanopyWeb.FallbackController

  tags ["drive"]

  @max_limit 1000
  @default_limit 200
  @slug_regex ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/
  @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  @valid_scopes ~w(personal team)
  @valid_kinds ~w(folder workflow prompt notebook env_vars mcp_server rule)

  # ---------------------------------------------------------------------------
  # Index
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List drive entries",
    parameters: [
      scope: [in: :query, type: :string, required: false],
      parent_id: [in: :query, type: :string, required: false],
      kind: [in: :query, type: :string, required: false],
      archived: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Drive entry list", "application/json", DriveSchema.EntryList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    with :ok <- validate_scope_opt(params["scope"]),
         :ok <- validate_kind_opt(params["kind"]),
         {:ok, parent_id} <- validate_parent_opt(params["parent_id"]) do
      opts =
        []
        |> maybe_put(:scope, params["scope"])
        |> maybe_put(:kind, params["kind"])
        |> maybe_put(:parent_id, parent_id)
        |> maybe_put(:archived, parse_archived(params["archived"]))
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{data: Drive.list(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Tree
  # ---------------------------------------------------------------------------

  operation :tree,
    summary: "Nested tree for a scope",
    parameters: [
      scope: [in: :query, type: :string, required: true],
      archived: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Drive tree", "application/json", DriveSchema.Tree}]

  @spec tree(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def tree(conn, %{"scope" => scope} = params) do
    with :ok <- validate_scope(scope) do
      opts =
        [scope: scope]
        |> maybe_put(:archived, parse_archived(params["archived"]))

      tree = Drive.tree(opts)
      json(conn, %{scope: scope, data: tree})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  def tree(conn, _params), do: bad_request(conn, "scope is required")

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  operation :search,
    summary: "Full-text search drive entries",
    parameters: [
      q: [in: :query, type: :string, required: true],
      scope: [in: :query, type: :string, required: false],
      kind: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Search results", "application/json", DriveSchema.EntryList}]

  @spec search(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def search(conn, %{"q" => q} = params) when is_binary(q) and q != "" do
    with :ok <- validate_scope_opt(params["scope"]),
         :ok <- validate_kind_opt(params["kind"]) do
      opts =
        []
        |> maybe_put(:scope, params["scope"])
        |> maybe_put(:kind, params["kind"])
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{query: q, data: Drive.search(q, opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  def search(conn, _params), do: bad_request(conn, "q is required")

  # ---------------------------------------------------------------------------
  # Show
  # ---------------------------------------------------------------------------

  operation :show,
    summary: "Show a drive entry",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [ok: {"Drive entry", "application/json", DriveSchema.Entry}]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, id} <- validate_uuid(id, "id") do
      case Drive.get(id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "drive_entry_not_found", id: id})

        entry ->
          json(conn, entry)
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------

  operation :create,
    summary: "Create a drive entry",
    request_body: {"Drive entry create", "application/json", DriveSchema.EntryCreate},
    responses: [created: {"Drive entry", "application/json", DriveSchema.Entry}]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    with :ok <- validate_slug(params["slug"]),
         :ok <- validate_kind(params["kind"]),
         :ok <- validate_scope(params["scope"]),
         {:ok, parent_id} <- validate_uuid_opt(params["parent_id"]) do
      attrs = params |> Map.put("parent_id", parent_id)

      case Drive.create(attrs) do
        {:ok, entry} -> conn |> put_status(:created) |> json(entry)
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Update
  # ---------------------------------------------------------------------------

  operation :update,
    summary: "Update a drive entry",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Drive entry update", "application/json", DriveSchema.EntryUpdate},
    responses: [ok: {"Drive entry", "application/json", DriveSchema.Entry}]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    with {:ok, id} <- validate_uuid(id, "id") do
      case Drive.get(id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "drive_entry_not_found", id: id})

        entry ->
          attrs = Map.delete(params, "id")

          case Drive.update(entry, attrs) do
            {:ok, updated} -> json(conn, updated)
            {:error, changeset} -> {:error, changeset}
          end
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Archive / Restore
  # ---------------------------------------------------------------------------

  operation :archive,
    summary: "Soft-archive a drive entry",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [ok: {"Drive entry", "application/json", DriveSchema.Entry}]

  @spec archive(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def archive(conn, %{"id" => id}), do: with_entry(conn, id, &Drive.archive/1)

  operation :restore,
    summary: "Restore an archived drive entry",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [ok: {"Drive entry", "application/json", DriveSchema.Entry}]

  @spec restore(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def restore(conn, %{"id" => id}), do: with_entry(conn, id, &Drive.restore/1)

  # ---------------------------------------------------------------------------
  # Move
  # ---------------------------------------------------------------------------

  operation :move,
    summary: "Reparent a drive entry",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Move target", "application/json", DriveSchema.MoveBody},
    responses: [ok: {"Drive entry", "application/json", DriveSchema.Entry}]

  @spec move(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def move(conn, %{"id" => id} = params) do
    with {:ok, id} <- validate_uuid(id, "id"),
         {:ok, parent_id} <- validate_uuid_opt(params["parent_id"]) do
      case Drive.get(id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "drive_entry_not_found", id: id})

        entry ->
          target = if is_nil(parent_id), do: :root, else: parent_id

          case Drive.move(entry, target) do
            {:ok, updated} -> json(conn, updated)
            {:error, :cycle} -> bad_request(conn, "move would create a cycle")
            {:error, changeset} -> {:error, changeset}
          end
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Reorder
  # ---------------------------------------------------------------------------

  operation :reorder,
    summary: "Reorder a sibling group",
    request_body: {"Reorder body", "application/json", DriveSchema.ReorderBody},
    responses: [ok: {"Reorder result", "application/json", DriveSchema.ReorderResult}]

  @spec reorder(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reorder(conn, %{"ids" => ids}) when is_list(ids) do
    with :ok <- validate_uuid_list(ids) do
      case Drive.reorder(:any, ids) do
        {:ok, n} -> json(conn, %{count: n})
        {:error, :not_found} -> bad_request(conn, "one or more ids not found")
        {:error, _changeset} -> bad_request(conn, "reorder failed")
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  def reorder(conn, _params), do: bad_request(conn, "ids array is required")

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp with_entry(conn, id, op) do
    with {:ok, id} <- validate_uuid(id, "id") do
      case Drive.get(id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "drive_entry_not_found", id: id})

        entry ->
          case op.(entry) do
            {:ok, updated} -> json(conn, updated)
            {:error, changeset} -> {:error, changeset}
          end
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  # ── UUID validation ────────────────────────────────────────────────────────

  defp validate_uuid_opt(nil), do: {:ok, nil}
  defp validate_uuid_opt(""), do: {:ok, nil}
  defp validate_uuid_opt("root"), do: {:ok, nil}
  defp validate_uuid_opt(str) when is_binary(str), do: validate_uuid(str, "uuid")
  defp validate_uuid_opt(_), do: {:error, "invalid uuid"}

  defp validate_uuid(str, field_name) when is_binary(str) do
    if Regex.match?(@uuid_regex, str) do
      {:ok, str}
    else
      {:error, "invalid #{field_name}: must be a UUID"}
    end
  end

  defp validate_uuid(_, field_name), do: {:error, "invalid #{field_name}"}

  defp validate_uuid_list(ids) do
    if Enum.all?(ids, fn id -> is_binary(id) and Regex.match?(@uuid_regex, id) end) do
      :ok
    else
      {:error, "ids must all be UUIDs"}
    end
  end

  defp validate_parent_opt(nil), do: {:ok, nil}
  defp validate_parent_opt(""), do: {:ok, nil}
  defp validate_parent_opt("root"), do: {:ok, :root}

  defp validate_parent_opt(str) when is_binary(str) do
    case validate_uuid(str, "parent_id") do
      {:ok, id} -> {:ok, id}
      err -> err
    end
  end

  # ── Slug ───────────────────────────────────────────────────────────────────

  defp validate_slug(nil), do: {:error, "slug is required"}
  defp validate_slug(""), do: {:error, "slug cannot be empty"}

  defp validate_slug(str) when is_binary(str) do
    if Regex.match?(@slug_regex, str) do
      :ok
    else
      {:error,
       "invalid slug: must be lowercase alphanumeric, dashes, underscores; max 128 chars; must start with letter or digit"}
    end
  end

  defp validate_slug(_), do: {:error, "slug must be a string"}

  # ── Kind & Scope ───────────────────────────────────────────────────────────

  defp validate_kind(nil), do: {:error, "kind is required"}

  defp validate_kind(kind) when is_binary(kind) do
    if kind in @valid_kinds, do: :ok, else: {:error, "invalid kind: #{kind}"}
  end

  defp validate_kind(_), do: {:error, "kind must be a string"}

  defp validate_kind_opt(nil), do: :ok
  defp validate_kind_opt(""), do: :ok
  defp validate_kind_opt(k), do: validate_kind(k)

  defp validate_scope(nil), do: {:error, "scope is required"}

  defp validate_scope(scope) when is_binary(scope) do
    if scope in @valid_scopes, do: :ok, else: {:error, "invalid scope: #{scope}"}
  end

  defp validate_scope(_), do: {:error, "scope must be a string"}

  defp validate_scope_opt(nil), do: :ok
  defp validate_scope_opt(""), do: :ok
  defp validate_scope_opt(s), do: validate_scope(s)

  # ── Bounded limit ──────────────────────────────────────────────────────────

  defp parse_limit(nil), do: @default_limit
  defp parse_limit(""), do: @default_limit
  defp parse_limit(n) when is_integer(n) and n > 0, do: min(n, @max_limit)

  defp parse_limit(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} when n > 0 -> min(n, @max_limit)
      _ -> @default_limit
    end
  end

  defp parse_limit(_), do: @default_limit

  defp parse_archived(nil), do: nil
  defp parse_archived(""), do: nil
  defp parse_archived("true"), do: true
  defp parse_archived("false"), do: false
  defp parse_archived("all"), do: :all
  defp parse_archived(_), do: nil

  # ── Error response ─────────────────────────────────────────────────────────

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end
end
