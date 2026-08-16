defmodule CanopyWeb.Schemas.DriveSchema do
  @moduledoc "OpenAPI schemas for the Drive super-module."

  alias OpenApiSpex.Schema

  defmodule Entry do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        kind: %Schema{
          type: :string,
          enum: ~w(folder workflow prompt notebook env_vars mcp_server rule)
        },
        scope: %Schema{type: :string, enum: ~w(personal team)},
        parent_id: %Schema{type: :string, format: :uuid, nullable: true},
        body: %Schema{type: :object, additionalProperties: true},
        owner_id: %Schema{type: :string, format: :uuid, nullable: true},
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        position: %Schema{type: :integer},
        archived_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :name, :kind, :scope]
    })
  end

  defmodule EntryList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Entry}
      }
    })
  end

  defmodule EntryCreate do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        kind: %Schema{
          type: :string,
          enum: ~w(folder workflow prompt notebook env_vars mcp_server rule)
        },
        scope: %Schema{type: :string, enum: ~w(personal team)},
        parent_id: %Schema{type: :string, format: :uuid, nullable: true},
        body: %Schema{type: :object, additionalProperties: true},
        tags: %Schema{type: :array, items: %Schema{type: :string}}
      },
      required: [:slug, :name, :kind, :scope]
    })
  end

  defmodule EntryUpdate do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        body: %Schema{type: :object, additionalProperties: true},
        tags: %Schema{type: :array, items: %Schema{type: :string}}
      }
    })
  end

  defmodule MoveBody do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        parent_id: %Schema{
          type: :string,
          format: :uuid,
          nullable: true,
          description: "Target folder id, or null for root"
        }
      }
    })
  end

  defmodule ReorderBody do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        ids: %Schema{
          type: :array,
          items: %Schema{type: :string, format: :uuid},
          description: "Array of entry ids in their new order"
        }
      },
      required: [:ids]
    })
  end

  defmodule ReorderResult do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule TreeNode do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        entry: Entry,
        children: %Schema{
          type: :array,
          items: %Schema{type: :object, additionalProperties: true}
        }
      }
    })
  end

  defmodule Tree do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        scope: %Schema{type: :string},
        data: %Schema{type: :array, items: TreeNode}
      }
    })
  end
end
