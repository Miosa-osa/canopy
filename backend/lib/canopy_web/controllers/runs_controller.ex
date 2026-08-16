defmodule CanopyWeb.RunsController do
  @moduledoc """
  HTTP API for the runs ledger.

  Routes:
    GET    /api/v1/runs                 — list with filters
    POST   /api/v1/runs                 — create (status=queued)
    GET    /api/v1/runs/:id             — get by uuid or short_id
    PATCH  /api/v1/runs/:id             — update status / process_pid
    POST   /api/v1/runs/:id/finish      — body: {status, usage_json, error?}
    GET    /api/v1/runs/:id/log         — NDJSON log polling (offset, limit)
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Runs

  action_fallback CanopyWeb.FallbackController

  tags ["runs"]

  # ---------------------------------------------------------------------------
  # List
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List runs",
    parameters: [
      session_id: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      agent_slug: [in: :query, type: :string, required: false],
      status: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Run list", "application/json", %OpenApiSpex.Schema{type: :object}}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters =
      %{}
      |> maybe_put(:session_id, params["session_id"])
      |> maybe_put(:workspace_slug, params["workspace_slug"])
      |> maybe_put(:agent_slug, params["agent_slug"])
      |> maybe_put(:status, params["status"])
      |> maybe_put(:limit, parse_int(params["limit"]))

    runs = Runs.list(filters)
    json(conn, %{data: runs, count: length(runs)})
  end

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------

  operation :create,
    summary: "Create a run",
    request_body: {"Run params", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [
      created: {"Run created", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity:
        {"Validation error", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    case Runs.start(params) do
      {:ok, run} -> conn |> put_status(:created) |> json(%{data: run})
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Show
  # ---------------------------------------------------------------------------

  operation :show,
    summary: "Get a run by uuid or short_id",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Run", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, run} <- Runs.get(id) do
      json(conn, %{data: run})
    end
  end

  # ---------------------------------------------------------------------------
  # Update (status, process_pid, usage_json)
  # ---------------------------------------------------------------------------

  operation :update,
    summary: "Update a run",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Run update", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [
      ok: {"Run updated", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    with {:ok, run} <- Runs.get(id) do
      attrs = Map.drop(params, ["id"])

      case apply_update(run, attrs) do
        {:ok, updated} -> json(conn, %{data: updated})
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Finish
  # ---------------------------------------------------------------------------

  operation :finish,
    summary: "Finish a run",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Finish params (status + optional usage_json + error)", "application/json",
       %OpenApiSpex.Schema{type: :object}},
    responses: [
      ok: {"Run finished", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity:
        {"Invalid status", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec finish(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def finish(conn, %{"id" => id} = params) do
    status = params["status"]
    usage = params["usage_json"] || %{}
    error = params["error"]

    if status not in ~w(succeeded failed cancelled) do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{
        error: "invalid_status",
        message: "status must be one of: succeeded, failed, cancelled"
      })
    else
      with {:ok, run} <- Runs.mark_finished(id, status, usage, error) do
        json(conn, %{data: run})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Log polling — NDJSON transcript lines from scrollback file
  # ---------------------------------------------------------------------------

  operation :log,
    summary: "Poll run log (NDJSON)",
    parameters: [
      id: [in: :path, type: :string, required: true],
      offset: [in: :query, type: :integer, required: false, description: "Start from line N"],
      limit: [in: :query, type: :integer, required: false, description: "Max lines (default 200)"]
    ],
    responses: [
      ok: {"NDJSON log lines", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec log(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def log(conn, %{"id" => id} = params) do
    offset = parse_int(params["offset"]) || 0
    limit = min(parse_int(params["limit"]) || 200, 1000)

    with {:ok, run} <- Runs.get(id) do
      lines = read_log_lines(run.log_ref, offset, limit)
      total = length(lines) + offset

      json(conn, %{
        run_id: run.id,
        short_id: run.short_id,
        offset: offset,
        limit: limit,
        lines: lines,
        has_more: length(lines) == limit,
        total_so_far: total
      })
    end
  end

  # ---------------------------------------------------------------------------
  # Transcript — normalized typed blocks
  # ---------------------------------------------------------------------------

  operation :transcript,
    summary: "Get normalized transcript blocks for a run",
    description:
      "Returns typed blocks (stdout, stderr, tool_call, tool_result, thinking, user_prompt, permission_request, exit) in chronological order.",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Transcript blocks", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec transcript(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transcript(conn, %{"id" => id}) do
    with {:ok, run} <- Runs.get(id) do
      blocks = Runs.transcript(run)
      json(conn, %{run_id: run.id, short_id: run.short_id, blocks: blocks, count: length(blocks)})
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp apply_update(run, attrs) do
    status = attrs["status"] || attrs[:status]

    cond do
      status in ~w(running) ->
        process_pid = attrs["process_pid"] || attrs[:process_pid]
        Runs.mark_running(run.id, process_pid)

      status == "paused" ->
        Runs.mark_paused(run.id)

      status == "running" and run.status == "paused" ->
        Runs.mark_resumed(run.id)

      Map.has_key?(attrs, "usage_json") or Map.has_key?(attrs, :usage_json) ->
        delta = attrs["usage_json"] || attrs[:usage_json] || %{}
        Runs.append_usage(run.id, delta)

      true ->
        {:ok, run}
    end
  end

  defp read_log_lines(nil, _offset, _limit), do: []

  defp read_log_lines("file://" <> path, offset, limit) do
    read_log_from_file(path, offset, limit)
  end

  defp read_log_lines(log_ref, offset, limit) when is_binary(log_ref) do
    # Treat bare paths as file references
    read_log_from_file(log_ref, offset, limit)
  end

  defp read_log_from_file(path, offset, limit) do
    case File.read(path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.drop(offset)
        |> Enum.take(limit)
        |> Enum.with_index(offset)
        |> Enum.map(fn {line, seq} -> parse_log_line(line, seq) end)

      {:error, _} ->
        []
    end
  end

  defp parse_log_line(line, seq) do
    case Jason.decode(line) do
      {:ok, parsed} -> Map.put_new(parsed, "seq", seq)
      {:error, _} -> %{"seq" => seq, "kind" => "stdout", "data" => line, "at" => nil}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} -> n
      _ -> nil
    end
  end
end
