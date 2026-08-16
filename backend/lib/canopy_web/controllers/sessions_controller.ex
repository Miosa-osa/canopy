defmodule CanopyWeb.SessionsController do
  @moduledoc """
  HTTP API for Canopy session lifecycle management.

  Creates, lists, cancels, and inspects agent sessions. The SSE stream lives in
  `SessionEventsController` — this controller handles the rest.

  Routes:
    GET    /api/v1/sessions                          — list with filters
    GET    /api/v1/sessions/:id                      — session + last N messages
    POST   /api/v1/sessions                          — create + start
    DELETE /api/v1/sessions                          — bulk delete terminal sessions
    DELETE /api/v1/sessions/:id                      — cancel if running, no-op if done
    GET    /api/v1/sessions/:id/chain                — full chain (parent + children)
    GET    /api/v1/sessions/:id/messages             — paginated transcript
    POST   /api/v1/sessions/:id/messages             — write content to session PTY stdin
    POST   /api/v1/sessions/:id/inject               — agent-to-agent PTY stdin injection
    POST   /api/v1/sessions/:id/pause                — pause output forwarding (pty stays alive)
    POST   /api/v1/sessions/:id/resume               — resume output, flush buffer
    POST   /api/v1/sessions/:id/stop                 — kill pty, mark cancelled
    GET    /api/v1/sessions/:id/worktree             — worktree status (path, branch, changes)
    GET    /api/v1/sessions/:id/worktree/diff        — git diff (capped 500KB)
    POST   /api/v1/sessions/:id/worktree/commit      — git add -A && git commit
    POST   /api/v1/sessions/:id/worktree/push        — git push origin <branch>
    POST   /api/v1/sessions/:id/worktree/merge       — merge session branch back to base
    DELETE /api/v1/sessions/:id/worktree             — remove worktree (keep_branch? param)
    POST   /api/v1/sessions/:id/cleanup_worktree     — legacy alias for DELETE /worktree
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.{Runtimes, Sessions}
  alias Canopy.Sessions.{PortsMonitor, WorktreeManager}
  alias Canopy.Hooks.HookEvent
  alias Canopy.Repo
  alias CanopyWeb.Schemas.SessionSchema

  import Ecto.Query, only: [from: 2]

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
      |> put_if(params["kind"], :kind, params["kind"])
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
        # Interactive terminal mode: skip the headless adapter runner. The
        # pty is spawned on channel join by SessionTerminalChannel → PtyBridge.
        # Default for sessions without an initial_prompt.
        interactive? = interactive_session?(params)

        cond do
          stored_conversation?(params) ->
            conn
            |> put_status(:created)
            |> json(session)

          interactive? ->
            {:ok, _running} = Sessions.update_status(session.id, "running")

            Logger.info(
              "[SessionsController] interactive session=#{session.id} — pty on channel join"
            )

            conn
            |> put_status(:created)
            |> json(%{
              session_id: session.id,
              mode: "interactive",
              channel_topic: "terminal:session:#{session.id}"
            })

          true ->
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

  operation :bulk_delete,
    summary: "Bulk delete terminal sessions",
    description:
      "Deletes all sessions in terminal states (ended, failed, cancelled, completed). " <>
        "Accepts optional `status` and `before` (ISO8601) query params to narrow the set. " <>
        "Running sessions are never deleted.",
    parameters: [
      status: [
        in: :query,
        type: :string,
        required: false,
        description: "Limit to a specific terminal status"
      ],
      before: [
        in: :query,
        type: :string,
        required: false,
        description: "ISO8601 datetime — only sessions inserted before this timestamp"
      ]
    ],
    responses: [
      ok:
        {"Deleted count", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{deleted: %OpenApiSpex.Schema{type: :integer}}
         }}
    ]

  @spec bulk_delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def bulk_delete(conn, params) do
    filters =
      []
      |> put_if(params["status"], :status, params["status"])
      |> put_if(params["before"], :before, params["before"])

    {:ok, count} = Sessions.bulk_delete(filters)
    json(conn, %{deleted: count})
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

  operation :create_message,
    summary: "Send a message to a session's PTY stdin",
    description:
      "Writes content to the session's PTY stdin via PtyBridge and persists it as a session message for audit. " <>
        "Appends a newline automatically so the shell processes the command.",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Message params", "application/json", SessionSchema.SendMessageRequest},
    responses: [
      ok: {"Message sent", "application/json", SessionSchema.SendMessageResponse},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec create_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_message(conn, %{"id" => session_id} = params) do
    content = params["content"] || params["message"] || ""

    with {:ok, _session} <- Sessions.get(session_id) do
      Canopy.Sessions.PtyBridge.send_input(session_id, content <> "\n")

      {:ok, msgs} = Sessions.list_messages(session_id)
      next_seq = length(msgs)

      Sessions.add_message(session_id, %{
        kind: "user_input",
        sequence: next_seq,
        emitted_at: DateTime.utc_now(),
        content: %{"text" => content}
      })

      json(conn, %{status: "sent", session_id: session_id})
    end
  end

  operation :inject,
    summary: "Agent-to-agent prompt injection into a session's PTY stdin",
    description:
      "Writes content to PTY stdin on behalf of a source agent. Persists with from_agent metadata for audit trail.",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Inject params", "application/json", SessionSchema.InjectMessageRequest},
    responses: [
      ok: {"Injection sent", "application/json", SessionSchema.InjectMessageResponse},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec inject(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def inject(conn, %{"id" => session_id} = params) do
    content = params["content"] || ""
    from_agent = params["from_agent"] || "unknown"

    with {:ok, _session} <- Sessions.get(session_id) do
      Canopy.Sessions.PtyBridge.send_input(session_id, content <> "\n")

      {:ok, msgs} = Sessions.list_messages(session_id)
      next_seq = length(msgs)

      Sessions.add_message(session_id, %{
        kind: "agent_injection",
        sequence: next_seq,
        emitted_at: DateTime.utc_now(),
        content: %{"text" => content, "from_agent" => from_agent}
      })

      Logger.info(
        "[SessionsController] inject from=#{from_agent} session=#{session_id} bytes=#{byte_size(content)}"
      )

      json(conn, %{status: "injected", session_id: session_id, from_agent: from_agent})
    end
  end

  operation :pause,
    summary: "Pause a session",
    description:
      "Keeps the pty alive but stops forwarding output to subscribers. Output is buffered (max 4KB).",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Session paused", "application/json", SessionSchema.SessionDetail},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec pause(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def pause(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.pause(id) do
      json(conn, %{session: session})
    end
  end

  operation :resume,
    summary: "Resume a paused session",
    description: "Marks session running and flushes buffered output to subscribers.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Session resumed", "application/json", SessionSchema.SessionDetail},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec resume(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def resume(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.resume(id) do
      json(conn, %{session: session})
    end
  end

  operation :stop,
    summary: "Stop a session",
    description: "Kills the pty subprocess and marks the session cancelled.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Session stopped", "application/json", SessionSchema.SessionDetail},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec stop(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stop(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.stop(id) do
      json(conn, %{session: session})
    end
  end

  operation :worktree_status,
    summary: "Get worktree status",
    description:
      "Returns path, branch, base_branch, whether the worktree exists on disk, and changed file count.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok:
        {"Worktree status", "application/json", CanopyWeb.Schemas.WorktreeSchema.WorktreeStatus},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec worktree_status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def worktree_status(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get(id) do
      st = WorktreeManager.status(id, session)
      json(conn, st)
    end
  end

  operation :worktree_diff,
    summary: "Get worktree diff",
    description: "Returns git diff output for the session worktree, capped at 500KB.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Worktree diff", "application/json", CanopyWeb.Schemas.WorktreeSchema.WorktreeDiff},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @max_diff_bytes 512_000

  @spec worktree_diff(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def worktree_diff(conn, %{"id" => id} = params) do
    with {:ok, session} <- Sessions.get(id) do
      if is_nil(session.worktree_path) or not File.dir?(session.worktree_path) do
        json(conn, %{diff: "", truncated: false, message: "No active worktree"})
      else
        file_opt = params["file"]
        max_bytes = parse_int(params["max_bytes"]) || @max_diff_bytes

        opts =
          []
          |> put_if(file_opt, :file, file_opt)
          |> Keyword.put(:max_bytes, max_bytes)

        {stat_output, _} =
          System.cmd("git", ["diff", "--stat", "HEAD"],
            cd: session.worktree_path,
            stderr_to_stdout: true
          )

        case WorktreeManager.diff(id, opts) do
          {:ok, diff_text} ->
            full_size =
              byte_size(
                case System.cmd("git", ["diff", "HEAD"],
                       cd: session.worktree_path,
                       stderr_to_stdout: true
                     ) do
                  {out, _} -> out
                end
              )

            truncated = byte_size(diff_text) < full_size

            json(conn, %{stat: stat_output, diff: diff_text, truncated: truncated})

          {:error, :no_worktree} ->
            json(conn, %{diff: "", truncated: false, message: "No active worktree"})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "diff_failed", message: inspect(reason)})
        end
      end
    end
  end

  operation :worktree_commit,
    summary: "Commit worktree changes",
    description: "Runs git add -A && git commit -m <message> in the session worktree.",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Commit params", "application/json", CanopyWeb.Schemas.WorktreeSchema.CommitRequest},
    responses: [
      ok: {"Commit result", "application/json", CanopyWeb.Schemas.WorktreeSchema.CommitResult},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec worktree_commit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def worktree_commit(conn, %{"id" => id} = params) do
    message = params["message"] || "Session worktree commit"
    files = params["files"]

    with {:ok, session} <- Sessions.get(id) do
      if is_nil(session.worktree_path) or not File.dir?(session.worktree_path) do
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "no_worktree", message: "Session has no active worktree"})
      else
        opts = if is_list(files), do: [files: files], else: []

        case WorktreeManager.commit(id, message, opts) do
          {:ok, sha} ->
            json(conn, %{ok: true, sha: sha, output: "Committed #{String.slice(sha, 0, 8)}"})

          {:error, {:git_error, _code, output}} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "commit_failed", output: output})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "commit_failed", message: inspect(reason)})
        end
      end
    end
  end

  operation :worktree_stage,
    summary: "Stage files in worktree",
    description: "Runs git add -- <files> in the session worktree. Validates paths.",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Stage params", "application/json", CanopyWeb.Schemas.WorktreeSchema.StageRequest},
    responses: [
      ok: {"Stage result", "application/json", CanopyWeb.Schemas.WorktreeSchema.StageResult},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec worktree_stage(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def worktree_stage(conn, %{"id" => id} = params) do
    files = params["files"]

    cond do
      not is_list(files) or Enum.empty?(files) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_request", message: "files must be a non-empty list"})

      not Enum.all?(files, &is_binary/1) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_request", message: "all entries in files must be strings"})

      true ->
        with {:ok, session} <- Sessions.get(id) do
          if is_nil(session.worktree_path) or not File.dir?(session.worktree_path) do
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "no_worktree", message: "Session has no active worktree"})
          else
            case WorktreeManager.stage(id, files) do
              {:ok, staged} ->
                json(conn, %{ok: true, staged: staged})

              {:error, :invalid_path} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "invalid_path", message: "One or more paths are not safe"})

              {:error, {:git_error, _code, output}} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "stage_failed", output: output})

              {:error, reason} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "stage_failed", message: inspect(reason)})
            end
          end
        end
    end
  end

  operation :worktree_discard_hunk,
    summary: "Discard a single hunk from the worktree",
    description:
      "Reverts a single hunk in the worktree by reverse-applying its diff. Validates file_path is inside worktree.",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Discard params", "application/json", CanopyWeb.Schemas.WorktreeSchema.DiscardHunkRequest},
    responses: [
      ok:
        {"Discard result", "application/json", CanopyWeb.Schemas.WorktreeSchema.DiscardHunkResult},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec worktree_discard_hunk(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def worktree_discard_hunk(conn, %{"id" => id} = params) do
    file_path = params["file_path"]
    hunk_header = params["hunk_header"]
    hunk_content = params["hunk_content"]

    cond do
      not is_binary(file_path) or file_path == "" ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_request", message: "file_path is required"})

      not is_binary(hunk_header) or not is_binary(hunk_content) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "invalid_request",
          message: "hunk_header and hunk_content must be strings"
        })

      true ->
        with {:ok, session} <- Sessions.get(id) do
          if is_nil(session.worktree_path) or not File.dir?(session.worktree_path) do
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "no_worktree", message: "Session has no active worktree"})
          else
            case WorktreeManager.discard_hunk(id, file_path, hunk_header, hunk_content) do
              :ok ->
                json(conn, %{ok: true})

              {:error, :invalid_path} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "invalid_path", message: "file_path is not safe"})

              {:error, :invalid_hunk_header} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{
                  error: "invalid_hunk_header",
                  message: "hunk_header must start with '@@ '"
                })

              {:error, {:git_error, _code, output}} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "discard_failed", output: output})

              {:error, reason} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "discard_failed", message: inspect(reason)})
            end
          end
        end
    end
  end

  operation :worktree_push,
    summary: "Push worktree branch",
    description:
      "Pushes the session branch to the given remote (default: origin). Never force-pushes.",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Push params", "application/json", CanopyWeb.Schemas.WorktreeSchema.PushRequest},
    responses: [
      ok: {"Push result", "application/json", CanopyWeb.Schemas.WorktreeSchema.PushResult},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec worktree_push(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def worktree_push(conn, %{"id" => id} = params) do
    remote = params["remote"] || "origin"

    with {:ok, session} <- Sessions.get(id) do
      if is_nil(session.worktree_path) or not File.dir?(session.worktree_path) do
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "no_worktree", message: "Session has no active worktree"})
      else
        case WorktreeManager.push(id, remote) do
          {:ok, ref} ->
            json(conn, %{ok: true, ref: ref})

          {:error, {:git_error, _code, output}} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "push_failed", output: output})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "push_failed", message: inspect(reason)})
        end
      end
    end
  end

  operation :worktree_merge,
    summary: "Merge session branch to base",
    description:
      "Merges the session branch back into the base branch (main/master). Returns conflict file list on conflict.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Merge result", "application/json", CanopyWeb.Schemas.WorktreeSchema.MergeResult},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Conflict or error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec worktree_merge(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def worktree_merge(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get(id) do
      if is_nil(session.worktree_path) or not File.dir?(session.worktree_path) do
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "no_worktree", message: "Session has no active worktree"})
      else
        case WorktreeManager.merge_to_base(id) do
          {:ok, base_branch} ->
            json(conn, %{ok: true, base_branch: base_branch})

          {:error, {:conflict, files}} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "conflict", conflict_files: files})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "merge_failed", message: inspect(reason)})
        end
      end
    end
  end

  operation :worktree_cleanup,
    summary: "Remove session worktree (DELETE)",
    description:
      "Removes the git worktree from disk and clears worktree fields on the session. Set keep_branch=true to preserve the branch.",
    parameters: [
      id: [in: :path, type: :string, required: true],
      keep_branch: [in: :query, type: :boolean, required: false]
    ],
    responses: [
      ok: {"Cleanup result", "application/json", CanopyWeb.Schemas.WorktreeSchema.CleanupResult},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec worktree_cleanup(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def worktree_cleanup(conn, %{"id" => id} = params) do
    keep_branch = params["keep_branch"] in [true, "true", "1"]

    with {:ok, session} <- Sessions.cleanup_worktree(id, keep_branch: keep_branch) do
      json(conn, %{ok: true, session: session})
    end
  end

  operation :cleanup_worktree,
    summary: "Remove session worktree",
    description: "Removes the git worktree from disk and clears worktree fields on the session.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Cleanup result", "application/json", CanopyWeb.Schemas.WorktreeSchema.CleanupResult},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec cleanup_worktree(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def cleanup_worktree(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.cleanup_worktree(id) do
      json(conn, %{ok: true, session: session})
    end
  end

  operation :pr_info,
    summary: "Get PR info for a session's branch",
    description: """
    Looks up an open GitHub PR for the session's worktree branch on public repos.
    Returns {exists: false} when no worktree, no remote, or no open PR is found.
    Auth-free v1 — public repos only.
    """,
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"PR info", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec pr_info(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def pr_info(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get(id) do
      result = resolve_pr_info(session)
      json(conn, result)
    end
  end

  defp resolve_pr_info(%{worktree_path: nil}), do: %{exists: false, reason: "no_worktree"}
  defp resolve_pr_info(%{worktree_branch: nil}), do: %{exists: false, reason: "no_branch"}

  defp resolve_pr_info(%{worktree_path: path, worktree_branch: branch}) do
    with {:ok, remote_url} <- git_remote_url(path),
         {:ok, {owner, repo}} <- parse_github_owner_repo(remote_url),
         {:ok, pr} <- fetch_github_pr(owner, repo, branch) do
      %{
        exists: true,
        number: pr["number"],
        title: pr["title"],
        url: pr["html_url"],
        state: pr["state"]
      }
    else
      _err -> %{exists: false, reason: "no_pr"}
    end
  end

  defp git_remote_url(path) do
    case System.cmd("git", ["-C", path, "config", "--get", "remote.origin.url"],
           stderr_to_stdout: false
         ) do
      {url, 0} -> {:ok, String.trim(url)}
      _other -> {:error, :no_remote}
    end
  end

  defp parse_github_owner_repo(url) do
    # Handles https://github.com/owner/repo.git and git@github.com:owner/repo.git
    patterns = [
      ~r{github\.com[:/](?<owner>[^/]+)/(?<repo>[^/\s\.]+)(?:\.git)?$}
    ]

    Enum.find_value(patterns, {:error, :not_github}, fn pat ->
      case Regex.named_captures(pat, url) do
        %{"owner" => owner, "repo" => repo} -> {:ok, {owner, repo}}
        _ -> nil
      end
    end)
  end

  defp fetch_github_pr(owner, repo, branch) do
    url =
      "https://api.github.com/repos/#{owner}/#{repo}/pulls?head=#{owner}:#{branch}&state=open&per_page=1"

    headers = [{"User-Agent", "Canopy/1.0"}, {"Accept", "application/vnd.github+json"}]

    case :httpc.request(
           :get,
           {String.to_charlist(url),
            Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)},
           [],
           []
         ) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        case Jason.decode(List.to_string(body)) do
          {:ok, [pr | _]} -> {:ok, pr}
          {:ok, []} -> {:error, :no_open_pr}
          _ -> {:error, :decode_error}
        end

      _other ->
        {:error, :request_failed}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp session_attrs(params) do
    %{
      runtime_type: params["runtime_type"],
      kind: params["kind"] || "terminal",
      cwd: params["cwd"] || System.tmp_dir!(),
      model_id: params["model_id"],
      prompt: params["prompt"],
      agent_slug: params["agent_slug"],
      workspace_slug: params["workspace_slug"],
      parent_session_id: params["parent_session_id"]
    }
  end

  defp interactive_session?(params) do
    case params["interactive"] do
      false -> false
      "false" -> false
      0 -> false
      "0" -> false
      true -> true
      "true" -> true
      1 -> true
      "1" -> true
      _ -> is_nil(params["initial_prompt"]) or params["initial_prompt"] == ""
    end
  end

  defp stored_conversation?(params) do
    params["kind"] == "agent_conversation" and
      params["interactive"] in [false, "false", 0, "0"]
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:id/ports
  # ---------------------------------------------------------------------------

  operation :ports,
    summary: "List forwarded ports for a session",
    description:
      "Returns listening TCP/UDP ports held by the session's pty process and its descendants.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Port list", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec ports(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def ports(conn, %{"id" => id}) do
    with {:ok, _session} <- Sessions.get(id) do
      case PortsMonitor.scan(id) do
        {:ok, ports} -> json(conn, %{data: ports})
        {:error, _} -> json(conn, %{data: []})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sessions/:id/lifecycle
  # ---------------------------------------------------------------------------

  operation :lifecycle,
    summary: "List lifecycle hook events for a session",
    description: "Returns hook_events linked to this Canopy session, newest first.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Lifecycle events", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec lifecycle(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def lifecycle(conn, %{"id" => id}) do
    with {:ok, _session} <- Sessions.get(id) do
      events =
        from(e in HookEvent,
          where: e.canopy_session_id == ^id,
          order_by: [desc: e.inserted_at],
          limit: 100
        )
        |> Repo.all()

      json(conn, %{data: events})
    end
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
