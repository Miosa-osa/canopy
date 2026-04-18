defmodule CanopyWeb.BudgetsController do
  @moduledoc """
  HTTP API for Canopy budget policies.

  Routes (add to router.ex under /api/v1 scope):
    GET    /budgets                — list budgets (filter: ?scope_type=&enabled=)
    POST   /budgets                — create budget
    GET    /budgets/:id            — get budget
    PUT    /budgets/:id            — update budget
    DELETE /budgets/:id            — delete budget
    GET    /budgets/:id/spend      — current spend + historical snapshots
    POST   /budgets/:id/check      — preflight enforcement check

  The check endpoint accepts `{projected_cost: "0.05"}` and returns `ok | warn | block`.
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ecto.Query, only: [from: 2]

  alias Canopy.Budgets
  alias Canopy.Budgets.SpendSnapshot
  alias Canopy.Repo
  alias CanopyWeb.Schemas.BudgetSchema

  action_fallback CanopyWeb.FallbackController

  tags ["budgets"]

  operation :index,
    summary: "List budget policies",
    description: "Returns all budgets. Optionally filter by scope_type or enabled status.",
    parameters: [
      scope_type: [
        in: :query,
        description: "Filter by scope type: agent | workspace | runtime | global",
        type: :string,
        required: false
      ],
      enabled: [
        in: :query,
        description: "Filter by enabled status: true | false",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: {"Budget list", "application/json", BudgetSchema.BudgetList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    opts = []

    opts =
      if params["scope_type"],
        do: Keyword.put(opts, :scope_type, params["scope_type"]),
        else: opts

    opts =
      if params["enabled"],
        do: Keyword.put(opts, :enabled, params["enabled"] == "true"),
        else: opts

    {:ok, budgets} = Budgets.list(opts)
    json(conn, %{data: budgets})
  end

  operation :create,
    summary: "Create a budget policy",
    request_body: {"Budget params", "application/json", BudgetSchema.BudgetCreateRequest},
    responses: [
      ok: {"Created budget", "application/json", BudgetSchema.Budget},
      unprocessable_entity:
        {"Validation error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    with {:ok, budget} <- Budgets.create(params) do
      conn
      |> put_status(:created)
      |> json(budget)
    end
  end

  operation :show,
    summary: "Get a budget policy",
    parameters: [
      id: [in: :path, description: "Budget UUID", type: :string, required: true]
    ],
    responses: [
      ok: {"Budget detail", "application/json", BudgetSchema.Budget},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    budget = Budgets.get!(id)
    json(conn, budget)
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  operation :update,
    summary: "Update a budget policy",
    parameters: [
      id: [in: :path, description: "Budget UUID", type: :string, required: true]
    ],
    request_body: {"Budget update params", "application/json", BudgetSchema.BudgetUpdateRequest},
    responses: [
      ok: {"Updated budget", "application/json", BudgetSchema.Budget},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse},
      unprocessable_entity:
        {"Validation error", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    attrs = Map.drop(params, ["id"])

    with budget <- Budgets.get!(id),
         {:ok, updated} <- Budgets.update(budget, attrs) do
      json(conn, updated)
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  operation :delete,
    summary: "Delete a budget policy",
    parameters: [
      id: [in: :path, description: "Budget UUID", type: :string, required: true]
    ],
    responses: [
      ok: {"Deleted budget", "application/json", BudgetSchema.Budget},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with budget <- Budgets.get!(id),
         {:ok, deleted} <- Budgets.delete(budget) do
      json(conn, deleted)
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  operation :spend,
    summary: "Get current spend and historical snapshots for a budget",
    parameters: [
      id: [in: :path, description: "Budget UUID", type: :string, required: true]
    ],
    responses: [
      ok: {"Spend data", "application/json", BudgetSchema.SpendResponse},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec spend(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def spend(conn, %{"id" => id}) do
    budget = Budgets.get!(id)
    {:ok, current} = Budgets.current_spend(budget.scope_type, budget.scope_id, budget.period)

    snapshots =
      Repo.all(
        from(s in SpendSnapshot,
          where: s.budget_id == ^budget.id,
          order_by: [desc: s.snapshot_at],
          limit: 100
        )
      )

    json(conn, %{current_spend_usd: current, snapshots: snapshots})
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  operation :check_budget,
    summary: "Preflight budget enforcement check",
    description: """
    Returns the enforcement tier for the given budget plus projected cost.
    Result is one of: ok | warn | block.
    """,
    parameters: [
      id: [in: :path, description: "Budget UUID", type: :string, required: true]
    ],
    request_body: {"Check params", "application/json", BudgetSchema.CheckRequest},
    responses: [
      ok: {"Check result", "application/json", BudgetSchema.CheckResponse},
      not_found: {"Not found", "application/json", CanopyWeb.Schemas.RuntimeSchema.ErrorResponse}
    ]

  @spec check_budget(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def check_budget(conn, %{"id" => id} = params) do
    budget = Budgets.get!(id)
    projected = parse_decimal(params["projected_cost"])

    result = Budgets.check(budget.scope_type, budget.scope_id, projected)

    body =
      case result do
        :ok ->
          %{result: "ok", spent_usd: nil, limit_usd: nil, budget_id: nil}

        {:warn, b, spent} ->
          %{result: "warn", spent_usd: spent, limit_usd: b.limit_usd, budget_id: b.id}

        {:block, b, spent} ->
          %{result: "block", spent_usd: spent, limit_usd: b.limit_usd, budget_id: b.id}
      end

    json(conn, body)
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec parse_decimal(String.t() | number() | nil) :: Decimal.t()
  defp parse_decimal(nil), do: Decimal.new(0)
  defp parse_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp parse_decimal(val) when is_float(val), do: Decimal.from_float(val)
  defp parse_decimal(val) when is_integer(val), do: Decimal.new(val)
end
