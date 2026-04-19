defmodule CanopyWeb.Schemas.MiosaSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the MIOSA integration resource.

  API contract schemas for `/api/v1/miosa` and `/api/v1/settings/miosa`.
  """

  alias OpenApiSpex.Schema

  defmodule MiosaHealth do
    @moduledoc "MIOSA reachability probe result."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MiosaHealth",
      type: :object,
      properties: %{
        configured: %Schema{
          type: :boolean,
          description: "True when MIOSA_API_URL and MIOSA_API_KEY are both set"
        },
        reachable: %Schema{
          type: :boolean,
          nullable: true,
          description: "True when the MIOSA health endpoint responded. Null when not configured."
        },
        latency_ms: %Schema{
          type: :integer,
          nullable: true,
          description:
            "Round-trip latency in milliseconds. Null when not configured or unreachable."
        },
        error: %Schema{
          type: :string,
          nullable: true,
          description: "Transport error detail when reachable is false."
        }
      },
      required: [:configured, :reachable, :latency_ms, :error]
    })
  end

  defmodule MiosaConfig do
    @moduledoc "MIOSA configuration shape returned by GET /miosa."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MiosaConfig",
      type: :object,
      properties: %{
        api_url: %Schema{type: :string, description: "MIOSA API base URL"},
        api_key_masked: %Schema{
          type: :string,
          description: "API key with all but prefix redacted (e.g. sk-abc1...****)"
        },
        configured: %Schema{
          type: :boolean,
          description: "True when both api_url and api_key are non-empty"
        }
      },
      required: [:api_url, :api_key_masked, :configured]
    })
  end

  defmodule MiosaUpdateBody do
    @moduledoc "Request body for PUT /settings/miosa."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MiosaUpdateBody",
      type: :object,
      properties: %{
        api_url: %Schema{type: :string, description: "MIOSA API base URL"},
        api_key: %Schema{type: :string, description: "MIOSA API key (stored in application env)"}
      },
      required: [:api_url]
    })
  end
end
