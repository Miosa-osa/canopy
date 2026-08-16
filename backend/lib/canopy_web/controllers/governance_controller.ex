defmodule CanopyWeb.GovernanceController do
  @moduledoc """
  HTTP API for Canopy governance rules, approvals, and audit log.

  All mutations produce an append-only audit log entry. Rules are evaluated
  in priority order during session creation (see Canopy.Governance @moduledoc).

  Routes (add to router.ex under :api pipeline):
    GET    /api/v1/governance/rules                   — rules_index
    POST   /api/v1/governance/rules                   — rules_create
    PUT    /api/v1/governance/rules/:id               — rules_update
    DELETE /api/v1/governance/rules/:id               — rules_delete
    GET    /api/v1/governance/approvals               — approvals_index
    POST   /api/v1/governance/approvals/:id/approve   — approve
    POST   /api/v1/governance/approvals/:id/reject    — reject
    GET    /api/v1/governance/audit                   — audit
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ecto.Query, only: [from: 2]

  alias Canopy.Governance
  alias Canopy.Governance.{Approval, Permissions}
  alias Canopy.Repo
  alias CanopyWeb.Schemas.GovernanceSchema

  action_fallback CanopyWeb.FallbackController

  tags ["governance"]

  # ---------------------------------------------------------------------------
  # Rules
  # ---------------------------------------------------------------------------

  operation :rules_index,
    summary: "List governance rules",
    description: "Returns all governance rules ordered by priority descending.",
    parameters: [
      enabled_only: [in: :query, type: :boolean, required: false]
    ],
    responses: [
      ok: {"Governance rule list", "application/json", GovernanceSchema.GovernanceRuleList}
    ]

  @spec rules_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def rules_index(conn, params) do
    enabled_only = params["enabled_only"] in [true, "true"]
    rules = Governance.list_rules(enabled_only: enabled_only)
    json(conn, %{data: rules})
  end

  operation :rules_create,
    summary: "Create a governance rule",
    request_body:
      {"Governance rule params", "application/json", GovernanceSchema.CreateRuleRequest},
    responses: [
      created: {"Created rule", "application/json", GovernanceSchema.GovernanceRule},
      unprocessable_entity:
        {"Validation error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec rules_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def rules_create(conn, params) do
    with {:ok, rule} <- Governance.create_rule(params) do
      conn
      |> put_status(:created)
      |> json(rule)
    end
  end

  operation :rules_update,
    summary: "Update a governance rule",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Governance rule params", "application/json", GovernanceSchema.CreateRuleRequest},
    responses: [
      ok: {"Updated rule", "application/json", GovernanceSchema.GovernanceRule},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Validation error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec rules_update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def rules_update(conn, %{"id" => id} = params) do
    rule = Governance.get_rule!(id)
    attrs = Map.drop(params, ["id"])

    with {:ok, updated} <- Governance.update_rule(rule, attrs) do
      json(conn, updated)
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  operation :rules_delete,
    summary: "Delete a governance rule",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      no_content: "Rule deleted",
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec rules_delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def rules_delete(conn, %{"id" => id}) do
    rule = Governance.get_rule!(id)

    with {:ok, _deleted} <- Governance.delete_rule(rule) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  # ---------------------------------------------------------------------------
  # Approvals
  # ---------------------------------------------------------------------------

  operation :approvals_index,
    summary: "List governance approvals",
    description: "Returns approvals, optionally filtered by status.",
    parameters: [
      status: [in: :query, type: :string, required: false]
    ],
    responses: [
      ok: {"Approval list", "application/json", GovernanceSchema.GovernanceApprovalList}
    ]

  @spec approvals_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def approvals_index(conn, params) do
    approvals =
      case params["status"] do
        nil -> Governance.pending_approvals()
        "pending" -> Governance.pending_approvals()
        status -> list_approvals_by_status(status)
      end

    json(conn, %{data: approvals})
  end

  operation :approve,
    summary: "Approve a pending governance approval",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Decision params", "application/json", GovernanceSchema.DecisionRequest},
    responses: [
      ok: {"Approved approval", "application/json", GovernanceSchema.GovernanceApproval},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Already decided", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec approve(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def approve(conn, %{"id" => id} = params) do
    decided_by = params["decided_by"] || ""
    reason = params["reason"] || ""

    case Governance.approve(id, decided_by, reason) do
      {:ok, approval} -> json(conn, approval)
      {:error, :not_found} -> {:error, :not_found}
      {:error, {:already_decided, status}} -> already_decided(conn, status)
      {:error, cs} -> {:error, cs}
    end
  end

  operation :reject,
    summary: "Reject a pending governance approval",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Decision params", "application/json", GovernanceSchema.DecisionRequest},
    responses: [
      ok: {"Rejected approval", "application/json", GovernanceSchema.GovernanceApproval},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Already decided", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec reject(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reject(conn, %{"id" => id} = params) do
    decided_by = params["decided_by"] || ""
    reason = params["reason"] || ""

    case Governance.reject(id, decided_by, reason) do
      {:ok, approval} -> json(conn, approval)
      {:error, :not_found} -> {:error, :not_found}
      {:error, {:already_decided, status}} -> already_decided(conn, status)
      {:error, cs} -> {:error, cs}
    end
  end

  # ---------------------------------------------------------------------------
  # Audit log
  # ---------------------------------------------------------------------------

  operation :audit,
    summary: "Query governance audit log",
    description: "Returns audit log entries, newest first. Append-only — never modified.",
    parameters: [
      event_type: [in: :query, type: :string, required: false],
      since: [in: :query, type: :string, required: false, description: "ISO8601 datetime"],
      until: [in: :query, type: :string, required: false, description: "ISO8601 datetime"],
      session_id: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"Audit log", "application/json", GovernanceSchema.AuditLogList}
    ]

  @spec audit(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def audit(conn, params) do
    opts =
      []
      |> put_if(params["event_type"], :event_type, params["event_type"])
      |> put_if(params["since"], :since, params["since"])
      |> put_if(params["until"], :until, params["until"])
      |> put_if(params["session_id"], :session_id, params["session_id"])
      |> put_if(params["limit"], :limit, parse_int(params["limit"]))

    entries = Governance.list_audit(opts)
    json(conn, %{data: entries})
  end

  # ---------------------------------------------------------------------------
  # Tool permission grants
  # ---------------------------------------------------------------------------

  operation :permissions_index,
    summary: "List tool permission grants",
    description: "Returns grants, optionally filtered by agent_slug, tool_name, workspace_slug, or scope.",
    parameters: [
      agent_slug: [in: :query, type: :string, required: false],
      tool_name: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      scope: [in: :query, type: :string, required: false]
    ],
    responses: [
      ok: {"Permission grant list", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec permissions_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def permissions_index(conn, params) do
    filters =
      []
      |> put_if(params["agent_slug"], :agent_slug, params["agent_slug"])
      |> put_if(params["tool_name"], :tool_name, params["tool_name"])
      |> put_if(params["workspace_slug"], :workspace_slug, params["workspace_slug"])
      |> put_if(params["scope"], :scope, params["scope"])

    grants = Permissions.list_grants(filters)
    json(conn, %{data: grants})
  end

  operation :permissions_create,
    summary: "Create a tool permission grant",
    description: "Grants a scoped permission. Scope must be one of: once, session, today, forever, never.",
    request_body: {"Grant params", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [
      created: {"Created grant", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity:
        {"Validation error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec permissions_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def permissions_create(conn, params) do
    with {:ok, grant} <- Permissions.grant_permission(params) do
      conn
      |> put_status(:created)
      |> json(grant)
    end
  end

  operation :permissions_delete,
    summary: "Revoke a tool permission grant",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      no_content: "Grant revoked",
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec permissions_delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def permissions_delete(conn, %{"id" => id}) do
    case Permissions.revoke_permission(id) do
      {:ok, _grant} -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  operation :permissions_check,
    summary: "Check if an agent is permitted to use a tool",
    description: "Returns the effective permission status: allowed, denied, or ask.",
    request_body: {"Check params", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [
      ok: {"Permission check result", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec permissions_check(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def permissions_check(conn, params) do
    agent_slug = params["agent_slug"] || ""
    tool_name = params["tool_name"] || ""

    opts =
      []
      |> put_if(params["session_id"], :session_id, params["session_id"])
      |> put_if(params["workspace_slug"], :workspace_slug, params["workspace_slug"])

    result = Permissions.check_permission(agent_slug, tool_name, opts)

    json(conn, %{status: result, agent_slug: agent_slug, tool_name: tool_name})
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp already_decided(conn, status) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "already_decided", message: "Approval is already #{status}."})
  end

  defp list_approvals_by_status(status) do
    Repo.all(
      from(a in Approval,
        where: a.status == ^status,
        order_by: [asc: a.requested_at]
      )
    )
  end

  defp put_if(opts, nil, _key, _val), do: opts
  defp put_if(opts, "", _key, _val), do: opts
  defp put_if(opts, _truthy, key, val), do: Keyword.put(opts, key, val)

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} -> n
      _other -> nil
    end
  end
end
