defmodule CanopyWeb.WorkspaceInitController do
  @moduledoc """
  HTTP API for workspace initialisation jobs.

  Routes:
    POST   /api/v1/workspaces/:slug/init                — start init job → 201 { job_id }
    GET    /api/v1/workspaces/:slug/init/:job_id        — get job state
    POST   /api/v1/workspaces/:slug/init/:job_id/cancel — cancel job
    GET    /api/v1/workspaces/:slug/init/:job_id/stream — SSE event stream
    POST   /api/v1/workspaces/:slug/setup              — ad-hoc run setup_script
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Workspaces.Init
  alias Canopy.Workspaces

  require Logger

  @heartbeat_ms 15_000
  @pubsub Canopy.PubSub

  action_fallback CanopyWeb.FallbackController

  tags ["workspaces"]

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:slug/init
  # ---------------------------------------------------------------------------

  operation :start,
    summary: "Start workspace init",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [
      created: {"Init job created", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Workspace not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec start(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def start(conn, %{"slug" => slug} = params) do
    opts = build_opts(params)

    case Init.start(slug, opts) do
      {:ok, job} ->
        conn
        |> put_status(:created)
        |> json(%{job_id: job.id, stream_url: stream_url(slug, job.id)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Workspace #{slug} does not exist."})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:slug/init/:job_id
  # ---------------------------------------------------------------------------

  operation :show,
    summary: "Get init job state",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      job_id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Init job", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"job_id" => job_id}) do
    case Init.get(job_id) do
      {:ok, job} ->
        json(conn, %{data: job})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Job #{job_id} does not exist."})
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:slug/init/:job_id/cancel
  # ---------------------------------------------------------------------------

  operation :cancel,
    summary: "Cancel init job",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      job_id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Cancelled", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec cancel(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def cancel(conn, %{"job_id" => job_id}) do
    case Init.cancel(job_id) do
      {:ok, job} ->
        json(conn, %{data: job})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Job #{job_id} does not exist."})

      {:error, :already_terminal} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "already_terminal", message: "Job is already in a terminal state."})
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/workspaces/:slug/init/:job_id/stream  (SSE)
  # ---------------------------------------------------------------------------

  operation :stream,
    summary: "SSE stream for init job progress",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      job_id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"SSE stream", "text/event-stream", %OpenApiSpex.Schema{type: :string}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec stream(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stream(conn, %{"job_id" => job_id}) do
    case Init.get(job_id) do
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found", message: "Job #{job_id} does not exist."})

      {:ok, job} ->
        conn = init_sse(conn)

        if job.status in ["succeeded", "failed", "cancelled"] do
          # Replay terminal state immediately
          conn = chunk_snapshot(conn, job)
          chunk_terminal_event(conn, job)
        else
          Phoenix.PubSub.subscribe(@pubsub, "workspace_init:job:#{job_id}")
          # Send current snapshot so client is up-to-date
          conn = chunk_snapshot(conn, job)
          conn = sse_loop(conn, job_id)
          Phoenix.PubSub.unsubscribe(@pubsub, "workspace_init:job:#{job_id}")
          conn
        end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:slug/setup  (ad-hoc setup script run)
  # ---------------------------------------------------------------------------

  operation :run_setup,
    summary: "Run workspace setup script ad-hoc",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [
      created: {"Setup job started", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity:
        {"No setup script", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec run_setup(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def run_setup(conn, %{"slug" => slug}) do
    with {:ok, workspace} <- Workspaces.get_by_slug(slug) do
      if is_nil(workspace.setup_script) or workspace.setup_script == "" do
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "no_setup_script", message: "Workspace has no setup_script configured."})
      else
        case Init.start(slug) do
          {:ok, job} ->
            conn
            |> put_status(:created)
            |> json(%{job_id: job.id, stream_url: stream_url(slug, job.id)})

          {:error, changeset} ->
            {:error, changeset}
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/workspaces/:slug/init/detect
  # ---------------------------------------------------------------------------

  operation :detect,
    summary: "Detect setup script from lockfiles",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Detected script", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @lockfile_presets [
    {"bun.lockb", "bun install"},
    {"bun.lock", "bun install"},
    {"pnpm-lock.yaml", "pnpm install"},
    {"package-lock.json", "npm install"},
    {"yarn.lock", "yarn install"},
    {"mix.exs", "mix deps.get"},
    {"uv.lock", "uv sync"},
    {"Pipfile.lock", "pip install -r requirements.txt"},
    {"requirements.txt", "pip install -r requirements.txt"},
    {"Cargo.toml", "cargo fetch"},
    {"go.mod", "go mod download"},
    {"Gemfile.lock", "bundle install"}
  ]

  @spec detect(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def detect(conn, %{"slug" => slug}) do
    with {:ok, workspace} <- Workspaces.get_by_slug(slug) do
      root = workspace.root_path

      {lockfile, suggested_script} =
        if root && File.dir?(root) do
          Enum.find_value(@lockfile_presets, {nil, nil}, fn {file, cmd} ->
            if File.exists?(Path.join(root, file)) do
              {file, cmd}
            end
          end)
        else
          {nil, nil}
        end

      json(conn, %{
        detected: suggested_script != nil,
        lockfile: lockfile,
        suggested_script: suggested_script
      })
    end
  end

  # ---------------------------------------------------------------------------
  # SSE loop — mirrors SessionEventsController pattern
  # ---------------------------------------------------------------------------

  defp sse_loop(conn, job_id) do
    receive do
      {:step, step_name} ->
        conn = chunk_event(conn, "step", %{step: step_name})
        sse_loop(conn, job_id)

      {:progress, pct} ->
        conn = chunk_event(conn, "progress", %{progress_pct: pct})
        sse_loop(conn, job_id)

      {:output, text} ->
        conn = chunk_event(conn, "output", %{text: text})
        sse_loop(conn, job_id)

      {:done, job} ->
        chunk_event(conn, "done", %{job: job})

      {:error, reason} ->
        chunk_event(conn, "error", %{error: reason})

      {:cancelled, job} ->
        chunk_event(conn, "cancelled", %{job: job})

      {:EXIT, _pid, _reason} ->
        conn
    after
      @heartbeat_ms ->
        case Plug.Conn.chunk(conn, ": keepalive\n\n") do
          {:ok, conn} ->
            # Re-check job status in case we missed the terminal broadcast
            case Init.get(job_id) do
              {:ok, %{status: s} = job} when s in ["succeeded", "failed", "cancelled"] ->
                chunk_terminal_event(conn, job)

              _ ->
                sse_loop(conn, job_id)
            end

          {:error, _} ->
            conn
        end
    end
  end

  # ---------------------------------------------------------------------------
  # SSE helpers
  # ---------------------------------------------------------------------------

  defp init_sse(conn) do
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("x-accel-buffering", "no")
    |> send_chunked(200)
  end

  defp chunk_snapshot(conn, job) do
    chunk_event(conn, "progress", %{
      progress_pct: job.progress_pct,
      current_step: job.current_step,
      output: job.output,
      status: job.status
    })
  end

  defp chunk_terminal_event(conn, %{status: "succeeded"} = job),
    do: chunk_event(conn, "done", %{job: job})

  defp chunk_terminal_event(conn, %{status: "failed"} = job),
    do: chunk_event(conn, "error", %{error: job.error, job: job})

  defp chunk_terminal_event(conn, %{status: "cancelled"} = job),
    do: chunk_event(conn, "cancelled", %{job: job})

  defp chunk_terminal_event(conn, _job), do: conn

  defp chunk_event(conn, event_name, payload) do
    data = Jason.encode!(payload)
    line = "event: #{event_name}\ndata: #{data}\n\n"

    case Plug.Conn.chunk(conn, line) do
      {:ok, conn} ->
        conn

      {:error, reason} ->
        Logger.debug(
          "[InitSSE] chunk failed job=#{conn.params["job_id"]} reason=#{inspect(reason)}"
        )

        conn
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp build_opts(params) do
    case params["clone_url"] do
      nil -> []
      "" -> []
      url -> [clone_url: url]
    end
  end

  defp stream_url(slug, job_id) do
    "/api/v1/workspaces/#{slug}/init/#{job_id}/stream"
  end
end
