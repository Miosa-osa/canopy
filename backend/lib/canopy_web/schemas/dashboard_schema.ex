defmodule CanopyWeb.Schemas.DashboardSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Dashboard resource.

  These are API contract schemas for `/api/v1/dashboard/*`.
  """

  alias OpenApiSpex.Schema

  defmodule WidgetInstance do
    @moduledoc "A single widget instance in a layout (position + config)."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WidgetInstance",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Unique instance ID within the layout"},
        type: %Schema{type: :string, description: "Widget type atom (e.g. active_agents)"},
        x: %Schema{type: :integer, description: "Column offset (12-column grid)"},
        y: %Schema{type: :integer, description: "Row offset"},
        w: %Schema{type: :integer, description: "Width in columns"},
        h: %Schema{type: :integer, description: "Height in rows"},
        config: %Schema{
          type: :object,
          additionalProperties: true,
          description: "Widget-specific config"
        }
      },
      required: [:id, :type, :x, :y, :w, :h]
    })
  end

  defmodule LayoutResponse do
    @moduledoc "Dashboard layout — list of widget instances."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "LayoutResponse",
      type: :object,
      properties: %{
        layout: %Schema{
          type: :array,
          items: WidgetInstance,
          description: "Ordered array of widget instances"
        }
      },
      required: [:layout]
    })
  end

  defmodule SaveLayoutRequest do
    @moduledoc "Request body for PUT /dashboard/layout."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SaveLayoutRequest",
      type: :object,
      properties: %{
        layout: %Schema{
          type: :array,
          items: WidgetInstance,
          description: "Widget layout to persist"
        }
      },
      required: [:layout]
    })
  end

  defmodule WidgetTypeItem do
    @moduledoc "A single available widget type."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WidgetTypeItem",
      type: :object,
      properties: %{
        type: %Schema{type: :string, description: "Widget type atom"},
        label: %Schema{type: :string, description: "Human-readable label"}
      },
      required: [:type, :label]
    })
  end

  defmodule WidgetTypesResponse do
    @moduledoc "List of available widget types for the picker."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WidgetTypesResponse",
      type: :object,
      properties: %{
        widgets: %Schema{
          type: :array,
          items: WidgetTypeItem
        }
      },
      required: [:widgets]
    })
  end

  defmodule SummaryResponse do
    @moduledoc "Full dashboard summary — all default widget payloads in one response."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SummaryResponse",
      type: :object,
      description: "Map of widget_type => payload. Keys depend on user's active widgets.",
      additionalProperties: true
    })
  end

  defmodule WidgetResponse do
    @moduledoc "Single widget payload response."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WidgetResponse",
      type: :object,
      properties: %{
        widget: %Schema{type: :string, description: "Widget type name"},
        data: %Schema{
          type: :object,
          additionalProperties: true,
          description: "Widget-specific payload"
        }
      },
      required: [:widget, :data]
    })
  end
end
