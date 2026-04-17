defmodule CanopyWeb.ApiSpec do
  @moduledoc """
  OpenAPI 3.1 specification for the Canopy HTTP API.

  This module implements the `OpenApiSpex.OpenApi` behaviour. The spec is
  generated at compile time from controller annotations (schemas, operations)
  and served at `/api/v1/openapi`.

  The TypeScript types package (`packages/types/`) is generated from this spec
  via `pnpm gen:types` — do not hand-write types in the frontend.

  Week 1 additions:
  - Schema modules for RuntimeAdapter, Session, Agent, Workspace
  - Operation annotations on each controller action
  - Response schema for all error types (404, 422, 501, etc.)
  """

  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Canopy API",
        description: """
        HTTP API for the Canopy runtime management platform.
        Manages AI runtimes, agent sessions, workspaces, and MIOSA sandboxes.
        """,
        version: Application.spec(:canopy, :vsn) |> to_string()
      },
      servers: servers(),
      paths: Paths.from_router(CanopyWeb.Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp servers do
    case Application.get_env(:canopy, :environment, :dev) do
      :prod ->
        [%Server{url: "https://api.canopy.app", description: "Production"}]

      _env ->
        [%Server{url: "http://localhost:9190", description: "Local development"}]
    end
  end
end
