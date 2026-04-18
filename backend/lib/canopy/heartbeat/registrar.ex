defmodule Canopy.Heartbeat.Registrar do
  @moduledoc """
  Manages Oban job scheduling for agent heartbeats.

  Since `Oban.Plugins.Cron` only supports static crontab entries loaded at boot,
  we use the self-rescheduling pattern instead:

  1. `register/1` — called when an agent is hired. Validates the cron expression,
     computes the next fire time, and inserts an `Oban.Job` with `scheduled_at`.

  2. `Canopy.Heartbeat.Worker.perform/1` — after each successful run, calls
     `schedule_next_job/2` to insert the _following_ job in the chain.

  3. `unregister/1` — called when an agent is fired. Cancels all pending heartbeat
     jobs for that agent slug.

  4. `register_all_hired/0` — called once at application boot (via a supervised
     Task) to register all currently-hired agents that have a `heartbeat_cron`.
     This is idempotent: if a job already exists for the agent (unique constraint),
     Oban deduplicates it silently.

  ## Cron expression validation

  `valid_cron?/1` uses `Oban.Cron.Expression.parse!/1` which ships with Oban.
  No external cron-parsing dependency is required. Invalid expressions are
  rejected at hire time before any job is inserted.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Agents.Agent
  alias Canopy.Heartbeat.Worker
  alias Canopy.Repo
  alias Oban.Cron.Expression

  require Logger

  @doc """
  Registers a cron-scheduled heartbeat for the given agent.

  Validates the `heartbeat_cron` expression. If valid, computes the next fire
  time and inserts an Oban job with `scheduled_at`. Noop if the agent has no
  `heartbeat_cron`.

  Returns `:ok` on success or `{:error, term}` if the expression is invalid or
  job insertion fails.
  """
  @spec register(Agent.t()) :: :ok | {:error, term()}
  def register(%Agent{heartbeat_cron: nil}), do: :ok

  def register(%Agent{heartbeat_cron: expr, slug: slug}) do
    if valid_cron?(expr) do
      case schedule_next_job(slug, expr) do
        {:ok, _job} ->
          Logger.info("[Heartbeat.Registrar] Registered heartbeat for agent=#{slug} cron=#{expr}")
          :ok

        {:error, reason} ->
          Logger.error("[Heartbeat.Registrar] Failed to register #{slug}: #{inspect(reason)}")

          {:error, reason}
      end
    else
      Logger.warning(
        "[Heartbeat.Registrar] Invalid cron expression for agent=#{slug}: #{inspect(expr)}"
      )

      {:error, {:invalid_cron_expression, expr}}
    end
  end

  @doc """
  Cancels all pending heartbeat jobs for the given agent slug.

  Uses `Oban.cancel_all_jobs/1` on the `:heartbeats` queue filtered by the
  agent_slug argument. Silently succeeds if no jobs are pending.
  """
  @spec unregister(String.t()) :: :ok
  def unregister(slug) do
    query =
      from(j in Oban.Job,
        where:
          j.queue == "heartbeats" and
            j.state in ["available", "scheduled", "retryable"] and
            fragment("?->>'agent_slug' = ?", j.args, ^slug)
      )

    {count, _rows} = Repo.update_all(query, set: [state: "cancelled"])

    if count > 0 do
      Logger.info("[Heartbeat.Registrar] Cancelled #{count} job(s) for agent=#{slug}")
    end

    :ok
  end

  @doc """
  Registers heartbeat schedules for all currently hired agents that have a
  `heartbeat_cron` set.

  Called once at application boot via a supervised Task. Uses Oban's `unique`
  constraint (`period: 60`) to deduplicate — if a job already exists for an
  agent from a previous boot, the insert is a no-op.

  Returns `{:ok, count}` where `count` is the number of agents processed
  (not necessarily the number of new jobs inserted, since some may be
  de-duplicated by Oban).
  """
  @spec register_all_hired() :: {:ok, non_neg_integer()}
  def register_all_hired do
    {:ok, agents} = Canopy.Agents.list(hired: true)

    agents_with_cron = Enum.filter(agents, &(&1.heartbeat_cron != nil))

    Enum.each(agents_with_cron, fn agent ->
      case register(agent) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "[Heartbeat.Registrar] Boot registration failed for #{agent.slug}: #{inspect(reason)}"
          )
      end
    end)

    {:ok, length(agents_with_cron)}
  end

  @doc """
  Validates a cron expression using Oban's built-in parser.

  Returns `true` if the expression is valid, `false` otherwise. Supports
  standard 5-field cron syntax (`* * * * *`) and Oban-specific aliases
  (`@hourly`, `@daily`, `@weekly`, `@monthly`, `@yearly`, `@reboot`).

  ## Examples

      iex> Canopy.Heartbeat.Registrar.valid_cron?("*/5 * * * *")
      true

      iex> Canopy.Heartbeat.Registrar.valid_cron?("not-a-cron")
      false
  """
  @spec valid_cron?(String.t()) :: boolean()
  def valid_cron?(expression) when is_binary(expression) do
    Expression.parse!(expression)
    true
  rescue
    _error -> false
  end

  def valid_cron?(_invalid), do: false

  @doc """
  Inserts an Oban heartbeat job scheduled at the next cron fire time after now.

  Used both by `register/1` (initial scheduling on hire) and by
  `Canopy.Heartbeat.Worker` (self-rescheduling after each run).

  Returns `{:ok, Oban.Job.t()}` or `{:error, term()}`.
  """
  @spec schedule_next_job(String.t(), String.t()) ::
          {:ok, Oban.Job.t()} | {:error, term()}
  def schedule_next_job(slug, cron_expr) do
    case next_fire_time(cron_expr) do
      {:ok, scheduled_at} ->
        job =
          Worker.new(
            %{"agent_slug" => slug, "wake_reason" => "heartbeat"},
            scheduled_at: scheduled_at
          )

        Oban.insert(job)

      {:error, _reason} = error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec next_fire_time(String.t()) :: {:ok, DateTime.t()} | {:error, :invalid_cron_expression}
  defp next_fire_time(expr) do
    expr
    |> Expression.parse!()
    |> Expression.next_at(DateTime.utc_now())
    |> case do
      %DateTime{} = dt -> {:ok, dt}
      :unknown -> {:error, :invalid_cron_expression}
    end
  rescue
    _error -> {:error, :invalid_cron_expression}
  end
end
