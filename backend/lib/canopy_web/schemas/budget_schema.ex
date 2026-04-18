defmodule CanopyWeb.Schemas.BudgetSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Budget resource.

  These are API contract schemas for `/api/v1/budgets`. Distinct from Ecto schemas.
  """

  alias OpenApiSpex.Schema

  defmodule Budget do
    @moduledoc "A Canopy budget policy."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Budget",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        scope_type: %Schema{
          type: :string,
          enum: ["agent", "workspace", "runtime", "global"],
          description: "What entity this budget constrains"
        },
        scope_id: %Schema{
          type: :string,
          format: :uuid,
          nullable: true,
          description: "ID of the scoped entity; nil for global budgets"
        },
        period: %Schema{
          type: :string,
          enum: ["daily", "weekly", "monthly", "total"],
          description: "Period over which spend is accumulated"
        },
        limit_usd: %Schema{
          type: :string,
          description: "Spending limit in USD (decimal string)"
        },
        soft_alert_pct: %Schema{
          type: :integer,
          description: "Percentage of limit at which a soft warning fires (default 80)"
        },
        hard_ceiling: %Schema{
          type: :boolean,
          description: "When true, sessions are blocked at 100% of limit"
        },
        enabled: %Schema{type: :boolean, description: "Whether this budget is enforced"},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :scope_type, :period, :limit_usd, :soft_alert_pct, :hard_ceiling, :enabled]
    })
  end

  defmodule BudgetList do
    @moduledoc "A list of budget policies."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "BudgetList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Budget}
      },
      required: [:data]
    })
  end

  defmodule BudgetCreateRequest do
    @moduledoc "Request body for creating a budget."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "BudgetCreateRequest",
      type: :object,
      properties: %{
        scope_type: %Schema{type: :string, enum: ["agent", "workspace", "runtime", "global"]},
        scope_id: %Schema{type: :string, format: :uuid, nullable: true},
        period: %Schema{type: :string, enum: ["daily", "weekly", "monthly", "total"]},
        limit_usd: %Schema{type: :string, description: "Decimal string, e.g. \"100.00\""},
        soft_alert_pct: %Schema{type: :integer, description: "Default 80"},
        hard_ceiling: %Schema{type: :boolean, description: "Default true"},
        enabled: %Schema{type: :boolean, description: "Default true"}
      },
      required: [:scope_type, :period, :limit_usd]
    })
  end

  defmodule BudgetUpdateRequest do
    @moduledoc "Request body for updating a budget."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "BudgetUpdateRequest",
      type: :object,
      properties: %{
        limit_usd: %Schema{type: :string},
        soft_alert_pct: %Schema{type: :integer},
        hard_ceiling: %Schema{type: :boolean},
        enabled: %Schema{type: :boolean}
      }
    })
  end

  defmodule SpendSnapshot do
    @moduledoc "A historical spend snapshot for a budget."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SpendSnapshot",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        budget_id: %Schema{type: :string, format: :uuid},
        period_start: %Schema{type: :string, format: :"date-time"},
        period_end: %Schema{type: :string, format: :"date-time"},
        actual_spend_usd: %Schema{type: :string, description: "Decimal string"},
        session_count: %Schema{type: :integer},
        snapshot_at: %Schema{type: :string, format: :"date-time"},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :budget_id, :period_start, :period_end, :actual_spend_usd, :session_count]
    })
  end

  defmodule SpendResponse do
    @moduledoc "Response for GET /budgets/:id/spend."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SpendResponse",
      type: :object,
      properties: %{
        current_spend_usd: %Schema{type: :string, description: "Current period spend in USD"},
        snapshots: %Schema{type: :array, items: SpendSnapshot}
      },
      required: [:current_spend_usd, :snapshots]
    })
  end

  defmodule CheckRequest do
    @moduledoc "Request body for POST /budgets/:id/check."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CheckRequest",
      type: :object,
      properties: %{
        projected_cost: %Schema{
          type: :string,
          description: "Expected cost in USD to add to current spend before threshold evaluation"
        }
      }
    })
  end

  defmodule CheckResponse do
    @moduledoc "Response for POST /budgets/:id/check."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CheckResponse",
      type: :object,
      properties: %{
        result: %Schema{
          type: :string,
          enum: ["ok", "warn", "block"],
          description: "Enforcement tier result"
        },
        spent_usd: %Schema{
          type: :string,
          nullable: true,
          description: "Actual spend (including projection) when result is warn or block"
        },
        limit_usd: %Schema{
          type: :string,
          nullable: true,
          description: "Budget limit when result is warn or block"
        },
        budget_id: %Schema{type: :string, format: :uuid, nullable: true}
      },
      required: [:result]
    })
  end
end
