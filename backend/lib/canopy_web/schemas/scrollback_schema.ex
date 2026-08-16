defmodule CanopyWeb.Schemas.ScrollbackSchema do
  @moduledoc "OpenAPISpex schema for the scrollback endpoint."

  alias OpenApiSpex.Schema

  defmodule ScrollbackResponse do
    @moduledoc "Response body for GET /api/v1/sessions/:id/scrollback"

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ScrollbackResponse",
      type: :object,
      required: [:session_id, :data, :offset, :total_bytes, :truncated],
      properties: %{
        session_id: %Schema{type: :string, format: :uuid, description: "Session identifier"},
        data: %Schema{
          type: :string,
          description: "Raw ANSI bytes, base64-encoded when binary-unsafe"
        },
        offset: %Schema{
          type: :integer,
          description: "Current tail offset in bytes — pass as `from` on next poll"
        },
        total_bytes: %Schema{type: :integer, description: "Total bytes currently in the log"},
        truncated: %Schema{
          type: :boolean,
          description: "True when the log has been rotated and head bytes were dropped"
        }
      }
    })
  end
end
