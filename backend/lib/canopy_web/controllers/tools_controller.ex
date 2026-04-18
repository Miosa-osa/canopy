defmodule CanopyWeb.ToolsController do
  @moduledoc """
  HTTP API for the Canopy tool registry.

  Tools are functions agents can invoke during execution. This controller
  exposes the registry for inspection and test-dispatch.

  Routes (added to router.ex scope "/api/v1"):
    GET  /tools                  — list all tools (filter by requires, mcp_exposed)
    GET  /tools/:name            — detail for a single tool
    POST /tools/:name/dispatch   — execute a tool handler (testing/debugging)
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Tools
  alias CanopyWeb.Schemas.ToolSchema

  action_fallback CanopyWeb.FallbackController

  tags ["tools"]

  # ---------------------------------------------------------------------------
  # GET /api/v1/tools
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List registered tools",
    description: """
    Returns all tools in the registry. Supports optional query parameters for
    filtering by capability requirements and exposure flags.
    """,
    parameters: [
      mcp_exposed: [
        in: :query,
        description: "Filter by MCP-exposed flag (true/false)",
        type: :boolean,
        required: false
      ],
      prompt_exposed: [
        in: :query,
        description: "Filter by prompt-exposed flag (true/false)",
        type: :boolean,
        required: false
      ]
    ],
    responses: [
      ok: {"Tool list", "application/json", ToolSchema.ToolList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    opts = build_filter_opts(params)
    tools = Tools.list(opts)
    json(conn, %{data: Enum.map(tools, &serialize_tool/1)})
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/tools/:name
  # ---------------------------------------------------------------------------

  operation :show,
    summary: "Get a single tool",
    description: "Returns full detail for a tool registered under the given name.",
    parameters: [
      name: [
        in: :path,
        description: "Tool name, e.g. \"read_file\"",
        type: :string,
        required: true
      ]
    ],
    responses: [
      ok: {"Tool detail", "application/json", ToolSchema.Tool},
      not_found: {"Not found", "application/json", ToolSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"name" => name}) do
    case Canopy.Tools.Registry.lookup(name) do
      {:ok, tool} -> json(conn, serialize_tool(tool))
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/tools/:name/dispatch
  # ---------------------------------------------------------------------------

  operation :dispatch,
    summary: "Dispatch a tool by name",
    description: """
    Executes a registered tool handler with the given args map. Intended for
    debugging and integration testing — not exposed to end-users in production.
    """,
    parameters: [
      name: [in: :path, description: "Tool name", type: :string, required: true]
    ],
    request_body: {"Dispatch args", "application/json", ToolSchema.DispatchRequest},
    responses: [
      ok: {"Dispatch result", "application/json", ToolSchema.DispatchResponse},
      not_found: {"Tool not found", "application/json", ToolSchema.ErrorResponse},
      unprocessable_entity: {"Handler error", "application/json", ToolSchema.ErrorResponse}
    ]

  @spec dispatch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dispatch(conn, %{"name" => name, "args" => args}) when is_map(args) do
    case Tools.dispatch(name, args) do
      {:ok, result} ->
        json(conn, %{result: result})

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "dispatch_failed", message: inspect(reason)})
    end
  end

  def dispatch(_, _), do: {:error, :bad_request}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec serialize_tool(Canopy.Tools.Tool.t()) :: map()
  defp serialize_tool(tool) do
    %{
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters,
      requires: Enum.map(tool.requires, &to_string/1),
      mcp_exposed: tool.mcp_exposed,
      prompt_exposed: tool.prompt_exposed
    }
  end

  @spec build_filter_opts(map()) :: keyword()
  defp build_filter_opts(params) do
    opts = []

    opts =
      case Map.get(params, "mcp_exposed") do
        "true" -> Keyword.put(opts, :mcp_exposed, true)
        "false" -> Keyword.put(opts, :mcp_exposed, false)
        _ -> opts
      end

    case Map.get(params, "prompt_exposed") do
      "true" -> Keyword.put(opts, :prompt_exposed, true)
      "false" -> Keyword.put(opts, :prompt_exposed, false)
      _ -> opts
    end
  end
end
