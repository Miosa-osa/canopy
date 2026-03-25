defmodule CanopyWeb.Plugs.Governance do
  @moduledoc """
  Governance plug that intercepts critical actions and enforces approval gates.

  When an action requires approval, the plug halts with HTTP 202 and returns
  the pending approval record. The action can then be replayed automatically
  once the approval is granted.

  Gate mappings:
    - POST /spawn          → :spawn_agent
    - DELETE /agents/:id   → :delete_agent
    - POST /agents/:id/terminate → :delete_agent
    - POST /budgets/incidents/:id/resolve → :budget_override
    - POST /goals/:id/decompose → :strategy
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Canopy.Governance.Gate

  def init(opts), do: opts

  def call(conn, _opts) do
    case detect_gate(conn) do
      nil ->
        conn

      gate_type ->
        context = build_context(conn, gate_type)

        case Gate.check(gate_type, context) do
          :allowed ->
            conn

          {:requires_approval, approval} ->
            conn
            |> put_status(202)
            |> json(%{
              status: "pending_approval",
              message: "This action requires governance approval before it can proceed.",
              approval: %{
                id: Map.get(approval, :id),
                title: Map.get(approval, :title),
                status: "pending"
              }
            })
            |> halt()
        end
    end
  end

  # Detect which governance gate applies to this request
  defp detect_gate(%{method: "POST", path_info: ["api", "v1", "spawn"]}), do: :spawn_agent

  defp detect_gate(%{method: "DELETE", path_info: ["api", "v1", "agents", _id]}),
    do: :delete_agent

  defp detect_gate(%{method: "POST", path_info: ["api", "v1", "agents", _id, "terminate"]}),
    do: :delete_agent

  defp detect_gate(%{
         method: "POST",
         path_info: ["api", "v1", "budgets", "incidents", _id, "resolve"]
       }),
       do: :budget_override

  defp detect_gate(%{method: "POST", path_info: ["api", "v1", "goals", _id, "decompose"]}),
    do: :strategy

  defp detect_gate(_conn), do: nil

  defp build_context(conn, gate_type) do
    user = conn.assigns[:current_user]
    workspace_ids = conn.assigns[:user_workspace_ids] || []

    %{
      workspace_id: List.first(workspace_ids),
      entity_id: extract_entity_id(conn, gate_type),
      entity_name: conn.params["name"],
      action: "#{conn.method} #{conn.request_path}",
      agent_id: conn.params["agent_id"],
      user_id: user && user.id,
      params: sanitize_params(conn.params)
    }
  end

  defp extract_entity_id(conn, :spawn_agent), do: conn.params["agent_id"]
  defp extract_entity_id(conn, :delete_agent), do: conn.path_params["id"] || conn.params["agent_id"]
  defp extract_entity_id(conn, :budget_override), do: conn.path_params["id"] || conn.params["id"]
  defp extract_entity_id(conn, :strategy), do: conn.path_params["id"] || conn.params["id"]
  defp extract_entity_id(_conn, _), do: nil

  @sensitive_keys ~w(password token secret api_key)
  defp sanitize_params(params) when is_map(params) do
    params
    |> Map.drop(@sensitive_keys ++ ["_format"])
    |> Map.take(~w(agent_id name context scope_type scope_id id))
  end

  defp sanitize_params(_), do: %{}
end
