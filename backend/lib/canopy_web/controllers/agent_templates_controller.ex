defmodule CanopyWeb.AgentTemplatesController do
  @moduledoc """
  HTTP API for the agent template marketplace.

  Routes:
    GET  /api/v1/agent-templates              — list templates (optional ?category=...)
    GET  /api/v1/agent-templates/:slug        — get single template
    POST /api/v1/agents/from-template         — clone template into a real hired agent
  """

  use CanopyWeb, :controller

  alias Canopy.Agents.Templates

  action_fallback CanopyWeb.FallbackController

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    opts =
      case Map.get(params, "category") do
        nil -> []
        cat -> [category: cat]
      end

    {:ok, templates} = Templates.list(opts)
    json(conn, %{data: templates})
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"slug" => slug}) do
    with {:ok, template} <- Templates.get_by_slug(slug) do
      json(conn, template)
    end
  end

  @spec from_template(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def from_template(conn, params) do
    with {:ok, agent} <- Templates.from_template(params) do
      body =
        agent
        |> Map.from_struct()
        |> Map.drop([:__meta__])
        |> Map.put(:persona_content, agent.persona_markdown)

      conn
      |> put_status(:created)
      |> json(body)
    end
  end
end
