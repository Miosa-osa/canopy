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

  defmodule AgentDetail do
    @moduledoc "An agent with optional persona markdown content."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AgentDetail",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        category: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        persona_path: %Schema{type: :string},
        persona_content: %Schema{
          type: :string,
          nullable: true,
          description: "Raw markdown content of the persona file (nil if file not found)"
        },
        default_runtime: %Schema{type: :string, nullable: true},
        default_model: %Schema{type: :string, nullable: true},
        heartbeat_cron: %Schema{type: :string, nullable: true},
        budget_monthly_usd: %Schema{type: :string, nullable: true},
        hired: %Schema{type: :boolean},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :category, :name, :persona_path, :hired]
    })
  end

  defmodule UpdatePersonaRequest do
    @moduledoc "Request body for PUT /api/v1/agents/:slug/persona."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UpdatePersonaRequest",
      type: :object,
      properties: %{
        persona_markdown: %Schema{
          type: :string,
          description: "Full markdown content to write to the agent persona file"
        }
      },
      required: [:persona_markdown]
    })
  end

  defmodule HireResponse do
    @moduledoc "Response after hiring or firing an agent."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HireResponse",
      type: :object,
      properties: %{
        data: Agent
      },
      required: [:data]
    })
  end

  defmodule HeartbeatEntry do
    @moduledoc "A single scheduled Oban heartbeat job for an agent."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HeartbeatEntry",
      type: :object,
      properties: %{
        id: %Schema{type: :integer, description: "Oban job ID"},
        state: %Schema{type: :string, description: "Job state: scheduled | available"},
        scheduled_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the job is scheduled to fire"
        },
        args: %Schema{type: :object, description: "Job arguments including agent_slug"},
        attempt: %Schema{type: :integer},
        max_attempts: %Schema{type: :integer}
      },
      required: [:id, :state, :scheduled_at, :args]
    })
  end

  defmodule HeartbeatList do
    @moduledoc "A list of upcoming heartbeat jobs for an agent."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HeartbeatList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: HeartbeatEntry}
      },
      required: [:data]
    })
  end
end
