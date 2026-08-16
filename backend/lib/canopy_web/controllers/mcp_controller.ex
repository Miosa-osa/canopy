defmodule CanopyWeb.MCPController do
  @moduledoc """
  HTTP API surfacing MCP-related read views for the desktop MCP Tools pane.

  Two read-only actions, both thin wrappers over existing primitives — no new
  state, no new tables, no parallel registry.

    * `GET /api/v1/mcp/servers`     — connected MCP servers (Phase A stub)
    * `GET /api/v1/mcp/tool-calls`  — global tool invocation log

  ## Why this controller exists (not in `tools_controller.ex`)

  `tools_controller.ex` exposes the in-memory `Canopy.Tools.Registry`. The
  invocation log is a *persistent audit* surface owned by
  `Canopy.Agents.ToolCalls`, and MCP server records are connection state owned
  by Phase B (Track J). Mixing these into ToolsController would couple three
  unrelated contexts.

  ## Validation

    * `limit` is parsed as integer, clamped to `1..1000` to match other Canopy
      list endpoints (sessions, breadcrumbs, etc.).
    * `status` is restricted to the values declared on `agent_tool_calls`.

  Phase B will replace `servers/2` with real connection records and add
  PubSub fan-out on the tool-call topic.
  """

  use CanopyWeb, :controller

  alias Canopy.Agents.ToolCalls

  action_fallback CanopyWeb.FallbackController

  @max_limit 1000
  @default_limit 100
  @valid_statuses ~w(ok error pending_review)

  # ---------------------------------------------------------------------------
  # GET /api/v1/mcp/servers
  # ---------------------------------------------------------------------------

  @doc """
  Phase A stub — returns an empty list. Phase B will return connected servers
  from `Canopy.MCP.Servers` (not yet implemented).
  """
  @spec servers(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def servers(conn, _params) do
    json(conn, %{data: []})
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/mcp/tool-calls
  # ---------------------------------------------------------------------------

  @doc """
  Lists the most recent agent tool-call audit rows across all sessions and
  agents. Polled by the InvocationLog component every ~5s.

  Query params:
    * `status` — `"ok" | "error" | "pending_review"` (optional)
    * `limit`  — integer, default #{@default_limit}, capped at #{@max_limit}
  """
  @spec tool_calls(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def tool_calls(conn, params) do
    filters =
      %{}
      |> maybe_put_status(params["status"])
      |> Map.put(:limit, parse_limit(params["limit"]))

    rows = ToolCalls.list(filters)
    json(conn, %{data: Enum.map(rows, &serialize_tool_call/1)})
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp maybe_put_status(filters, status) when status in @valid_statuses,
    do: Map.put(filters, :status, status)

  defp maybe_put_status(filters, _), do: filters

  defp parse_limit(nil), do: @default_limit
  defp parse_limit(n) when is_integer(n), do: clamp_limit(n)

  defp parse_limit(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> clamp_limit(n)
      :error -> @default_limit
    end
  end

  defp parse_limit(_), do: @default_limit

  defp clamp_limit(n) when is_integer(n) do
    n
    |> max(1)
    |> min(@max_limit)
  end

  defp serialize_tool_call(tc) do
    %{
      id: tc.id,
      session_id: tc.session_id,
      run_id: tc.run_id,
      agent_id: tc.agent_id,
      tool_name: tc.tool_name,
      params: tc.params || %{},
      result: tc.result,
      status: tc.status,
      error: tc.error,
      review_id: tc.review_id,
      inserted_at: tc.inserted_at
    }
  end
end
