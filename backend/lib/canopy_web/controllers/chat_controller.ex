defmodule CanopyWeb.ChatController do
  @moduledoc """
  HTTP API for Canopy chat threads.

  Chat threads are a thin coordination layer on top of Sessions. A thread groups
  one or more Sessions by conversational context. Message storage lives entirely
  in `SessionMessage` — this controller never duplicates content.

  Routes:
    GET    /api/v1/chat/threads                   — list with filters
    POST   /api/v1/chat/threads                   — create thread + initial session
    GET    /api/v1/chat/threads/:id               — thread detail with full transcript
    POST   /api/v1/chat/threads/:id/continue      — new message turn
    PATCH  /api/v1/chat/threads/:id               — rename / pin / archive
    DELETE /api/v1/chat/threads/:id               — hard delete (sessions preserved)
    GET    /api/v1/chat/threads/:id/export        — markdown export
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Chat
  alias CanopyWeb.Schemas.ChatSchema

  action_fallback CanopyWeb.FallbackController

  tags ["chat"]

  operation :index,
    summary: "List chat threads",
    description:
      "Returns threads ordered by last activity. Filters: user_id, agent_slug, archived, pinned.",
    parameters: [
      user_id: [in: :query, type: :string, required: false],
      agent_slug: [in: :query, type: :string, required: false],
      archived: [in: :query, type: :boolean, required: false],
      pinned: [in: :query, type: :boolean, required: false]
    ],
    responses: [
      ok: {"Thread list", "application/json", ChatSchema.ThreadList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters = %{
      user_id: params["user_id"],
      agent_slug: params["agent_slug"],
      archived: parse_bool(params["archived"]),
      pinned: parse_bool(params["pinned"])
    }

    threads = Chat.list_threads(filters)
    json(conn, %{data: threads})
  end

  operation :create,
    summary: "Create a chat thread",
    description:
      "Creates a thread and an initial Session. Governance and budget gates fire on session create.",
    request_body: {"Thread creation params", "application/json", ChatSchema.CreateThreadRequest},
    responses: [
      created: {"Thread created", "application/json", ChatSchema.CreateThreadResponse},
      unprocessable_entity:
        {"Validation error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    attrs = %{
      title: params["title"],
      user_id: conn.assigns[:current_user] && conn.assigns.current_user.id,
      agent_slug: params["agent_slug"],
      runtime_type: params["runtime_type"],
      model_id: params["model_id"],
      workspace_slug: params["workspace_slug"],
      prompt: params["prompt"]
    }

    case Chat.create_thread(attrs) do
      {:ok, thread} ->
        sse_url = "/api/v1/sessions/#{thread.last_session_id}/events"

        conn
        |> put_status(:created)
        |> json(%{
          thread: thread,
          session_id: thread.last_session_id,
          sse_url: sse_url
        })

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

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation :show,
    summary: "Get thread detail",
    description: "Returns the thread with its full concatenated transcript across all sessions.",
    parameters: [
      id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Thread detail", "application/json", ChatSchema.ThreadDetail},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, thread} <- Chat.get_thread(id),
         {:ok, messages} <- Chat.thread_transcript(id) do
      json(conn, %{thread: thread, messages: messages})
    end
  end

  operation :continue,
    summary: "Continue a chat thread",
    description:
      "Creates a new Session turn within the thread. Returns session_id and SSE URL for streaming.",
    parameters: [
      id: [in: :path, type: :string, required: true]
    ],
    request_body: {"Continue request", "application/json", ChatSchema.ContinueThreadRequest},
    responses: [
      created: {"Continuation started", "application/json", ChatSchema.ContinueThreadResponse},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Validation error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec continue(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def continue(conn, %{"id" => id} = params) do
    prompt = params["prompt"] || ""

    case Chat.continue_thread(id, prompt) do
      {:ok, %{session: session}} ->
        sse_url = "/api/v1/sessions/#{session.id}/events"

        conn
        |> put_status(:created)
        |> json(%{session_id: session.id, sse_url: sse_url})

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

      {:error, reason} ->
        {:error, reason}
    end
  end

  operation :update,
    summary: "Update thread metadata",
    description: "Rename the thread, pin/unpin, or archive/unarchive.",
    parameters: [
      id: [in: :path, type: :string, required: true]
    ],
    request_body: {"Update params", "application/json", ChatSchema.UpdateThreadRequest},
    responses: [
      ok: {"Thread updated", "application/json", ChatSchema.Thread},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    with {:ok, thread} <- apply_updates(id, params) do
      json(conn, thread)
    end
  end

  operation :delete,
    summary: "Delete a chat thread",
    description: "Hard-deletes the thread and junction rows. Underlying Sessions are preserved.",
    parameters: [
      id: [in: :path, type: :string, required: true]
    ],
    responses: [
      no_content: "Thread deleted",
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with :ok <- Chat.delete_thread(id) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :export,
    summary: "Export thread as markdown",
    description: "Returns the full thread transcript formatted as GitHub-Flavored Markdown.",
    parameters: [
      id: [in: :path, type: :string, required: true],
      include_thinking: [in: :query, type: :boolean, required: false]
    ],
    responses: [
      ok: {"Markdown export", "text/markdown", %OpenApiSpex.Schema{type: :string}},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec export(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def export(conn, %{"id" => id} = params) do
    opts = [include_thinking: parse_bool(params["include_thinking"]) == true]

    with {:ok, markdown} <- Chat.export_thread(id, opts) do
      conn
      |> put_resp_content_type("text/markdown; charset=utf-8")
      |> send_resp(200, markdown)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec apply_updates(binary(), map()) ::
          {:ok, Canopy.Chat.Thread.t()} | {:error, :not_found | Ecto.Changeset.t()}
  defp apply_updates(id, params) do
    with {:ok, thread} <- handle_archive(id, params),
         {:ok, thread} <- handle_pin(thread.id, params),
         {:ok, thread} <- handle_rename(thread.id, params) do
      {:ok, thread}
    end
  end

  defp handle_archive(id, %{"archived" => true}), do: Chat.archive_thread(id)
  defp handle_archive(id, %{"archived" => false}), do: Chat.unarchive_thread(id)

  defp handle_archive(id, _params) do
    case Chat.get_thread(id) do
      {:ok, thread} -> {:ok, thread}
      err -> err
    end
  end

  defp handle_pin(id, %{"pinned" => true}), do: Chat.pin_thread(id)
  defp handle_pin(id, %{"pinned" => false}), do: Chat.unpin_thread(id)

  defp handle_pin(id, _params) do
    case Canopy.Repo.get(Canopy.Chat.Thread, id) do
      nil -> {:error, :not_found}
      thread -> {:ok, thread}
    end
  end

  defp handle_rename(id, %{"title" => title}) when is_binary(title),
    do: Chat.rename_thread(id, title)

  defp handle_rename(id, _params) do
    case Canopy.Repo.get(Canopy.Chat.Thread, id) do
      nil -> {:error, :not_found}
      thread -> {:ok, thread}
    end
  end

  @spec parse_bool(term()) :: boolean() | nil
  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(true), do: true
  defp parse_bool(false), do: false
  defp parse_bool(_), do: nil
end
