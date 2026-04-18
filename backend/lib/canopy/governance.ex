defmodule Canopy.Governance do
  @moduledoc """
  Public API for Canopy governance gates.

  Governance gates inspect session context before execution and apply rules
  that can block, require approval, warn, or log. This is the Canopy-original
  approval gate system ported from canopy-legacy (`governance/gate.ex`).

  ## Session Integration Hook

  `Sessions.create/1` should call `Canopy.Governance.evaluate/1` before the
  Repo.insert. The call site should build a context map from the session attrs:

      context = %{
        "runtime_type"   => attrs.runtime_type,
        "agent_slug"     => attrs.agent_slug,
        "workspace_slug" => attrs.workspace_slug,
        "prompt"         => attrs.prompt,
        "cost_usd"       => 0
      }

      case Canopy.Governance.evaluate(context) do
        :pass ->
          # proceed with insert
        {:require_approval, rule} ->
          # surface to caller; persist session as "pending" with governance metadata
        {:block, rule} ->
          # reject: return {:error, :governance_blocked}
        {:warn, rule} ->
          # log and proceed
      end

  Track A or the Sessions wiring agent adds this call. The governance module
  exposes the API cleanly — no changes to Sessions.create are made here.

  ## Rule Evaluation

  Rules are loaded from the database, filtered to enabled=true, and sorted by
  priority descending. The first rule whose conditions ALL match wins. Warn and
  log actions do not short-circuit — they continue evaluating for a decisive match.
  If no decisive match is found, `evaluate/1` returns `:pass`.

  ## Audit Log

  Every `evaluate/1`, `approve/3`, and `reject/3` call writes to the append-only
  `governance_audit_log` table. The log is never modified after insertion.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Governance.{Approval, AuditLog, Evaluator, Rule}
  alias Canopy.Repo

  require Logger

  # ---------------------------------------------------------------------------
  # Rule management
  # ---------------------------------------------------------------------------

  @doc "Returns all governance rules ordered by priority descending."
  @spec list_rules(keyword()) :: [Rule.t()]
  def list_rules(opts \\ []) do
    enabled_only = Keyword.get(opts, :enabled_only, false)

    query =
      from(r in Rule,
        order_by: [desc: r.priority, asc: r.inserted_at]
      )

    query =
      if enabled_only do
        from(r in query, where: r.enabled == true)
      else
        query
      end

    Repo.all(query)
  end

  @doc "Fetches a rule by id, raising if not found."
  @spec get_rule!(binary()) :: Rule.t()
  def get_rule!(id), do: Repo.get!(Rule, id)

  @doc "Creates a new governance rule."
  @spec create_rule(map()) :: {:ok, Rule.t()} | {:error, Ecto.Changeset.t()}
  def create_rule(attrs) do
    %Rule{}
    |> Rule.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates an existing governance rule."
  @spec update_rule(Rule.t(), map()) :: {:ok, Rule.t()} | {:error, Ecto.Changeset.t()}
  def update_rule(%Rule{} = rule, attrs) do
    rule
    |> Rule.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a governance rule."
  @spec delete_rule(Rule.t()) :: {:ok, Rule.t()} | {:error, Ecto.Changeset.t()}
  def delete_rule(%Rule{} = rule), do: Repo.delete(rule)

  @doc "Enables a governance rule."
  @spec enable_rule(Rule.t()) :: {:ok, Rule.t()} | {:error, Ecto.Changeset.t()}
  def enable_rule(%Rule{} = rule) do
    rule
    |> Rule.enabled_changeset(true)
    |> Repo.update()
  end

  @doc "Disables a governance rule."
  @spec disable_rule(Rule.t()) :: {:ok, Rule.t()} | {:error, Ecto.Changeset.t()}
  def disable_rule(%Rule{} = rule) do
    rule
    |> Rule.enabled_changeset(false)
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Evaluation
  # ---------------------------------------------------------------------------

  @doc """
  Evaluates all enabled rules against the session context.

  Rules are sorted by priority descending. The first rule with a decisive
  action (block or require_approval) that matches the context wins. Warn and
  log rules are applied but do not stop evaluation. If no decisive match is
  found, returns `:pass`.

  Context map keys (all optional, string-keyed):
    - "runtime_type"   — session runtime adapter type
    - "agent_slug"     — agent identifier
    - "workspace_slug" — workspace identifier
    - "prompt"         — user prompt text
    - "cost_usd"       — accumulated cost for cost_over checks
    - "session_id"     — for audit log correlation

  ## Examples

      iex> Canopy.Governance.evaluate(%{"runtime_type" => "claude-local", "prompt" => "deploy"})
      {:block, %Rule{}}

      iex> Canopy.Governance.evaluate(%{"prompt" => "hello"})
      :pass
  """
  @spec evaluate(map()) ::
          :pass | {:require_approval, Rule.t()} | {:block, Rule.t()} | {:warn, Rule.t()}
  def evaluate(context) do
    session_id = Map.get(context, "session_id") || Map.get(context, :session_id)

    rules =
      from(r in Rule,
        where: r.enabled == true,
        order_by: [desc: r.priority, asc: r.inserted_at]
      )
      |> Repo.all()

    result = apply_rules(rules, context, session_id)

    case result do
      :pass ->
        audit(%{
          event_type: "policy_bypassed",
          session_id: session_id,
          payload: %{rule_count: length(rules)}
        })

      {:block, rule} ->
        audit(%{
          event_type: "session_blocked",
          rule_id: rule.id,
          session_id: session_id,
          payload: %{rule_name: rule.name, context: sanitize_context(context)}
        })

      {:require_approval, rule} ->
        audit(%{
          event_type: "approval_requested",
          rule_id: rule.id,
          session_id: session_id,
          payload: %{rule_name: rule.name}
        })

      {:warn, rule} ->
        audit(%{
          event_type: "rule_evaluated",
          rule_id: rule.id,
          session_id: session_id,
          payload: %{rule_name: rule.name, action: "warn"}
        })
    end

    result
  end

  # ---------------------------------------------------------------------------
  # Approvals
  # ---------------------------------------------------------------------------

  @doc """
  Creates a pending approval request for the given rule and session.

  The caller (Sessions.create or similar) should persist this before returning
  a 202 to the frontend so the approval can be surfaced in the UI.
  """
  @spec request_approval(binary(), binary()) :: {:ok, Approval.t()} | {:error, Ecto.Changeset.t()}
  def request_approval(rule_id, session_id) do
    attrs = %{
      rule_id: rule_id,
      session_id: session_id,
      status: "pending",
      requested_at: DateTime.utc_now()
    }

    result =
      %Approval{}
      |> Approval.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, approval} ->
        audit(%{
          event_type: "approval_requested",
          rule_id: rule_id,
          session_id: session_id,
          payload: %{approval_id: approval.id}
        })

        {:ok, approval}

      error ->
        error
    end
  end

  @doc "Approves a pending approval. Records who approved and why."
  @spec approve(binary(), String.t(), String.t()) :: {:ok, Approval.t()} | {:error, term()}
  def approve(approval_id, decided_by, reason) do
    decide(approval_id, "approved", decided_by, reason, "approval_granted")
  end

  @doc "Rejects a pending approval. Records who rejected and why."
  @spec reject(binary(), String.t(), String.t()) :: {:ok, Approval.t()} | {:error, term()}
  def reject(approval_id, decided_by, reason) do
    decide(approval_id, "rejected", decided_by, reason, "approval_rejected")
  end

  @doc "Returns all approvals, optionally filtered by status."
  @spec pending_approvals() :: [Approval.t()]
  def pending_approvals do
    Repo.all(from(a in Approval, where: a.status == "pending", order_by: [asc: a.requested_at]))
  end

  # ---------------------------------------------------------------------------
  # Audit log queries
  # ---------------------------------------------------------------------------

  @doc "Returns audit log entries with optional filters."
  @spec list_audit(keyword()) :: [AuditLog.t()]
  def list_audit(opts \\ []) do
    event_type = Keyword.get(opts, :event_type)
    since = Keyword.get(opts, :since)
    until_dt = Keyword.get(opts, :until)
    limit = Keyword.get(opts, :limit, 100)
    session_id = Keyword.get(opts, :session_id)

    from(a in AuditLog, order_by: [desc: a.occurred_at], limit: ^limit)
    |> apply_audit_filter(:event_type, event_type)
    |> apply_audit_filter(:since, since)
    |> apply_audit_filter(:until, until_dt)
    |> apply_audit_filter(:session_id, session_id)
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec apply_rules([Rule.t()], map(), binary() | nil) ::
          :pass | {:require_approval, Rule.t()} | {:block, Rule.t()} | {:warn, Rule.t()}
  defp apply_rules([], _context, _session_id), do: :pass

  defp apply_rules([rule | rest], context, session_id) do
    if Evaluator.matches?(rule, context) do
      audit(%{
        event_type: "rule_evaluated",
        rule_id: rule.id,
        session_id: session_id,
        payload: %{rule_name: rule.name, action: rule.action, matched: true}
      })

      case rule.action do
        "block" -> {:block, rule}
        "require_approval" -> {:require_approval, rule}
        "warn" -> {:warn, rule}
        "log" -> apply_rules(rest, context, session_id)
        _other -> apply_rules(rest, context, session_id)
      end
    else
      apply_rules(rest, context, session_id)
    end
  end

  @spec decide(binary(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, Approval.t()} | {:error, term()}
  defp decide(approval_id, status, decided_by, reason, event_type) do
    case Repo.get(Approval, approval_id) do
      nil ->
        {:error, :not_found}

      %Approval{status: "pending"} = approval ->
        attrs = %{
          status: status,
          decided_at: DateTime.utc_now(),
          decided_by: decided_by,
          decision_reason: reason
        }

        case approval |> Approval.decision_changeset(attrs) |> Repo.update() do
          {:ok, updated} ->
            audit(%{
              event_type: event_type,
              rule_id: updated.rule_id,
              session_id: updated.session_id,
              payload: %{
                approval_id: updated.id,
                decided_by: decided_by,
                reason: reason
              }
            })

            {:ok, updated}

          error ->
            error
        end

      %Approval{status: current} ->
        {:error, {:already_decided, current}}
    end
  end

  @spec audit(map()) :: :ok
  defp audit(attrs) do
    entry_attrs = Map.put_new(attrs, :occurred_at, DateTime.utc_now())

    case %AuditLog{} |> AuditLog.changeset(entry_attrs) |> Repo.insert() do
      {:ok, _inserted} ->
        :ok

      {:error, cs} ->
        Logger.warning("[Governance] audit insert failed: #{inspect(cs.errors)}")
        :ok
    end
  end

  @spec apply_audit_filter(Ecto.Query.t(), atom(), term()) :: Ecto.Query.t()
  defp apply_audit_filter(query, _key, nil), do: query

  defp apply_audit_filter(query, :event_type, val),
    do: from(a in query, where: a.event_type == ^val)

  defp apply_audit_filter(query, :session_id, val),
    do: from(a in query, where: a.session_id == ^val)

  defp apply_audit_filter(query, :since, val) do
    case parse_datetime(val) do
      {:ok, dt} -> from(a in query, where: a.occurred_at >= ^dt)
      _error -> query
    end
  end

  defp apply_audit_filter(query, :until, val) do
    case parse_datetime(val) do
      {:ok, dt} -> from(a in query, where: a.occurred_at <= ^dt)
      _error -> query
    end
  end

  @spec parse_datetime(term()) :: {:ok, DateTime.t()} | :error
  defp parse_datetime(%DateTime{} = dt), do: {:ok, dt}

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> {:ok, dt}
      _error -> :error
    end
  end

  defp parse_datetime(_other), do: :error

  # Strip large fields from context before storing in audit payload.
  @spec sanitize_context(map()) :: map()
  defp sanitize_context(context) do
    context
    |> Map.take(["runtime_type", "agent_slug", "workspace_slug", "session_id"])
  end
end
