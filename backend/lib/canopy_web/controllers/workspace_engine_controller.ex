defmodule CanopyWeb.WorkspaceEngineController do
  @moduledoc """
  HTTP API for workspace-local OptimalEngine execution.
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Workspaces.Engine

  action_fallback CanopyWeb.FallbackController

  tags ["workspace-engine"]

  operation :health,
    summary: "Workspace engine health",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Engine health", "application/json", %OpenApiSpex.Schema{type: :object}}]

  def health(conn, %{"slug" => slug}) do
    with {:ok, result} <- Engine.health(slug) do
      json(conn, %{data: result})
    end
  end

  operation :commands,
    summary: "List workspace engine commands",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Engine commands", "application/json", %OpenApiSpex.Schema{type: :object}}]

  def commands(conn, %{"slug" => slug}) do
    case Engine.list_commands(slug) do
      {:ok, commands} ->
        json(conn, %{data: %{commands: commands, count: length(commands)}})

      {:error, reason} ->
        render_engine_error(conn, reason)
    end
  end

  operation :run,
    summary: "Run a workspace engine command",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Run command", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [ok: {"Engine result", "application/json", %OpenApiSpex.Schema{type: :object}}]

  def run(conn, %{"slug" => slug, "command" => command} = params) do
    case Engine.run(slug, command, Map.get(params, "args", []),
           timeout_ms: Map.get(params, "timeout_ms")
         ) do
      {:ok, result} -> json(conn, %{data: result})
      {:error, reason} -> render_engine_error(conn, reason)
    end
  end

  def run(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "command is required"})
  end

  defp render_engine_error(_conn, :not_found), do: {:error, :not_found}

  defp render_engine_error(conn, reason) do
    {status, error} =
      case reason do
        {:engine_incompatible, _} -> {:unprocessable_entity, "engine_incompatible"}
        :engine_not_found -> {:not_found, "engine_not_found"}
        :mix_project_not_found -> {:unprocessable_entity, "mix_project_not_found"}
        :manifest_not_found -> {:unprocessable_entity, "manifest_not_found"}
        :command_not_allowed -> {:unprocessable_entity, "command_not_allowed"}
        :invalid_arg -> {:bad_request, "invalid_arg"}
        :arg_too_large -> {:bad_request, "arg_too_large"}
        :invalid_timeout -> {:bad_request, "invalid_timeout"}
        :timeout_too_large -> {:bad_request, "timeout_too_large"}
        {:execution_failed, _} -> {:unprocessable_entity, "execution_failed"}
        _ -> {:unprocessable_entity, "engine_error"}
      end

    conn
    |> put_status(status)
    |> json(%{error: error, message: inspect(reason)})
  end
end
