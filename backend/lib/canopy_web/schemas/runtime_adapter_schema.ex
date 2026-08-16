defmodule CanopyWeb.Schemas.RuntimeAdapterSchema do
  @moduledoc "OpenAPI schemas for the Runtime Adapter Agent surface."

  alias OpenApiSpex.Schema

  defmodule ModelInfo do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        max_tokens: %Schema{type: :integer, nullable: true},
        context_window: %Schema{type: :integer, nullable: true},
        supports_images: %Schema{type: :boolean},
        supports_prompt_cache: %Schema{type: :boolean},
        supports_reasoning: %Schema{type: :boolean},
        input_price: %Schema{type: :string, nullable: true},
        output_price: %Schema{type: :string, nullable: true},
        cache_writes_price: %Schema{type: :string, nullable: true},
        cache_reads_price: %Schema{type: :string, nullable: true},
        tiers: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              name: %Schema{type: :string},
              threshold_tokens: %Schema{type: :integer},
              multiplier: %Schema{type: :string}
            }
          }
        }
      }
    })
  end

  defmodule Model do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        model_id: %Schema{type: :string},
        display_name: %Schema{type: :string, nullable: true},
        is_default: %Schema{type: :boolean},
        info: ModelInfo
      }
    })
  end

  defmodule ModelList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        runtime_id: %Schema{type: :string},
        models: %Schema{type: :array, items: Model}
      }
    })
  end

  defmodule Checkpoint do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        session_id: %Schema{type: :string, format: :uuid},
        runtime: %Schema{type: :string},
        label: %Schema{type: :string, nullable: true},
        captured_at: %Schema{type: :string, format: :"date-time"},
        code_hash: %Schema{type: :string, nullable: true},
        transcript_id: %Schema{type: :string, format: :uuid, nullable: true},
        transcript_sequence: %Schema{type: :integer, nullable: true},
        agent_memory: %Schema{type: :object, additionalProperties: true},
        parent_checkpoint_id: %Schema{type: :string, format: :uuid, nullable: true},
        workspace_slug: %Schema{type: :string, nullable: true},
        created_by_agent_id: %Schema{type: :string, format: :uuid, nullable: true},
        restored_at: %Schema{type: :string, format: :"date-time", nullable: true},
        metadata: %Schema{type: :object, additionalProperties: true}
      },
      required: [:id, :session_id, :runtime, :captured_at]
    })
  end

  defmodule CheckpointList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        session_id: %Schema{type: :string, format: :uuid},
        count: %Schema{type: :integer},
        data: %Schema{type: :array, items: Checkpoint}
      }
    })
  end

  defmodule CheckpointCreate do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        session_id: %Schema{type: :string, format: :uuid},
        runtime: %Schema{type: :string},
        label: %Schema{type: :string},
        code_hash: %Schema{type: :string},
        transcript_id: %Schema{type: :string, format: :uuid},
        transcript_sequence: %Schema{type: :integer},
        agent_memory: %Schema{type: :object, additionalProperties: true},
        workspace_slug: %Schema{type: :string}
      },
      required: [:session_id, :runtime]
    })
  end

  defmodule ModelRole do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        runtime: %Schema{type: :string},
        model: %Schema{type: :string},
        role: %Schema{
          type: :string,
          enum: ["chat", "autocomplete", "edit", "apply", "embed", "rerank", "summarize"]
        },
        default_for_role: %Schema{type: :boolean},
        priority: %Schema{type: :integer},
        workspace_slug: %Schema{type: :string, nullable: true},
        metadata: %Schema{type: :object, additionalProperties: true}
      }
    })
  end

  defmodule ModelRoleList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: ModelRole}
      }
    })
  end

  defmodule RoleAssignment do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        runtime: %Schema{type: :string},
        model: %Schema{type: :string},
        role: %Schema{type: :string},
        default_for_role: %Schema{type: :boolean},
        priority: %Schema{type: :integer},
        workspace_slug: %Schema{type: :string}
      },
      required: [:runtime, :model, :role]
    })
  end

  defmodule Suggestion do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        runtime_id: %Schema{type: :string},
        score: %Schema{type: :number, format: :float},
        reason: %Schema{type: :string}
      }
    })
  end

  defmodule SuggestionList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        count: %Schema{type: :integer},
        suggestions: %Schema{type: :array, items: Suggestion}
      }
    })
  end

  defmodule SwapRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        session_id: %Schema{type: :string, format: :uuid},
        current_runtime: %Schema{type: :string},
        target_runtime: %Schema{type: :string},
        agent_id: %Schema{type: :string, format: :uuid}
      },
      required: [:session_id, :current_runtime, :target_runtime]
    })
  end
end
