defmodule CanopyWeb.Schemas.BlocksSchema do
  @moduledoc "OpenAPI schemas for the Block primitive."

  alias OpenApiSpex.Schema

  defmodule Block do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        session_id: %Schema{type: :string, format: :uuid},
        parent_block_id: %Schema{type: :string, format: :uuid, nullable: true},
        sequence: %Schema{type: :integer},
        kind: %Schema{
          type: :string,
          enum: ~w(command agent_message tool_call tool_result approval diff system_event error)
        },
        status: %Schema{
          type: :string,
          enum: ~w(running completed failed cancelled pending_approval)
        },
        input_text: %Schema{type: :string, nullable: true},
        output_text: %Schema{type: :string, nullable: true},
        exit_code: %Schema{type: :integer, nullable: true},
        started_at: %Schema{type: :string, format: :"date-time", nullable: true},
        ended_at: %Schema{type: :string, format: :"date-time", nullable: true},
        duration_ms: %Schema{type: :integer, nullable: true},
        cost_cents: %Schema{type: :integer, nullable: true},
        metadata: %Schema{type: :object, additionalProperties: true},
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :session_id, :sequence, :kind, :status]
    })
  end

  defmodule BlockList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        session_id: %Schema{type: :string, format: :uuid},
        count: %Schema{type: :integer},
        data: %Schema{type: :array, items: Block}
      }
    })
  end

  defmodule BlockSearchResult do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        session_id: %Schema{type: :string, format: :uuid},
        count: %Schema{type: :integer},
        data: %Schema{type: :array, items: Block}
      }
    })
  end
end
