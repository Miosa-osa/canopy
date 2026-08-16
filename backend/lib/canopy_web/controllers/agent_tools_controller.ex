defmodule CanopyWeb.AgentToolsController do
  @moduledoc """
  HTTP API for agent-to-Canopy orchestration tool calls.

  Routes:
    POST /api/v1/agents/tools/:tool_name   — execute a named tool from a session
    GET  /api/v1/agents/:slug/tool-calls   — list recent tool calls for an agent

  ## Auth

  v1 trust model: `session_id` in the request body must match a real session in
  the database. The session's `agent_slug` determines the agent's capabilities.
  No external token required — sessions are already scoped to the backend process.

  ## Response shapes

  - 200 `{ ok: true, result: ... }`               — tool executed successfully
  - 202 `{ ok: false, pending_review: true, review_id: "..." }` — governance gate
  - 403 `{ ok: false, error: "agent lacks capability <name>" }` — missing capability
  - 422 `{ ok: false, error: "..." }`              — validation or execution error
  """

  use CanopyWeb, :controller

  alias Canopy.Agents.{ToolCalls, Tools}

  action_fallback CanopyWeb.FallbackController

  @doc """
  Dispatches a tool call on behalf of the session identified by `session_id`
  in the request body.

  Expects JSON body: `{ "session_id": "...", "params": { ... } }`
  """
  @spec dispatch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dispatch(conn, %{"tool_name" => tool_name} = params) do
    session_id = params["session_id"]
    tool_params = params["params"] || %{}

    if is_nil(session_id) or session_id == "" do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{ok: false, error: "missing session_id"})
    else
      run_id = Map.get(conn.assigns, :run_id)
      tool_opts = if run_id, do: [run_id: run_id], else: []

      case Tools.execute(tool_name, session_id, tool_params, tool_opts) do
        {:ok, result} ->
          json(conn, %{ok: true, result: result})

        {:pending_review, review_id} ->
          conn
          |> put_status(:accepted)
          |> json(%{ok: false, pending_review: true, review_id: review_id})

        {:error, "agent lacks capability" <> _ = msg} ->
          conn
          |> put_status(:forbidden)
          |> json(%{ok: false, error: msg})

        {:error, "session not found" <> _ = msg} ->
          conn
          |> put_status(:not_found)
          |> json(%{ok: false, error: msg})

        {:error, msg} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{ok: false, error: msg})
      end
    end
  end

  @doc "Lists recent agent_tool_calls for the given agent slug."
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"slug" => slug} = params) do
    filters =
      %{agent_id: slug}
      |> maybe_put(:status, params["status"])
      |> maybe_put(:limit, parse_limit(params["limit"]))

    tool_calls = ToolCalls.list(filters)
    json(conn, %{data: tool_calls})
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(acc, _key, nil), do: acc
  defp maybe_put(acc, key, val), do: Map.put(acc, key, val)

  defp parse_limit(nil), do: nil
  defp parse_limit(n) when is_integer(n), do: n
  defp parse_limit(s) when is_binary(s), do: String.to_integer(s)
end
