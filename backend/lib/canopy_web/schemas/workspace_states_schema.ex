defmodule CanopyWeb.Schemas.WorkspaceStatesSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the per-workspace state store.

  These are API contract schemas for `/api/v1/workspaces/:slug/state*`.
  Distinct from the Ecto schema in `Canopy.Workspaces.State`.
  """

  alias OpenApiSpex.Schema

  defmodule StateValue do
    @moduledoc "Container for a single state value. The shape of `value` is module-defined."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WorkspaceStateValue",
      type: :object,
      properties: %{
        key: %Schema{type: :string, description: "State key (namespaced, e.g. 'mosaic.layout')"},
        value: %Schema{
          description: "Arbitrary JSON-encodable value (object/array/scalar). Capped at 1 MB.",
          nullable: true
        },
        updated_at: %Schema{type: :string, format: :"date-time", nullable: true}
      },
      required: [:value]
    })
  end

  defmodule StateMap do
    @moduledoc "All key/value entries for a single workspace as a map."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WorkspaceStateMap",
      type: :object,
      properties: %{
        workspace_slug: %Schema{type: :string},
        data: %Schema{
          type: :object,
          additionalProperties: true,
          description: "Map of `key` → arbitrary JSON-encodable value"
        }
      },
      required: [:workspace_slug, :data]
    })
  end

  defmodule StatePutBody do
    @moduledoc "Request body for PUT /workspaces/:slug/state/:key."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WorkspaceStatePutBody",
      type: :object,
      properties: %{
        value: %Schema{
          description: "Arbitrary JSON-encodable value to persist. Capped at 1 MB.",
          nullable: true
        }
      },
      required: [:value]
    })
  end

  defmodule StateDeleteResponse do
    @moduledoc "Response confirming deletion of a single state entry."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WorkspaceStateDeleteResponse",
      type: :object,
      properties: %{
        deleted: %Schema{type: :boolean},
        workspace_slug: %Schema{type: :string},
        key: %Schema{type: :string}
      },
      required: [:deleted, :workspace_slug, :key]
    })
  end
end
