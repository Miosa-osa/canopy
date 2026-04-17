defmodule CanopyWeb.Schemas.AgentSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Agent resource.

  These are API contract schemas for `/api/v1/agents`. Distinct from Ecto schemas.
  """

  alias OpenApiSpex.Schema

  defmodule Agent do
    @moduledoc "A Canopy agent persona."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Agent",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string, description: "Stable URL-safe identifier"},
        category: %Schema{type: :string, description: "Agent category, e.g. engineering"},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        persona_path: %Schema{
          type: :string,
          description: "Path relative to priv/agents/"
        },
        default_runtime: %Schema{type: :string, nullable: true},
        default_model: %Schema{type: :string, nullable: true},
        heartbeat_cron: %Schema{
          type: :string,
          nullable: true,
          description: "Cron expression for scheduled heartbeats"
        },
        budget_monthly_usd: %Schema{
          type: :string,
          nullable: true,
          description: "Monthly budget cap in USD"
        },
        hired: %Schema{type: :boolean, description: "Whether the user has opted in"},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :category, :name, :persona_path, :hired]
    })
  end

  defmodule AgentList do
    @moduledoc "A list of agents."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AgentList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Agent}
      },
      required: [:data]
    })
  end
end
