defmodule CanopyWeb.Schemas.AnalyticsSchema do
  @moduledoc "OpenAPI schemas for the Analytics super-module."

  alias OpenApiSpex.Schema

  defmodule TelemetryEvent do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        ts: %Schema{type: :string, format: :"date-time"},
        event: %Schema{type: :string},
        run_id: %Schema{type: :string, format: :uuid, nullable: true},
        session_id: %Schema{type: :string, format: :uuid, nullable: true},
        agent_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        runtime: %Schema{type: :string, nullable: true},
        model: %Schema{type: :string, nullable: true},
        duration_ms: %Schema{type: :integer, nullable: true},
        cost_cents: %Schema{type: :integer, nullable: true},
        status: %Schema{type: :string, nullable: true},
        payload: %Schema{type: :object, additionalProperties: true}
      },
      required: [:id, :ts, :event]
    })
  end

  defmodule TelemetryList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: TelemetryEvent}
      }
    })
  end

  defmodule CostBucket do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        bucket: %Schema{type: :string, format: :"date-time"},
        cost_cents: %Schema{type: :integer},
        count: %Schema{type: :integer}
      }
    })
  end

  defmodule CostBuckets do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        granularity: %Schema{type: :string},
        rows: %Schema{type: :array, items: CostBucket}
      }
    })
  end

  defmodule Breadcrumb do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        run_id: %Schema{type: :string, format: :uuid},
        session_id: %Schema{type: :string, format: :uuid, nullable: true},
        sequence: %Schema{type: :integer},
        ts: %Schema{type: :string, format: :"date-time"},
        type: %Schema{type: :string},
        category: %Schema{type: :string, nullable: true},
        level: %Schema{type: :string},
        message: %Schema{type: :string, nullable: true},
        data: %Schema{type: :object, additionalProperties: true}
      }
    })
  end

  defmodule BreadcrumbList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        run_id: %Schema{type: :string, format: :uuid},
        count: %Schema{type: :integer},
        data: %Schema{type: :array, items: Breadcrumb}
      }
    })
  end

  defmodule Insight do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        title: %Schema{type: :string},
        body: %Schema{type: :string},
        severity: %Schema{type: :string},
        kind: %Schema{type: :string},
        metric: %Schema{type: :string, nullable: true},
        detected_at: %Schema{type: :string, format: :"date-time"},
        window_start: %Schema{type: :string, format: :"date-time", nullable: true},
        window_end: %Schema{type: :string, format: :"date-time", nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        created_by_agent_id: %Schema{type: :string, format: :uuid, nullable: true},
        related_run_id: %Schema{type: :string, format: :uuid, nullable: true},
        related_session_id: %Schema{type: :string, format: :uuid, nullable: true},
        acknowledged_at: %Schema{type: :string, format: :"date-time", nullable: true},
        acknowledged_by: %Schema{type: :string, nullable: true},
        feedback: %Schema{type: :string, nullable: true},
        dashboards: %Schema{type: :array, items: %Schema{type: :string}},
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        query: %Schema{type: :object, additionalProperties: true},
        result: %Schema{type: :object, additionalProperties: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule InsightList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Insight}
      }
    })
  end

  defmodule Alert do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        metric: %Schema{type: :string},
        type: %Schema{type: :string},
        config: %Schema{type: :object, additionalProperties: true},
        routing: %Schema{type: :object, additionalProperties: true},
        enabled: %Schema{type: :boolean},
        severity: %Schema{type: :string},
        sensitivity: %Schema{type: :number, format: :float},
        workspace_slug: %Schema{type: :string, nullable: true},
        last_evaluated_at: %Schema{type: :string, format: :"date-time", nullable: true},
        last_fired_at: %Schema{type: :string, format: :"date-time", nullable: true},
        fire_count: %Schema{type: :integer},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule AlertList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Alert}
      }
    })
  end

  defmodule InsightCreate do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        title: %Schema{type: :string},
        body: %Schema{type: :string},
        severity: %Schema{type: :string},
        kind: %Schema{type: :string},
        metric: %Schema{type: :string},
        detected_at: %Schema{type: :string, format: :"date-time"},
        workspace_slug: %Schema{type: :string},
        related_run_id: %Schema{type: :string, format: :uuid},
        related_session_id: %Schema{type: :string, format: :uuid},
        tags: %Schema{type: :array, items: %Schema{type: :string}}
      },
      required: [:slug, :title, :body, :detected_at]
    })
  end

  defmodule AlertCreate do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string},
        metric: %Schema{type: :string},
        type: %Schema{type: :string},
        config: %Schema{type: :object, additionalProperties: true},
        routing: %Schema{type: :object, additionalProperties: true},
        enabled: %Schema{type: :boolean},
        severity: %Schema{type: :string},
        sensitivity: %Schema{type: :number, format: :float},
        workspace_slug: %Schema{type: :string}
      },
      required: [:slug, :name, :metric, :type]
    })
  end
end
