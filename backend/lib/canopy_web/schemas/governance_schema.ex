defmodule CanopyWeb.Schemas.GovernanceSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Governance resource.

  API contract schemas for `/api/v1/governance/*`. Distinct from Ecto schemas.
  These are generated-type-safe contracts — the TypeScript layer reads the
  generated OpenAPI spec rather than hand-writing types.
  """

  alias OpenApiSpex.Schema

  defmodule GovernanceRule do
    @moduledoc "A governance rule that evaluates session context."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GovernanceRule",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        enabled: %Schema{type: :boolean},
        priority: %Schema{type: :integer, description: "Higher = evaluated first"},
        conditions: %Schema{
          type: :object,
          description:
            "Condition map — keys: runtime, agent_slug, workspace_slug, prompt_regex, cost_over"
        },
        action: %Schema{
          type: :string,
          enum: ["block", "require_approval", "warn", "log"]
        },
        audit_context: %Schema{type: :object, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :name, :enabled, :priority, :conditions, :action]
    })
  end

  defmodule GovernanceRuleList do
    @moduledoc "List of governance rules."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GovernanceRuleList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: GovernanceRule}
      },
      required: [:data]
    })
  end

  defmodule CreateRuleRequest do
    @moduledoc "Request body for creating a governance rule."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CreateGovernanceRuleRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        enabled: %Schema{type: :boolean},
        priority: %Schema{type: :integer},
        conditions: %Schema{type: :object},
        action: %Schema{type: :string, enum: ["block", "require_approval", "warn", "log"]},
        audit_context: %Schema{type: :object, nullable: true}
      },
      required: [:name, :action]
    })
  end

  defmodule GovernanceApproval do
    @moduledoc "A pending or resolved governance approval."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GovernanceApproval",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        rule_id: %Schema{type: :string, format: :uuid},
        session_id: %Schema{type: :string, format: :uuid},
        status: %Schema{type: :string, enum: ["pending", "approved", "rejected", "expired"]},
        requested_at: %Schema{type: :string, format: :"date-time"},
        decided_at: %Schema{type: :string, format: :"date-time", nullable: true},
        expires_at: %Schema{type: :string, format: :"date-time", nullable: true},
        decided_by: %Schema{type: :string, nullable: true},
        decision_reason: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :rule_id, :session_id, :status, :requested_at]
    })
  end

  defmodule GovernanceApprovalList do
    @moduledoc "List of governance approvals."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GovernanceApprovalList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: GovernanceApproval}
      },
      required: [:data]
    })
  end

  defmodule DecisionRequest do
    @moduledoc "Request body for approve or reject decisions."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GovernanceDecisionRequest",
      type: :object,
      properties: %{
        decided_by: %Schema{type: :string, description: "Human identifier making the decision"},
        reason: %Schema{type: :string, description: "Rationale for this decision"}
      },
      required: [:decided_by, :reason]
    })
  end

  defmodule AuditLogEntry do
    @moduledoc "A single governance audit log entry."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GovernanceAuditLogEntry",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        rule_id: %Schema{type: :string, format: :uuid, nullable: true},
        session_id: %Schema{type: :string, format: :uuid, nullable: true},
        event_type: %Schema{
          type: :string,
          enum: [
            "rule_evaluated",
            "session_blocked",
            "approval_requested",
            "approval_granted",
            "approval_rejected",
            "policy_bypassed"
          ]
        },
        payload: %Schema{type: :object},
        occurred_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :event_type, :occurred_at, :payload]
    })
  end

  defmodule AuditLogList do
    @moduledoc "List of governance audit log entries."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "GovernanceAuditLogList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: AuditLogEntry}
      },
      required: [:data]
    })
  end
end
