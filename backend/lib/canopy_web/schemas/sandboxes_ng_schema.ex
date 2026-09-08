defmodule CanopyWeb.Schemas.SandboxesNgSchema do
  @moduledoc "OpenAPI schemas for the Sandboxes super-module (next-gen operator surface)."

  alias OpenApiSpex.Schema

  defmodule LifecycleEvent do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        sandbox_id: %Schema{type: :string},
        state: %Schema{type: :string},
        prior_state: %Schema{type: :string, nullable: true},
        reason: %Schema{type: :string, nullable: true},
        ts: %Schema{type: :string, format: :"date-time"},
        run_id: %Schema{type: :string, format: :uuid, nullable: true},
        session_id: %Schema{type: :string, format: :uuid, nullable: true},
        owner_agent_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        payload: %Schema{type: :object, additionalProperties: true},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :sandbox_id, :state, :ts]
    })
  end

  defmodule LifecycleEventList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: LifecycleEvent}
      }
    })
  end

  defmodule SandboxState do
    @moduledoc "Most-recent state row for a sandbox."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        sandbox_id: %Schema{type: :string},
        state: %Schema{type: :string},
        prior_state: %Schema{type: :string, nullable: true},
        ts: %Schema{type: :string, format: :"date-time"},
        owner_agent_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        reason: %Schema{type: :string, nullable: true},
        payload: %Schema{type: :object, additionalProperties: true}
      }
    })
  end

  defmodule SandboxStateList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: SandboxState}
      }
    })
  end

  defmodule Snapshot do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        sandbox_id: %Schema{type: :string},
        kind: %Schema{type: :string},
        name: %Schema{type: :string, nullable: true},
        image_uri: %Schema{type: :string, nullable: true},
        path: %Schema{type: :string, nullable: true},
        size_bytes: %Schema{type: :integer, nullable: true},
        parent_snapshot_id: %Schema{type: :string, format: :uuid, nullable: true},
        created_by_agent_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        retention_until: %Schema{type: :string, format: :"date-time", nullable: true},
        reaped_at: %Schema{type: :string, format: :"date-time", nullable: true},
        metadata: %Schema{type: :object, additionalProperties: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule SnapshotList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Snapshot}
      }
    })
  end

  defmodule SnapshotCreate do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        sandbox_id: %Schema{type: :string},
        kind: %Schema{type: :string, enum: ["filesystem", "directory", "memory"]},
        name: %Schema{type: :string},
        path: %Schema{type: :string},
        parent_snapshot_id: %Schema{type: :string, format: :uuid},
        workspace_slug: %Schema{type: :string}
      },
      required: [:slug, :sandbox_id, :kind]
    })
  end

  defmodule PortForward do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        sandbox_id: %Schema{type: :string},
        internal_port: %Schema{type: :integer},
        protocol: %Schema{type: :string},
        visibility: %Schema{type: :string},
        external_url: %Schema{type: :string, nullable: true},
        tcp_endpoint: %Schema{type: :string, nullable: true},
        label: %Schema{type: :string, nullable: true},
        process_name: %Schema{type: :string, nullable: true},
        opened_by_agent_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        access_token: %Schema{type: :string, nullable: true},
        closed_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule PortForwardList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: PortForward}
      }
    })
  end

  defmodule PortForwardCreate do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        sandbox_id: %Schema{type: :string},
        internal_port: %Schema{type: :integer},
        protocol: %Schema{type: :string, enum: ["http", "https", "tcp"]},
        visibility: %Schema{type: :string, enum: ["private", "token", "public"]},
        label: %Schema{type: :string},
        confirm_public: %Schema{type: :boolean},
        workspace_slug: %Schema{type: :string}
      },
      required: [:sandbox_id, :internal_port]
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
        type: %Schema{type: :string, enum: ["threshold", "composite"]},
        config: %Schema{type: :object, additionalProperties: true},
        routing: %Schema{type: :object, additionalProperties: true},
        enabled: %Schema{type: :boolean},
        severity: %Schema{type: :string, enum: ["info", "medium", "high", "critical"]},
        workspace_slug: %Schema{type: :string}
      },
      required: [:slug, :name, :metric, :type]
    })
  end
end
