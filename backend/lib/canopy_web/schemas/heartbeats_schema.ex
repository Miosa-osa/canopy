defmodule CanopyWeb.Schemas.HeartbeatsSchema do
  @moduledoc "OpenAPI schemas for the Heartbeats and Activity APIs."

  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule HeartbeatDetail do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "HeartbeatDetail",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        session_id: %Schema{type: :string, format: :uuid},
        kind: %Schema{
          type: :string,
          enum: ["output", "input", "error", "exit", "pause", "resume"]
        },
        byte_count: %Schema{type: :integer, minimum: 0},
        preview: %Schema{type: :string, nullable: true},
        meta: %Schema{type: :object, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule HeartbeatList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "HeartbeatList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: HeartbeatDetail},
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule SessionStats do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "SessionStats",
      type: :object,
      properties: %{
        session_id: %Schema{type: :string, format: :uuid},
        total_output_bytes: %Schema{type: :integer},
        total_input_bytes: %Schema{type: :integer},
        heartbeat_count: %Schema{type: :integer},
        started_at: %Schema{type: :string, format: :"date-time", nullable: true},
        last_activity_at: %Schema{type: :string, format: :"date-time", nullable: true}
      }
    })
  end

  defmodule ActivityItem do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ActivityItem",
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        type: %Schema{type: :string},
        session_id: %Schema{type: :string, format: :uuid, nullable: true},
        task_id: %Schema{type: :string, format: :uuid, nullable: true},
        issue_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string},
        actor_type: %Schema{type: :string, enum: ["agent", "human", "system"]},
        actor_id: %Schema{type: :string},
        title: %Schema{type: :string},
        preview: %Schema{type: :string, nullable: true},
        at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule ActivityFeed do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ActivityFeed",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: ActivityItem},
        count: %Schema{type: :integer}
      }
    })
  end
end
