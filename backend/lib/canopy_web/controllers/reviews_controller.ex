defmodule CanopyWeb.ReviewsController do
  @moduledoc """
  HTTP API for the human-review approval queue.

  Routes:
    GET  /api/v1/reviews                        — list (filters: workspace_slug, status, kind, agent_id)
    GET  /api/v1/reviews/summary                — queue summary for dashboards and agents
    GET  /api/v1/reviews/:id                    — get by uuid
    POST /api/v1/reviews                        — request review (artifact or tool_call)
    POST /api/v1/reviews/:id/approve            — approve pending review
    POST /api/v1/reviews/:id/reject             — reject pending review (body: {feedback})
    POST /api/v1/reviews/:id/request_changes    — request changes on pending review (body: {feedback})
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Reviews
  alias CanopyWeb.Schemas.ReviewsSchema

  action_fallback(CanopyWeb.FallbackController)

  tags(["reviews"])

  # ---------------------------------------------------------------------------
  # List
  # ---------------------------------------------------------------------------

  operation(:index,
    summary: "List reviews",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false],
      status: [in: :query, type: :string, required: false],
      kind: [in: :query, type: :string, required: false],
      agent_id: [in: :query, type: :string, required: false],
      session_id: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Review list", "application/json", ReviewsSchema.ReviewList}]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    filters = filters_from_params(params)

    reviews = Reviews.list(filters)
    json(conn, %{data: reviews, count: length(reviews)})
  end

  operation(:summary,
    summary: "Review queue summary",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false],
      status: [in: :query, type: :string, required: false],
      kind: [in: :query, type: :string, required: false],
      agent_id: [in: :query, type: :string, required: false],
      session_id: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Review summary", "application/json", ReviewsSchema.ReviewSummary}]
  )

  @spec summary(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def summary(conn, params) do
    json(conn, %{data: Reviews.summary(filters_from_params(params))})
  end

  # ---------------------------------------------------------------------------
  # Show
  # ---------------------------------------------------------------------------

  operation(:show,
    summary: "Get a review by uuid",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Review", "application/json", ReviewsSchema.ReviewDetail},
      not_found: {"Not found", "application/json", ReviewsSchema.ErrorResponse}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, review} <- Reviews.get(id) do
      json(conn, %{data: review})
    end
  end

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------

  operation(:create,
    summary: "Request a review (artifact or tool_call)",
    request_body:
      {"Review request", "application/json", ReviewsSchema.CreateArtifactReviewRequest},
    responses: [
      created: {"Review created", "application/json", ReviewsSchema.ReviewDetail},
      unprocessable_entity: {"Validation error", "application/json", ReviewsSchema.ErrorResponse}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    run_id = Map.get(conn.assigns, :run_id)

    result =
      case params["kind"] do
        "tool_call" ->
          Reviews.request_tool_call(
            params["session_id"],
            params["tool_name"],
            params["tool_args"] || %{},
            run_id: run_id,
            workspace_slug: params["workspace_slug"],
            agent_id: params["agent_id"]
          )

        _ ->
          attrs = if run_id, do: Map.put(params, "created_by_run_id", run_id), else: params
          Reviews.request_artifact(attrs)
      end

    case result do
      {:ok, review} -> conn |> put_status(:created) |> json(%{data: review})
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Approve
  # ---------------------------------------------------------------------------

  operation(:approve,
    summary: "Approve a pending review",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Approve request", "application/json", ReviewsSchema.ApproveRequest},
    responses: [
      ok: {"Approved review", "application/json", ReviewsSchema.ReviewDetail},
      not_found: {"Not found", "application/json", ReviewsSchema.ErrorResponse},
      unprocessable_entity: {"Not pending", "application/json", ReviewsSchema.ErrorResponse}
    ]
  )

  @spec approve(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def approve(conn, %{"id" => id} = params) do
    reviewer_id = params["reviewer_id"]

    case Reviews.approve(id, reviewer_id) do
      {:ok, review} -> json(conn, %{data: review})
      {:error, :not_found} -> {:error, :not_found}
      {:error, :not_pending} -> not_pending_error(conn)
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Reject
  # ---------------------------------------------------------------------------

  operation(:reject,
    summary: "Reject a pending review",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Reject request", "application/json", ReviewsSchema.RejectRequest},
    responses: [
      ok: {"Rejected review", "application/json", ReviewsSchema.ReviewDetail},
      not_found: {"Not found", "application/json", ReviewsSchema.ErrorResponse},
      unprocessable_entity: {"Not pending", "application/json", ReviewsSchema.ErrorResponse}
    ]
  )

  @spec reject(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reject(conn, %{"id" => id} = params) do
    reviewer_id = params["reviewer_id"]
    feedback = params["feedback"]

    case Reviews.reject(id, reviewer_id, feedback) do
      {:ok, review} -> json(conn, %{data: review})
      {:error, :not_found} -> {:error, :not_found}
      {:error, :not_pending} -> not_pending_error(conn)
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Request changes
  # ---------------------------------------------------------------------------

  operation(:request_changes,
    summary: "Request changes on a pending review",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Request changes", "application/json", ReviewsSchema.RequestChangesRequest},
    responses: [
      ok: {"Review with changes requested", "application/json", ReviewsSchema.ReviewDetail},
      not_found: {"Not found", "application/json", ReviewsSchema.ErrorResponse},
      unprocessable_entity: {"Not pending", "application/json", ReviewsSchema.ErrorResponse}
    ]
  )

  @spec request_changes(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def request_changes(conn, %{"id" => id} = params) do
    reviewer_id = params["reviewer_id"]
    feedback = params["feedback"]

    case Reviews.request_changes(id, reviewer_id, feedback) do
      {:ok, review} -> json(conn, %{data: review})
      {:error, :not_found} -> {:error, :not_found}
      {:error, :not_pending} -> not_pending_error(conn)
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Resubmit
  # ---------------------------------------------------------------------------

  operation(:resubmit,
    summary: "Resubmit a review from changes_requested back to pending",
    description: "Bumps revision_count. Optionally updates artifact_preview.",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Resubmit params", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           new_artifact_preview: %OpenApiSpex.Schema{type: :string, nullable: true}
         }
       }},
    responses: [
      ok: {"Resubmitted review", "application/json", ReviewsSchema.ReviewDetail},
      not_found: {"Not found", "application/json", ReviewsSchema.ErrorResponse},
      unprocessable_entity:
        {"Not in changes_requested", "application/json", ReviewsSchema.ErrorResponse}
    ]
  )

  @spec resubmit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def resubmit(conn, %{"id" => id} = params) do
    attrs =
      case params["new_artifact_preview"] || params["artifact_preview"] do
        nil -> %{}
        preview -> %{artifact_preview: preview}
      end

    case Reviews.resubmit(id, attrs) do
      {:ok, review} ->
        json(conn, %{data: review})

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, :not_changes_requested} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "not_changes_requested",
          message: "Only reviews in changes_requested state can be resubmitted."
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp not_pending_error(conn) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: "not_pending",
      message: "Only pending reviews can be approved, rejected, or changed."
    })
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp filters_from_params(params) do
    %{}
    |> maybe_put(:workspace_slug, params["workspace_slug"])
    |> maybe_put(:status, params["status"])
    |> maybe_put(:kind, params["kind"])
    |> maybe_put(:agent_id, params["agent_id"])
    |> maybe_put(:session_id, params["session_id"])
  end
end
