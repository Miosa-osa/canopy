defmodule CanopyWeb.BlocksController do
  @moduledoc """
  HTTP API for the **Block** primitive.

  Routes (registered in `router.ex`):

      GET  /api/v1/sessions/:session_id/blocks            — list blocks
      GET  /api/v1/sessions/:session_id/blocks/search     — search by tag/status/kind/q
      GET  /api/v1/sessions/:session_id/blocks/:id        — show one block

  Validation matches `AnalyticsController` exactly: UUID regex, limit cap
  1000, tag slug regex, optional ISO-8601 timestamp parsing, and a single
  400 error helper for all validation failures.
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Sessions.Blocks
  alias CanopyWeb.Schemas.BlocksSchema

  action_fallback CanopyWeb.FallbackController

  tags ["blocks"]

  @max_limit 1000
  @default_limit 200
  @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  @tag_regex ~r/\A[a-z0-9][a-z0-9_-]{0,63}\z/

  @kinds ~w(command agent_message tool_call tool_result approval diff system_event error)
  @statuses ~w(running completed failed cancelled pending_approval)

  # ---------------------------------------------------------------------------
  # Index
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List blocks for a session",
    description:
      "Returns blocks ordered by sequence ascending. Filter by kind, status, parent_block_id, or since.",
    parameters: [
      session_id: [in: :path, type: :string, required: true],
      kind: [in: :query, type: :string, required: false],
      status: [in: :query, type: :string, required: false],
      parent_block_id: [in: :query, type: :string, required: false],
      since: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Block list", "application/json", BlocksSchema.BlockList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"session_id" => session_id} = params) do
    with {:ok, session_id} <- validate_uuid(session_id, "session_id"),
         :ok <- validate_kind_opt(params["kind"]),
         :ok <- validate_status_opt(params["status"]),
         {:ok, parent_block_id} <- validate_uuid_opt(params["parent_block_id"]),
         {:ok, since} <- parse_dt_opt(params["since"]) do
      opts =
        [session_id: session_id]
        |> maybe_put(:kind, params["kind"])
        |> maybe_put(:status, params["status"])
        |> maybe_put(:parent_block_id, parent_block_id)
        |> maybe_put(:since, since)
        |> maybe_put(:limit, parse_limit(params["limit"]))

      blocks = Blocks.list(opts)
      json(conn, %{session_id: session_id, count: length(blocks), data: blocks})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Show
  # ---------------------------------------------------------------------------

  operation :show,
    summary: "Show a single block",
    parameters: [
      session_id: [in: :path, type: :string, required: true],
      id: [in: :path, type: :string, required: true]
    ],
    responses: [ok: {"Block", "application/json", BlocksSchema.Block}]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"session_id" => session_id, "id" => id}) do
    with {:ok, session_id} <- validate_uuid(session_id, "session_id"),
         {:ok, id} <- validate_uuid(id, "id") do
      case Blocks.get(id) do
        nil ->
          not_found(conn, "block_not_found", id)

        %{session_id: ^session_id} = block ->
          json(conn, block)

        _mismatch ->
          # Block exists but belongs to a different session — surface as 404
          # to avoid leaking cross-session existence.
          not_found(conn, "block_not_found", id)
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  operation :search,
    summary: "Search blocks within a session",
    description: "Faceted + free-text search. Filters: kind, status, tag, q (substring).",
    parameters: [
      session_id: [in: :path, type: :string, required: true],
      q: [in: :query, type: :string, required: false],
      kind: [in: :query, type: :string, required: false],
      status: [in: :query, type: :string, required: false],
      tag: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Search result", "application/json", BlocksSchema.BlockSearchResult}]

  @spec search(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def search(conn, %{"session_id" => session_id} = params) do
    with {:ok, session_id} <- validate_uuid(session_id, "session_id"),
         :ok <- validate_kind_opt(params["kind"]),
         :ok <- validate_status_opt(params["status"]),
         :ok <- validate_tag_opt(params["tag"]) do
      opts =
        [session_id: session_id]
        |> maybe_put(:q, params["q"])
        |> maybe_put(:kind, params["kind"])
        |> maybe_put(:status, params["status"])
        |> maybe_put(:tag, params["tag"])
        |> maybe_put(:limit, parse_limit(params["limit"]))

      blocks = Blocks.search(opts)
      json(conn, %{session_id: session_id, count: length(blocks), data: blocks})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  # ── UUID validation ────────────────────────────────────────────────────────

  defp validate_uuid_opt(nil), do: {:ok, nil}
  defp validate_uuid_opt(""), do: {:ok, nil}
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

  # ── Kind / Status enum validation ──────────────────────────────────────────

  defp validate_kind_opt(nil), do: :ok
  defp validate_kind_opt(""), do: :ok

  defp validate_kind_opt(k) when is_binary(k) do
    if k in @kinds, do: :ok, else: {:error, "invalid kind: #{k}"}
  end

  defp validate_kind_opt(_), do: {:error, "kind must be a string"}

  defp validate_status_opt(nil), do: :ok
  defp validate_status_opt(""), do: :ok

  defp validate_status_opt(s) when is_binary(s) do
    if s in @statuses, do: :ok, else: {:error, "invalid status: #{s}"}
  end

  defp validate_status_opt(_), do: {:error, "status must be a string"}

  # ── Tag validation ─────────────────────────────────────────────────────────

  defp validate_tag_opt(nil), do: :ok
  defp validate_tag_opt(""), do: :ok

  defp validate_tag_opt(t) when is_binary(t) do
    if Regex.match?(@tag_regex, t) do
      :ok
    else
      {:error,
       "invalid tag: must be lowercase alphanumeric, dashes, underscores; max 64 chars; must start with letter or digit"}
    end
  end

  defp validate_tag_opt(_), do: {:error, "tag must be a string"}

  # ── Optional ISO-8601 timestamp parsing ────────────────────────────────────

  defp parse_dt_opt(nil), do: {:ok, nil}
  defp parse_dt_opt(""), do: {:ok, nil}

  defp parse_dt_opt(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> {:error, "invalid timestamp: #{str}"}
    end
  end

  defp parse_dt_opt(_), do: {:error, "invalid timestamp"}

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

  # ── Error responses ────────────────────────────────────────────────────────

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end

  defp not_found(conn, error, id) do
    conn
    |> put_status(:not_found)
    |> json(%{error: error, id: id})
  end
end
