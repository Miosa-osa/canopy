defmodule Canopy.Analytics.Emitter do
  @moduledoc """
  Centralized emission helpers that translate domain events into telemetry
  records and breadcrumbs for the Iris (Analytics) super-module.

  This module is a **leaf** — it depends only on `Canopy.Analytics` and
  `Canopy.Analytics.Breadcrumbs`. Any other context module (Sessions,
  Governance, Budgets, Heartbeats, Tools, Runtimes) may call these helpers
  without introducing a circular dependency.

  ## Why a thin wrapper?

  - Single responsibility: every domain module has one place to look up
    "what telemetry event do I emit for this lifecycle hook?"
  - Errors are guaranteed swallowed: `Analytics.record/1` already returns
    `:ok` even on failure, but emitter helpers also rescue any exception so
    that an unexpected failure (e.g. ETS table not yet booted) cannot crash
    the caller's flow.
  - Vocabulary lives in one place: the event names below are the canonical
    list documented in `Canopy.Analytics.Telemetry`.
  """

  alias Canopy.Analytics
  alias Canopy.Analytics.Breadcrumbs

  require Logger

  # ---------------------------------------------------------------------------
  # Agent run lifecycle
  # ---------------------------------------------------------------------------

  @doc """
  Emits `agent.run.started`. Accepts a map with optional keys: `:run_id`,
  `:session_id`, `:agent_id`, `:workspace_slug`, `:runtime`, `:model`,
  `:payload`.
  """
  @spec agent_run_started(map()) :: :ok
  def agent_run_started(attrs) do
    safe_record(
      Map.merge(
        %{event: "agent.run.started", status: "info"},
        Map.take(attrs, common_run_keys() ++ [:payload])
      )
    )
  end

  @doc """
  Emits `agent.run.finished`. `metrics` may include `:duration_ms`,
  `:cost_cents`, `:status` (defaults to "ok").
  """
  @spec agent_run_finished(map(), map()) :: :ok
  def agent_run_finished(attrs, metrics \\ %{}) do
    safe_record(
      Map.merge(
        %{event: "agent.run.finished", status: Map.get(metrics, :status, "ok")},
        Map.take(attrs, common_run_keys() ++ [:payload])
      )
      |> Map.merge(Map.take(metrics, [:duration_ms, :cost_cents]))
    )
  end

  @doc """
  Emits `agent.run.failed`. `error_info` may include `:reason`,
  `:duration_ms`, `:payload`.
  """
  @spec agent_run_failed(map(), map()) :: :ok
  def agent_run_failed(attrs, error_info \\ %{}) do
    payload =
      attrs
      |> Map.get(:payload, %{})
      |> Map.merge(Map.take(error_info, [:reason]))

    safe_record(
      Map.merge(
        %{event: "agent.run.failed", status: "error", payload: payload},
        Map.take(attrs, common_run_keys())
      )
      |> Map.merge(Map.take(error_info, [:duration_ms]))
    )
  end

  # ---------------------------------------------------------------------------
  # Session lifecycle
  # ---------------------------------------------------------------------------

  @spec session_created(map()) :: :ok
  def session_created(attrs) do
    safe_record(
      Map.merge(
        %{event: "session.created", status: "info"},
        Map.take(attrs, common_run_keys() ++ [:payload])
      )
    )
  end

  @spec session_completed(map()) :: :ok
  def session_completed(attrs) do
    safe_record(
      Map.merge(
        %{event: "session.completed", status: "ok"},
        Map.take(attrs, common_run_keys() ++ [:duration_ms, :cost_cents, :payload])
      )
    )
  end

  @spec session_cancelled(map()) :: :ok
  def session_cancelled(attrs) do
    safe_record(
      Map.merge(
        %{event: "session.cancelled", status: "warn"},
        Map.take(attrs, common_run_keys() ++ [:payload])
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Governance
  # ---------------------------------------------------------------------------

  @spec governance_approved(map(), map()) :: :ok
  def governance_approved(attrs, rule \\ %{}) do
    payload = governance_payload(rule, attrs)

    safe_record(
      Map.merge(
        %{event: "governance.approved", status: "ok", payload: payload},
        Map.take(attrs, common_run_keys())
      )
    )

    safe_breadcrumb(attrs, %{
      type: "governance",
      category: rule_name(rule),
      level: "info",
      message: "governance approved"
    })
  end

  @spec governance_rejected(map(), map()) :: :ok
  def governance_rejected(attrs, rule \\ %{}) do
    payload = governance_payload(rule, attrs)

    safe_record(
      Map.merge(
        %{event: "governance.rejected", status: "error", payload: payload},
        Map.take(attrs, common_run_keys())
      )
    )

    safe_breadcrumb(attrs, %{
      type: "governance",
      category: rule_name(rule),
      level: "warning",
      message: "governance rejected"
    })
  end

  @spec governance_escalated(map(), map()) :: :ok
  def governance_escalated(attrs, rule \\ %{}) do
    payload = governance_payload(rule, attrs)

    safe_record(
      Map.merge(
        %{event: "governance.escalated", status: "warn", payload: payload},
        Map.take(attrs, common_run_keys())
      )
    )

    safe_breadcrumb(attrs, %{
      type: "governance",
      category: rule_name(rule),
      level: "warning",
      message: "governance escalated for approval"
    })
  end

  # ---------------------------------------------------------------------------
  # Budgets
  # ---------------------------------------------------------------------------

  @spec budget_warned(map(), map()) :: :ok
  def budget_warned(attrs, budget_info \\ %{}) do
    safe_record(
      Map.merge(
        %{
          event: "budget.threshold_warned",
          status: "warn",
          payload: budget_payload(budget_info)
        },
        Map.take(attrs, common_run_keys())
      )
    )
  end

  @spec budget_blocked(map(), map()) :: :ok
  def budget_blocked(attrs, budget_info \\ %{}) do
    safe_record(
      Map.merge(
        %{
          event: "budget.ceiling_blocked",
          status: "error",
          payload: budget_payload(budget_info)
        },
        Map.take(attrs, common_run_keys())
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Heartbeats
  # ---------------------------------------------------------------------------

  @spec heartbeat_fired(map()) :: :ok
  def heartbeat_fired(attrs) do
    safe_record(
      Map.merge(
        %{event: "heartbeat.fired", status: "info"},
        Map.take(attrs, common_run_keys() ++ [:payload])
      )
    )
  end

  @spec heartbeat_missed(map()) :: :ok
  def heartbeat_missed(attrs) do
    safe_record(
      Map.merge(
        %{event: "heartbeat.missed", status: "warn"},
        Map.take(attrs, common_run_keys() ++ [:payload])
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Runtimes
  # ---------------------------------------------------------------------------

  @spec runtime_swapped(String.t() | nil, map()) :: :ok
  def runtime_swapped(runtime, attrs \\ %{}) do
    safe_record(
      Map.merge(
        %{
          event: "runtime.swapped",
          status: "info",
          runtime: to_str(runtime),
          payload: Map.get(attrs, :payload, %{})
        },
        Map.take(attrs, common_run_keys() -- [:runtime])
      )
    )
  end

  @spec runtime_test_failed(String.t() | nil, map()) :: :ok
  def runtime_test_failed(runtime, attrs \\ %{}) do
    safe_record(
      Map.merge(
        %{
          event: "runtime.test_failed",
          status: "error",
          runtime: to_str(runtime),
          payload: Map.get(attrs, :payload, %{})
        },
        Map.take(attrs, common_run_keys() -- [:runtime])
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Breadcrumbs
  # ---------------------------------------------------------------------------

  @doc """
  Emits a `tool_call` breadcrumb. `run_id` is required; if nil, the call is
  silently dropped (no run = no per-run trail).

  `tool_name` becomes the `category`; `args` are summarised into the `data`
  map (stringified keys, truncated values).
  """
  @spec tool_call_breadcrumb(Ecto.UUID.t() | nil, String.t(), map()) :: :ok
  def tool_call_breadcrumb(nil, _tool_name, _args), do: :ok

  def tool_call_breadcrumb(run_id, tool_name, args)
      when is_binary(run_id) and is_binary(tool_name) do
    try do
      Breadcrumbs.add(run_id, %{
        type: "tool_call",
        category: tool_name,
        level: "info",
        message: "tool: #{tool_name}",
        data: summarise_args(args)
      })
    rescue
      err ->
        Logger.debug("[Emitter] tool_call breadcrumb add raised: #{inspect(err)}")
        :ok
    catch
      _, _ -> :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @spec common_run_keys() :: [atom()]
  defp common_run_keys do
    [:run_id, :session_id, :agent_id, :workspace_slug, :runtime, :model]
  end

  @spec safe_record(map()) :: :ok
  defp safe_record(attrs) do
    Analytics.record(attrs)
  rescue
    err ->
      Logger.debug("[Emitter] record raised: #{inspect(err)}")
      :ok
  catch
    _, _ -> :ok
  end

  @spec safe_breadcrumb(map(), map()) :: :ok
  defp safe_breadcrumb(attrs, crumb) do
    case Map.get(attrs, :run_id) do
      run_id when is_binary(run_id) ->
        try do
          base =
            crumb
            |> Map.put_new(:session_id, Map.get(attrs, :session_id))

          Breadcrumbs.add(run_id, base)
        rescue
          _ -> :ok
        catch
          _, _ -> :ok
        end

        :ok

      _ ->
        :ok
    end
  end

  @spec governance_payload(map(), map()) :: map()
  defp governance_payload(rule, attrs) do
    base = %{
      "rule_id" => Map.get(rule, :id) || Map.get(rule, "id"),
      "rule_name" => rule_name(rule),
      "action" => Map.get(rule, :action) || Map.get(rule, "action")
    }

    case Map.get(attrs, :payload) do
      nil -> base
      extra when is_map(extra) -> Map.merge(base, extra)
      _ -> base
    end
  end

  @spec rule_name(map()) :: String.t() | nil
  defp rule_name(rule) do
    Map.get(rule, :name) || Map.get(rule, "name")
  end

  @spec budget_payload(map()) :: map()
  defp budget_payload(info) do
    info
    |> Map.take([:budget_id, :scope_type, :scope_id, :limit_usd, :spent, :reason])
    |> Enum.into(%{}, fn {k, v} -> {to_string(k), serialise(v)} end)
  end

  @spec serialise(term()) :: term()
  defp serialise(%Decimal{} = d), do: Decimal.to_string(d)
  defp serialise(other), do: other

  @spec to_str(term()) :: String.t() | nil
  defp to_str(nil), do: nil
  defp to_str(s) when is_binary(s), do: s
  defp to_str(a) when is_atom(a), do: Atom.to_string(a)
  defp to_str(other), do: to_string(other)

  @spec summarise_args(map()) :: map()
  defp summarise_args(args) when is_map(args) do
    args
    |> Enum.take(10)
    |> Enum.into(%{}, fn {k, v} ->
      {to_string(k), summarise_value(v)}
    end)
  end

  defp summarise_args(_), do: %{}

  @spec summarise_value(term()) :: term()
  defp summarise_value(v) when is_binary(v) and byte_size(v) > 200 do
    binary_part(v, 0, 200) <> "…"
  end

  defp summarise_value(v) when is_binary(v), do: v
  defp summarise_value(v) when is_number(v) or is_boolean(v) or is_nil(v), do: v
  defp summarise_value(v) when is_atom(v), do: Atom.to_string(v)
  defp summarise_value(v) when is_list(v), do: "[list len=#{length(v)}]"
  defp summarise_value(v) when is_map(v), do: "[map keys=#{map_size(v)}]"
  defp summarise_value(v), do: inspect(v, limit: 50, printable_limit: 200)
end
