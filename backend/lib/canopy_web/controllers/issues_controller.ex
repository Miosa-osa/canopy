defmodule CanopyWeb.IssuesController do
  @moduledoc """
  HTTP API for developer issues.

  Routes:
    GET    /api/v1/issues               — list with filters
    POST   /api/v1/issues               — create
    GET    /api/v1/issues/:id           — get by short_id or uuid
    PATCH  /api/v1/issues/:id           — update
    POST   /api/v1/issues/:id/assign    — assign to agent or human
    POST   /api/v1/issues/:id/complete  — close
    POST   /api/v1/issues/:id/reopen    — reopen to open
    POST   /api/v1/issues/:id/dispatch  — dispatch to agent terminal
    POST   /api/v1/issues/:id/transition — Kanban drag-to-state (verb + status)
    DELETE /api/v1/issues/:id           — hard delete
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Issues
  alias CanopyWeb.Schemas.IssuesSchema

  action_fallback CanopyWeb.FallbackController

  tags ["issues"]

  operation :index,
    summary: "List issues",
    parameters: [
      status: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      project_slug: [in: :query, type: :string, required: false],
      assignee_type: [in: :query, type: :string, required: false],
      assignee_id: [in: :query, type: :string, required: false],
      parent_id: [in: :query, type: :string, required: false],
      q: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Issue list", "application/json", IssuesSchema.IssueList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters =
      %{}
      |> maybe_put(:status, params["status"])
      |> maybe_put(:workspace_slug, params["workspace_slug"])
      |> maybe_put(:project_slug, params["project_slug"])
      |> maybe_put(:assignee_type, params["assignee_type"])
      |> maybe_put(:assignee_id, params["assignee_id"])
      |> maybe_put(:parent_id, params["parent_id"])
      |> maybe_put(:q, params["q"])
      |> maybe_put(:limit, parse_int(params["limit"]))

    issues = Issues.list(filters)
    json(conn, %{data: issues, count: length(issues)})
  end

  operation :create,
    summary: "Create an issue",
    request_body: {"Issue params", "application/json", IssuesSchema.CreateIssueRequest},
    responses: [
      created: {"Issue created", "application/json", IssuesSchema.IssueDetail},
      unprocessable_entity: {"Validation error", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    attrs = maybe_stamp_run_id(params, conn)

    case Issues.create(attrs) do
      {:ok, issue} -> conn |> put_status(:created) |> json(%{data: issue})
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :show,
    summary: "Get an issue by short_id or uuid",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Issue", "application/json", IssuesSchema.IssueDetail},
      not_found: {"Not found", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, issue} <- Issues.get(id) do
      json(conn, %{data: issue})
    end
  end

  operation :update,
    summary: "Update an issue",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Update params", "application/json", IssuesSchema.UpdateIssueRequest},
    responses: [
      ok: {"Updated issue", "application/json", IssuesSchema.IssueDetail},
      not_found: {"Not found", "application/json", IssuesSchema.ErrorResponse},
      unprocessable_entity: {"Validation error", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    case Issues.update(id, params) do
      {:ok, issue} -> json(conn, %{data: issue})
      {:error, :not_found} -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  operation :assign,
    summary: "Assign an issue",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Assign params", "application/json", IssuesSchema.AssignIssueRequest},
    responses: [
      ok: {"Assigned issue", "application/json", IssuesSchema.IssueDetail},
      not_found: {"Not found", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec assign(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def assign(conn, %{"id" => id, "assignee_type" => _type, "assignee_id" => _aid} = params) do
    case Issues.assign(id, params) do
      {:ok, issue} -> json(conn, %{data: issue})
      error -> error
    end
  end

  def assign(conn, _) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "assignee_type and assignee_id are required."})
  end

  operation :complete,
    summary: "Close an issue",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Closed issue", "application/json", IssuesSchema.IssueDetail},
      not_found: {"Not found", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec complete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def complete(conn, %{"id" => id}) do
    case Issues.complete(id) do
      {:ok, issue} -> json(conn, %{data: issue})
      error -> error
    end
  end

  operation :reopen,
    summary: "Reopen a closed issue",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Reopened issue", "application/json", IssuesSchema.IssueDetail},
      not_found: {"Not found", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec reopen(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reopen(conn, %{"id" => id}) do
    case Issues.reopen(id) do
      {:ok, issue} -> json(conn, %{data: issue})
      error -> error
    end
  end

  operation :transition,
    summary: "Kanban drag-to-state — apply a verb to an issue",
    description:
      "Applies a column verb (start/pause/resume/stop/done/noop) and optionally updates issue status.",
    parameters: [id: [in: :path, type: :string, required: true]],
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
      ok: {"Transition result", "application/json", IssuesSchema.IssueDispatchResponse},
      not_found: {"Issue not found", "application/json", IssuesSchema.ErrorResponse},
      unprocessable_entity: {"Error", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec transition(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transition(conn, %{"id" => id} = params) do
    verb = params["verb"] || "noop"
    target_status = params["status"]

    case Issues.apply_verb(id, verb, target_status) do
      {:ok, issue, session_id} ->
        json(conn, %{data: %{issue: issue, session_id: session_id}})

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
    summary: "Dispatch an issue to an agent terminal session",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Dispatch options", "application/json", IssuesSchema.IssueDispatchRequest, required: false},
    responses: [
      ok: {"Dispatch result", "application/json", IssuesSchema.IssueDispatchResponse},
      not_found: {"Issue not found", "application/json", IssuesSchema.ErrorResponse},
      unprocessable_entity:
        {"No target or unauthenticated", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec dispatch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dispatch(conn, %{"id" => id} = params) do
    opts =
      []
      |> maybe_opt(:agent_slug, params["agent_slug"])
      |> maybe_opt(:runtime_type, params["runtime_type"])

    case Issues.dispatch(id, opts) do
      {:ok, %{session_id: session_id, issue: issue}} ->
        json(conn, %{data: %{session_id: session_id, issue: issue}})

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, :no_target} ->
        {:error, :no_target}

      {:error, :runtime_unauthenticated} ->
        {:error, :runtime_unauthenticated}
    end
  end

  operation :checkout,
    summary: "Check out an issue for exclusive agent ownership",
    description:
      "Returns 200 on success or auto-renew. Returns 409 if another agent holds an active lock.",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Checkout params", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           agent_slug: %OpenApiSpex.Schema{type: :string},
           ttl_seconds: %OpenApiSpex.Schema{type: :integer, nullable: true}
         },
         required: ["agent_slug"]
       }},
    responses: [
      ok: {"Checked-out issue", "application/json", IssuesSchema.IssueDetail},
      conflict: {"Already checked out", "application/json", IssuesSchema.ErrorResponse},
      not_found: {"Not found", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec checkout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def checkout(conn, %{"id" => id, "agent_slug" => agent_slug} = params) do
    ttl = parse_int(params["ttl_seconds"]) || 1800

    case Issues.try_checkout(id, agent_slug, ttl) do
      {:ok, issue} ->
        json(conn, %{data: issue})

      {:error, :already_checked_out, %{locked_by: locked_by, locked_until: locked_until}} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "already_checked_out",
          locked_by: locked_by,
          locked_until: DateTime.to_iso8601(locked_until)
        })

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def checkout(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "agent_slug is required"})
  end

  operation :release,
    summary: "Release an issue checkout lock",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Release params", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{agent_slug: %OpenApiSpex.Schema{type: :string}},
         required: ["agent_slug"]
       }},
    responses: [
      no_content: "Released",
      not_found: {"Not found", "application/json", IssuesSchema.ErrorResponse},
      forbidden: {"Not owner", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec release(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def release(conn, %{"id" => id, "agent_slug" => agent_slug}) do
    case Issues.release(id, agent_slug) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, :not_owner} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "not_owner", message: "Only the owning agent can release a lock"})
    end
  end

  def release(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "agent_slug is required"})
  end

  operation :delete,
    summary: "Hard-delete an issue",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      no_content: "Deleted",
      not_found: {"Not found", "application/json", IssuesSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    case Issues.delete(id) do
      :ok -> send_resp(conn, :no_content, "")
      error -> error
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

  defp maybe_stamp_run_id(params, conn) do
    case Map.get(conn.assigns, :run_id) do
      nil -> params
      run_id -> Map.put(params, "created_by_run_id", run_id)
    end
  end
end
