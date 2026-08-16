defmodule CanopyWeb.Schemas.SearchSchema do
  @moduledoc "OpenAPI schemas for `GET /api/v1/search`."

  alias OpenApiSpex.Schema

  defmodule SearchMatch do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SearchMatch",
      description: "A single line-level match within a workspace file.",
      type: :object,
      properties: %{
        file_path: %Schema{type: :string, description: "Path relative to the workspace root."},
        line_number: %Schema{type: :integer, minimum: 1},
        line_text: %Schema{
          type: :string,
          description: "The matching line, possibly truncated with an ellipsis if >500 chars."
        },
        match_start: %Schema{
          type: :integer,
          minimum: 0,
          description: "Byte offset of the match start within line_text."
        },
        match_end: %Schema{
          type: :integer,
          minimum: 0,
          description: "Byte offset of the match end (exclusive) within line_text."
        }
      },
      required: [:file_path, :line_number, :line_text, :match_start, :match_end]
    })
  end

  defmodule SearchResult do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SearchResult",
      description: "Workspace search response with backend metadata.",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: SearchMatch},
        backend: %Schema{
          type: :string,
          enum: ["ripgrep", "elixir"],
          description: "Which backend served the request."
        },
        elapsed_ms: %Schema{
          type: :integer,
          minimum: 0,
          description: "Wall-clock time spent in the backend, in milliseconds."
        },
        truncated: %Schema{
          type: :boolean,
          description: "True if any returned line_text was truncated (>500 chars)."
        }
      },
      required: [:data, :backend, :elapsed_ms, :truncated]
    })
  end

  # Kept for symmetry with sibling schema files; some clients reference this name.
  defmodule SearchResultList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SearchResultList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: SearchMatch}
      },
      required: [:data]
    })
  end
end
