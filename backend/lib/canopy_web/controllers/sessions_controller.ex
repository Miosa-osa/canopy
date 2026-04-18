defmodule CanopyWeb.SessionsController do
  @moduledoc """
  HTTP API for Canopy session lifecycle management.

  Creates, lists, cancels, and inspects agent sessions. The SSE stream lives in
  `SessionEventsController` — this controller handles the rest.

  Routes:
    GET    /api/v1/sessions                  — list with filters
    GET    /api/v1/sessions/:id              — session + last N messages
    POST   /api/v1/sessions                  — create + start
    DELETE /api/v1/sessions/:id              — cancel if running, no-op if done
    GET    /api/v1/sessions/:id/chain        — full chain (parent + children)
    GET    /api/v1/sessions/:id/messages     — paginated transcript
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.{Runtimes, Sessions}
  alias CanopyWeb.Schemas.SessionSchema

  require Logger

  action_fallback CanopyWeb.FallbackController

  tags ["sessions"]

  operation :index,
    summary: "List sessions",
    description:
      "Returns sessions with optional filters: runtime, status, workspace, limit, cursor.",
    parameters: [
      runtime: [in: :query, type: :string, required: false],
      status: [in: :query, type: :string, required: false],
      workspace: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false],
      cursor: [in: :query, type: :string, required: false]
    ],
    responses: [
      ok: {"Session list", "application/json", SessionSchema.SessionList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    opts =
      []
      |> put_if(params["runtime"], :runtime, params["runtime"])
      |> put_if(params["status"], :status, params["status"])
      |> put_if(params["workspace"], :workspace, params["workspace"])
      |> put_if(params["cursor"], :cursor, params["cursor"])
      |> put_if(params["limit"], :limit, parse_limit(params["limit"]))

    {:ok, sessions} = Sessions.list(opts)
    json(conn, %{data: sessions})
  end

  operation :show,
    summary: "Get session detail",
    description: "Returns the session and its last 50 messages.",
    parameters: [
      id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Session detail", "application/json", SessionSchema.SessionDetail},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get(id),
         {:ok, messages} <- Sessions.list_messages(id, limit: 50) do
      json(conn, %{session: session, messages: messages})
    end
  end

  operation :create,
    summary: "Create and start a session",
    description: "Creates a session record, resolves the adapter, and starts execution.",
    request_body:
      {"Session creation params", "application/json", SessionSchema.CreateSessionRequest},
    responses: [
      created: {"Session created", "application/json", SessionSchema.CreateSessionResponse},
      unprocessable_entity:
        {"Validation error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    runtime_type = params["runtime_type"]

    case Sessions.create(session_attrs(params)) do
      {:error, {:governance_blocked, rule}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "governance_blocked",
          rule: %{id: rule.id, name: rule.name},
          message: "Session blocked by governance rule"
        })

      {:error, {:budget_blocked, budget, spent}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "budget_blocked",
          budget_id: budget.id,
          spent_usd: Decimal.to_string(spent),
          limit_usd: Decimal.to_string(budget.limit_usd),
          message: "Session blocked by budget limit"
        })

      {:ok, %{status: "pending_approval"} = session} ->
        # Governance requires approval — session stored, no adapter spawned.
        Logger.info("[SessionsController] pending_approval session=#{session.id}")

        conn
        |> put_status(:accepted)
        |> json(%{
          session_id: session.id,
          status: "pending_approval",
          message: "Session is awaiting governance approval"
        })

      {:ok, session} ->
        with {:adapter, {:ok, adapter}} <- {:adapter, Runtimes.lookup_adapter(runtime_type)},
             {:execute, {:ok, session_ref}} <-
               {:execute, adapter.execute(build_context(session, params))} do
          {:ok, _running} = Sessions.update_status(session.id, "running")

          sse_url = "/api/v1/sessions/#{session.id}/events"

          Logger.info(
            "[SessionsController] started session=#{session.id} pid=#{inspect(session_ref[:pid])}"
          )

          conn
          |> put_status(:created)
          |> json(%{session_id: session.id, sse_url: sse_url})
        else
          {:adapter, {:error, :not_found}} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "unknown_runtime",
              message: "Runtime type '#{runtime_type}' is not registered."
            })

          {:execute, {:error, reason}} ->
            Logger.error("[SessionsController] adapter.execute failed: #{inspect(reason)}")

            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "execution_failed", message: inspect(reason)})
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation :delete,
    summary: "Cancel a session",
    description: "Cancels a running session. Returns 204 if already completed or cancelled.",
    parameters: [
      id: [in: :path, type: :string, required: true]
    ],
    responses: [
      no_content: "Session cancelled or already done",
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get(id) do
      if session.status == "running" do
        {:ok, _cancelled} = Sessions.update_status(id, "cancelled")
      end

      send_resp(conn, :no_content, "")
    end
  end

  operation :chain,
    summary: "Get session chain",
    description: "Returns the session with all ancestors and direct children.",
    parameters: [
      id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Session chain", "application/json", SessionSchema.SessionChain},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec chain(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def chain(conn, %{"id" => id}) do
    with {:ok, chain} <- Sessions.get_chain(id) do
      json(conn, chain)
    end
  end

  operation :messages,
    summary: "List session messages",
    description: "Returns paginated transcript messages for a session.",
    parameters: [
      id: [in: :path, type: :string, required: true],
      from: [
        in: :query,
        type: :integer,
        required: false,
        description: "Start from sequence number"
      ],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"Message list", "application/json", SessionSchema.MessageList},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec messages(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def messages(conn, %{"id" => id} = params) do
    with {:ok, _session} <- Sessions.get(id) do
      opts =
        []
        |> put_if(params["from"], :from, parse_int(params["from"]))
        |> put_if(params["limit"], :limit, parse_int(params["limit"]))

      {:ok, msgs} = Sessions.list_messages(id, opts)
      json(conn, %{data: msgs})
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp session_attrs(params) do
    %{
      runtime_type: params["runtime_type"],
      cwd: params["cwd"] || System.tmp_dir!(),
      model_id: params["model_id"],
      prompt: params["prompt"],
      agent_slug: params["agent_slug"],
      workspace_slug: params["workspace_slug"],
      parent_session_id: params["parent_session_id"]
    }
  end

  defp build_context(session, params) do
    %{
      "session_id" => session.id,
      "runtime_type" => session.runtime_type,
      "cwd" => session.cwd,
      "prompt" => session.prompt || "",
      "model_id" => session.model_id,
      "agent_slug" => session.agent_slug,
      "workspace_slug" => session.workspace_slug
    }
    |> Map.merge(Map.take(params, ["agents_md", "skills"]))
  end

  defp put_if(opts, nil, _key, _value), do: opts
  defp put_if(opts, "", _key, _value), do: opts
  defp put_if(opts, _truthy, key, value), do: Keyword.put(opts, key, value)

  defp parse_limit(nil), do: 50
  defp parse_limit(val), do: parse_int(val) || 50

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} -> n
      _other -> nil
    end
  end
end
