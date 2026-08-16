defmodule CanopyWeb.Schemas.ScheduleSchema do
  @moduledoc "OpenAPI schemas for the Schedule super-module."

  alias OpenApiSpex.Schema

  defmodule Spec do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        agent_id: %Schema{type: :string, format: :uuid, nullable: true},
        agent_slug: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        model: %Schema{type: :object, additionalProperties: true},
        timezone: %Schema{type: :string},
        overlap_policy: %Schema{type: :string},
        jitter_seconds: %Schema{type: :integer},
        grace_seconds: %Schema{type: :integer},
        failure_threshold: %Schema{type: :integer},
        concurrency_key: %Schema{type: :string, nullable: true},
        start_at: %Schema{type: :string, format: :"date-time", nullable: true},
        end_at: %Schema{type: :string, format: :"date-time", nullable: true},
        next_fire_at: %Schema{type: :string, format: :"date-time", nullable: true},
        last_fire_at: %Schema{type: :string, format: :"date-time", nullable: true},
        status: %Schema{type: :string},
        paused_reason: %Schema{type: :string, nullable: true},
        paused_at: %Schema{type: :string, format: :"date-time", nullable: true},
        consecutive_failures: %Schema{type: :integer},
        run_count: %Schema{type: :integer},
        error_count: %Schema{type: :integer},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :name]
    })
  end

  defmodule SpecList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{data: %Schema{type: :array, items: Spec}}
    })
  end

  defmodule SpecCreate do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string},
        agent_slug: %Schema{type: :string},
        workspace_slug: %Schema{type: :string},
        model: %Schema{type: :object, additionalProperties: true},
        timezone: %Schema{type: :string},
        overlap_policy: %Schema{
          type: :string,
          enum: ["skip", "buffer_one", "cancel_other", "terminate_other"]
        },
        jitter_seconds: %Schema{type: :integer},
        grace_seconds: %Schema{type: :integer},
        failure_threshold: %Schema{type: :integer},
        concurrency_key: %Schema{type: :string},
        start_at: %Schema{type: :string, format: :"date-time"},
        end_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:slug, :name]
    })
  end

  defmodule SpecUpdate do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        description: %Schema{type: :string},
        model: %Schema{type: :object, additionalProperties: true},
        timezone: %Schema{type: :string},
        overlap_policy: %Schema{type: :string},
        jitter_seconds: %Schema{type: :integer},
        grace_seconds: %Schema{type: :integer},
        failure_threshold: %Schema{type: :integer},
        concurrency_key: %Schema{type: :string}
      }
    })
  end

  defmodule Run do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        spec_id: %Schema{type: :string, format: :uuid},
        spec_slug: %Schema{type: :string, nullable: true},
        agent_slug: %Schema{type: :string, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        scheduled_at: %Schema{type: :string, format: :"date-time"},
        fired_at: %Schema{type: :string, format: :"date-time", nullable: true},
        completed_at: %Schema{type: :string, format: :"date-time", nullable: true},
        status: %Schema{type: :string},
        lateness_ms: %Schema{type: :integer, nullable: true},
        duration_ms: %Schema{type: :integer, nullable: true},
        attempt: %Schema{type: :integer},
        session_id: %Schema{type: :string, format: :uuid, nullable: true},
        run_id: %Schema{type: :string, format: :uuid, nullable: true},
        payload: %Schema{type: :object, additionalProperties: true},
        error_class: %Schema{type: :string, nullable: true},
        error_message: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule RunList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{data: %Schema{type: :array, items: Run}}
    })
  end

  defmodule RunBucket do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        bucket: %Schema{type: :string, format: :"date-time"},
        total: %Schema{type: :integer},
        succeeded: %Schema{type: :integer},
        failed: %Schema{type: :integer},
        missed: %Schema{type: :integer},
        late: %Schema{type: :integer}
      }
    })
  end

  defmodule RunBuckets do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        granularity: %Schema{type: :string},
        rows: %Schema{type: :array, items: RunBucket}
      }
    })
  end

  defmodule Overlap do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        spec_id: %Schema{type: :string, format: :uuid},
        spec_slug: %Schema{type: :string, nullable: true},
        running_run_id: %Schema{type: :string, format: :uuid},
        incoming_run_id: %Schema{type: :string, format: :uuid},
        gap_seconds: %Schema{type: :integer},
        detected_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule OverlapList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{data: %Schema{type: :array, items: Overlap}}
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
        spec_id: %Schema{type: :string, format: :uuid, nullable: true},
        spec_slug: %Schema{type: :string, nullable: true},
        category: %Schema{type: :string},
        severity: %Schema{type: :string},
        status: %Schema{type: :string},
        summary: %Schema{type: :string},
        detail: %Schema{type: :string, nullable: true},
        first_seen_at: %Schema{type: :string, format: :"date-time"},
        last_seen_at: %Schema{type: :string, format: :"date-time"},
        closed_at: %Schema{type: :string, format: :"date-time", nullable: true},
        acknowledged_at: %Schema{type: :string, format: :"date-time", nullable: true},
        acknowledged_by: %Schema{type: :string, nullable: true},
        failure_count: %Schema{type: :integer},
        related_run_ids: %Schema{type: :array, items: %Schema{type: :string, format: :uuid}},
        workspace_slug: %Schema{type: :string, nullable: true},
        resolution_note: %Schema{type: :string, nullable: true},
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
      properties: %{data: %Schema{type: :array, items: Alert}}
    })
  end

  defmodule AlertCreate do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        spec_slug: %Schema{type: :string},
        category: %Schema{
          type: :string,
          enum: [
            "miss",
            "late",
            "failure",
            "circuit_breaker",
            "overlap",
            "calendar_sync",
            "schedule_conflict"
          ]
        },
        severity: %Schema{type: :string},
        summary: %Schema{type: :string},
        detail: %Schema{type: :string},
        workspace_slug: %Schema{type: :string}
      },
      required: [:slug, :category, :summary]
    })
  end
end
