defmodule Canopy.Heartbeat.Worker do
  @moduledoc """
  Oban worker that executes an agent heartbeat by creating a Canopy session.

  One job fires per agent per cron tick. The `unique: [period: 60]` guard prevents
  duplicate jobs from landing within the same 60-second window — the natural defence
  against clock skew and double-registration.

  After each successful or cancelled run the worker schedules the _next_ fire time
  by inserting a new job with `scheduled_at`. This is the self-rescheduling pattern:
  since `Oban.Plugins.Cron` only supports static crontab at boot time, we compute
  the next DateTime from the agent's `heartbeat_cron` expression and insert a new
  job ourselves.

  ## Cancel semantics

  - `{:cancel, :agent_not_hired}` — agent was fired after the job was enqueued.
    Oban marks the job cancelled; the rescheduling step is deliberately skipped so
    the chain ends cleanly. `Canopy.Heartbeat.Registrar.unregister/1` also cancels
    any pending jobs when `Agents.fire/1` is called.

  - `{:cancel, :agent_not_found}` — agent row was deleted from the database.
    Same outcome — the scheduling chain ends.

  - `{:cancel, :no_cron_expression}` — the agent has no `heartbeat_cron`. This
    should not happen if jobs are only enqueued by `Registrar.register/1`, but
    guards against schema drift.

  - `{:cancel, :gate_blocked}` — governance or budget gate denied the session.
    Gate decisions are authoritative and must not be retried. The rescheduling
    chain continues so future heartbeats still fire (the gate may pass later).
  """

  use Oban.Worker, queue: :heartbeats, max_attempts: 3, unique: [period: 60]

  alias Canopy.Agents
  alias Canopy.Heartbeat.Registrar
  alias Canopy.Sessions

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"agent_slug" => slug, "wake_reason" => reason}}) do
    with {:ok, agent} <- Agents.get_by_slug(slug),
         true <- agent.hired,
         {:ok, session} <- create_session(agent, reason) do
      schedule_next(agent)
      {:ok, session.id}
    else
      false ->
        Logger.info("[Heartbeat] Agent #{slug} is not hired — cancelling job chain")
        {:cancel, :agent_not_hired}

      {:error, :not_found} ->
        Logger.warning("[Heartbeat] Agent #{slug} not found — cancelling job chain")
        {:cancel, :agent_not_found}

      {:error, :no_cron_expression} ->
        Logger.warning("[Heartbeat] Agent #{slug} has no heartbeat_cron — cancelling")
        {:cancel, :no_cron_expression}

      {:error, {:governance_blocked, rule}} ->
        Logger.warning(
          "[Heartbeat] Gate blocked agent=#{slug} rule=#{rule.id} name=#{rule.name} — cancelling (no retry)"
        )

        {:cancel, :gate_blocked}

      {:error, {:budget_blocked, budget, spent}} ->
        Logger.warning(
          "[Heartbeat] Gate blocked agent=#{slug} budget=#{budget.id} spent=#{spent} — cancelling (no retry)"
        )

        {:cancel, :gate_blocked}

      {:error, err_reason} ->
        Logger.error("[Heartbeat] Session creation failed for #{slug}: #{inspect(err_reason)}")
        {:error, err_reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec create_session(Agents.Agent.t(), String.t()) ::
          {:ok, Sessions.Session.t()} | {:error, term()}
  defp create_session(agent, reason) do
    Sessions.create(%{
      agent_slug: agent.slug,
      runtime_type: agent.default_runtime || "claude-local",
      wake_reason: reason || "heartbeat",
      cwd: default_workspace_cwd(agent),
      prompt: heartbeat_prompt(agent)
    })
  end

  # Week 3 will resolve the real workspace path from the agent's workspace association.
  # For now we use the system temp directory as a safe, always-present fallback.
  @spec default_workspace_cwd(Agents.Agent.t()) :: String.t()
  defp default_workspace_cwd(_agent), do: System.tmp_dir!()

  # Returns the heartbeat prompt for an agent.
  #
  # Reads agent.persona_markdown directly from the already-loaded DB row —
  # no filesystem access at runtime. The file at persona_path is the seed
  # source only (written by mix canopy.seed.agents). Falls back to a canned
  # prompt when persona_markdown is nil or empty.
  @spec heartbeat_prompt(Agents.Agent.t()) :: String.t()
  defp heartbeat_prompt(%{persona_markdown: markdown, name: _name})
       when is_binary(markdown) and markdown != "" do
    markdown
  end

  defp heartbeat_prompt(%{name: name}) do
    canned_prompt(name)
  end

  @spec canned_prompt(String.t()) :: String.t()
  defp canned_prompt(name),
    do: "You are #{name}. Check your inbox and complete any pending work items."

  # Insert the next heartbeat job, scheduled at the time the cron expression
  # next fires after now. If the expression cannot be parsed (shouldn't happen
  # since Registrar validates before inserting), we log a warning and stop.
  @spec schedule_next(Agents.Agent.t()) :: :ok
  defp schedule_next(%{heartbeat_cron: nil, slug: slug}) do
    Logger.warning("[Heartbeat] Cannot reschedule #{slug}: no cron expression")
    :ok
  end

  defp schedule_next(%{heartbeat_cron: cron_expr, slug: slug}) do
    case Registrar.schedule_next_job(slug, cron_expr) do
      {:ok, _job} ->
        Logger.debug("[Heartbeat] Rescheduled #{slug}")
        :ok

      {:error, reason} ->
        Logger.warning("[Heartbeat] Failed to reschedule #{slug}: #{inspect(reason)}")
        :ok
    end
  end
end
