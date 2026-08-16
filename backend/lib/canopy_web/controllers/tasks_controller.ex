defmodule CanopyWeb.TasksController do
  @moduledoc """
  HTTP API for tasks. Single table, CRUD only.

  Routes:
    GET    /api/v1/tasks               — list with filters
    POST   /api/v1/tasks               — create
    GET    /api/v1/tasks/:id           — get by short_id
    PUT    /api/v1/tasks/:id           — update
    PATCH  /api/v1/tasks/:id           — update (alias)
    POST   /api/v1/tasks/:id/assign    — assign to actor
    POST   /api/v1/tasks/:id/complete  — mark done
    POST   /api/v1/tasks/:id/reopen    — reopen
    POST   /api/v1/tasks/:id/dispatch  — dispatch to agent terminal
    POST   /api/v1/tasks/:id/transition — Kanban drag-to-state (verb + status)
    DELETE /api/v1/tasks/:id           — hard delete

  ## PubSub contract (dispatch)

  On successful dispatch, Phoenix.PubSub broadcasts on `tasks:workspace:<workspace_slug>`:

      {:task_dispatched, %{task_id: short_id, session_id: session_id, status: "in_progress"}}

  The frontend should subscribe via the existing workspace channel (if one exists)
  or refetch the task list on receiving the event.
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Tasks
  alias Canopy.Tasks.Dispatcher
  alias CanopyWeb.Schemas.TasksSchema

  action_fallback CanopyWeb.FallbackController

  tags ["tasks"]

  operation :index,
    summary: "List tasks",
    parameters: [
      status: [in: :query, type: :string, required: false],
      project_slug: [in: :query, type: :string, required: false],
      assignee_type: [in: :query, type: :string, required: false],
      assignee_id: [in: :query, type: :string, required: false],
      parent_id: [in: :query, type: :string, required: false],
      q: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Task list", "application/json", TasksSchema.TaskList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters =
      %{}
      |> maybe_put(:status, params["status"])
      |> maybe_put(:project_slug, params["project_slug"])
      |> maybe_put(:assignee_type, params["assignee_type"])
      |> maybe_put(:assignee_id, params["assignee_id"])
      |> maybe_put(:parent_id, params["parent_id"])
      |> maybe_put(:q, params["q"])
      |> maybe_put(:limit, parse_int(params["limit"]))

    tasks = Tasks.list(filters)
    json(conn, %{data: tasks, count: length(tasks)})
  end

  operation :create,
    summary: "Create a task",
    request_body: {"Task params", "application/json", TasksSchema.CreateTaskRequest},
    responses: [
      created: {"Task created", "application/json", TasksSchema.TaskDetail},
      unprocessable_entity: {"Validation error", "application/json", TasksSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    attrs = maybe_stamp_run_id(params, conn)

    case Tasks.create(attrs) do
      {:ok, task} ->
        conn |> put_status(:created) |> json(%{data: task})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation :show,
    summary: "Get a task by short_id",
    parameters: [id: [in: :path, type: :string, required: true, description: "Task short_id"]],
    responses: [
      ok: {"Task", "application/json", TasksSchema.TaskDetail},
      not_found: {"Not found", "application/json", TasksSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, task} <- Tasks.get(id) do
      json(conn, %{data: task})
    end
  end

  operation :update,
    summary: "Update a task",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Update params", "application/json", TasksSchema.UpdateTaskRequest},
    responses: [
      ok: {"Updated task", "application/json", TasksSchema.TaskDetail},
      not_found: {"Not found", "application/json", TasksSchema.ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", TasksSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    case Tasks.update(id, params) do
      {:ok, task} -> json(conn, %{data: task})
      {:error, :not_found} -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :assign,
    summary: "Assign a task",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Assign params — {assignee_type, assignee_id}", "application/json",
       %OpenApiSpex.Schema{type: :object}},
    responses: [
      ok: {"Assigned task", "application/json", TasksSchema.TaskDetail},
      not_found: {"Not found", "application/json", TasksSchema.ErrorResponse}
    ]

  @spec assign(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def assign(conn, %{"id" => id, "assignee_type" => type, "assignee_id" => aid}) do
    case Tasks.assign(id, type, aid) do
      {:ok, task} -> json(conn, %{data: task})
      error -> error
    end
  end

  def assign(conn, _) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "assignee_type and assignee_id are required."})
  end

  operation :complete,
    summary: "Mark a task as done",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Completed task", "application/json", TasksSchema.TaskDetail},
      not_found: {"Not found", "application/json", TasksSchema.ErrorResponse}
    ]

  @spec complete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def complete(conn, %{"id" => id}) do
    case Tasks.complete(id) do
      {:ok, task} -> json(conn, %{data: task})
      error -> error
    end
  end

  operation :reopen,
    summary: "Reopen a completed task",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Reopened task", "application/json", TasksSchema.TaskDetail},
      not_found: {"Not found", "application/json", TasksSchema.ErrorResponse}
    ]

  @spec reopen(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reopen(conn, %{"id" => id}) do
    case Tasks.reopen(id) do
      {:ok, task} -> json(conn, %{data: task})
      error -> error
    end
  end

  operation :delete,
    summary: "Hard-delete a task",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", TasksSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    case Tasks.delete(id) do
      :ok -> send_resp(conn, :no_content, "")
      error -> error
    end
  end

  operation :transition,
    summary: "Kanban drag-to-state — apply a verb to a task",
    description:
      "Applies a column verb (start/pause/resume/stop/done/noop) and optionally updates task status.",
    parameters: [id: [in: :path, type: :string, required: true, description: "Task short_id"]],
    request_body:
      {"Transition params", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           verb: %OpenApiSpex.Schema{
             type: :string,
             enum: ["start", "build", "pause", "resume", "stop", "cancel", "done", "noop"]
           },
           status: %OpenApiSpex.Schema{type: :string, nullable: true}
         },
         required: ["verb"]
       }},
    responses: [
      ok: {"Transition result", "application/json", TasksSchema.DispatchResponse},
      not_found: {"Task not found", "application/json", TasksSchema.ErrorResponse},
      unprocessable_entity: {"Error", "application/json", TasksSchema.ErrorResponse}
    ]

  @spec transition(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transition(conn, %{"id" => id} = params) do
    verb = params["verb"] || "noop"
    target_status = params["status"]

    case Tasks.apply_verb(id, verb, target_status) do
      {:ok, task, session_id} ->
        json(conn, %{data: %{task: task, session_id: session_id}})

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, :no_target} ->
        {:error, :no_target}

      {:error, :runtime_unauthenticated} ->
        {:error, :runtime_unauthenticated}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation :dispatch,
    summary: "Dispatch a task to an agent terminal session",
    parameters: [id: [in: :path, type: :string, required: true, description: "Task short_id"]],
    request_body:
      {"Dispatch options (all optional)", "application/json", TasksSchema.DispatchRequest,
       required: false},
    responses: [
      ok: {"Dispatch result", "application/json", TasksSchema.DispatchResponse},
      not_found: {"Task not found", "application/json", TasksSchema.ErrorResponse},
      unprocessable_entity:
        {"No target or unauthenticated", "application/json", TasksSchema.ErrorResponse}
    ]

  @doc """
  Dispatches the task to a live agent terminal session.

  Accepts an optional JSON body:
    - `agent_slug`    — override the task's assigned agent
    - `runtime_type`  — override the agent's default runtime

  Returns 200 with `{ data: { session_id, task } }` on success.
  Returns 422 with `{ error: "no_target" | "runtime_unauthenticated", message }` when
  no session can be resolved.
  """
  @spec dispatch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dispatch(conn, %{"id" => id} = params) do
    opts =
      []
      |> maybe_opt(:agent_slug, params["agent_slug"])
      |> maybe_opt(:runtime_type, params["runtime_type"])

    case Dispatcher.dispatch(id, opts) do
      {:ok, %{session_id: session_id, task: task}} ->
        json(conn, %{data: %{session_id: session_id, task: task}})

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, :no_target} ->
        {:error, :no_target}

      {:error, :runtime_unauthenticated} ->
        {:error, :runtime_unauthenticated}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp maybe_opt(opts, _key, nil), do: opts
  defp maybe_opt(opts, key, val), do: Keyword.put(opts, key, val)

  defp parse_int(nil), do: nil

  defp parse_int(s) do
    case Integer.parse(s) do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end

  # Stamps created_by_run_id when an X-Run-Id was present on the request.
  defp maybe_stamp_run_id(params, conn) do
    case Map.get(conn.assigns, :run_id) do
      nil -> params
      run_id -> Map.put(params, "created_by_run_id", run_id)
    end
  end
end
