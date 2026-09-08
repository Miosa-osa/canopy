defmodule Canopy.Application do
  @moduledoc """
  OTP Application entry point for Canopy.

  Defines the supervision tree in startup order. Each child is annotated with
  its role. The tree uses the `one_for_one` strategy — a failed child restarts
  independently without taking down siblings.
  """

  use Application

  alias Canopy.Heartbeat.Registrar, as: HeartbeatRegistrar

  @impl true
  def start(_type, _args) do
    children = [
      # 1. Telemetry — must be first so metrics are available during startup
      CanopyWeb.Telemetry,

      # 2. Ecto Repo — database connection pool
      Canopy.Repo,

      # 3. DNS cluster — enables node discovery in multi-node deployments
      {DNSCluster, query: Application.get_env(:canopy, :dns_cluster_query) || :ignore},

      # 4. Phoenix PubSub — in-process message bus for realtime events
      {Phoenix.PubSub, name: Canopy.PubSub},

      # 4a. Presence — user presence tracking across real-time topics.
      #     Must start after PubSub (it subscribes to it) and before the Endpoint.
      Canopy.Presence,

      # 5. Finch — HTTP connection pool used by Req (MIOSA client, quota APIs)
      {Finch, name: Canopy.Finch},

      # 6. Oban — Postgres-backed job queue (heartbeats, cron, async enforcement)
      {Oban, Application.fetch_env!(:canopy, Oban)},

      # 7. Runtime Registry — GenServer + ETS. Auto-registers built-in adapters
      #    on init. Process stays alive for app lifetime, so adapters stay registered
      #    (unlike the prior Task-based approach which auto-unregistered on exit).
      Canopy.Runtimes.RegistryServer,

      # 8. Tool Registry — GenServer + ETS. Starts empty; builtins registered in
      #    the boot Task below after all deps are ready.
      Canopy.Tools.Registry,

      # 9. Governance Rule Cache — ETS-backed cache of enabled rules
      Canopy.Governance.RuleCache,

      # 9a. Analytics Breadcrumbs — per-run ETS ring buffer; flushed to DB
      #     on run completion. Public ETS table allows direct hot-path writes
      #     from any process without a GenServer round-trip.
      Canopy.Analytics.Breadcrumbs,

      # 9aa. Schedule Dispatcher — periodic evaluator that scans active specs,
      #      marks late/missed runs, and emits :canopy.schedule.* telemetry.
      #      Wraps Canopy.Heartbeat.Worker (Oban) — does not replace it.
      Canopy.Schedule.Dispatcher,

      # 9b. Sessions Supervisor — DynamicSupervisor; one child per running session
      Canopy.Sessions.Supervisor,

      # 9c. Pty Registry — unique Registry for PtyBridge lookups (session_id → pid)
      {Registry, keys: :unique, name: Canopy.Sessions.PtyRegistry},

      # 9d. Pty Supervisor — DynamicSupervisor; one PtyBridge child per live terminal
      {DynamicSupervisor, name: Canopy.Sessions.PtySupervisor, strategy: :one_for_one},

      # 9e. Scrollback Registry — unique Registry for ScrollbackStore lookups (session_id → pid)
      {Registry, keys: :unique, name: Canopy.Sessions.ScrollbackRegistry},

      # 9f. Scrollback Supervisor — DynamicSupervisor; one ScrollbackStore per live session
      Canopy.Sessions.ScrollbackSupervisor,

      # 10. Task Supervisor — for fire-and-forget tasks (e.g. boot heartbeat registration)
      {Task.Supervisor, name: Canopy.TaskSupervisor},

      # 10a. Init Registry — tracks running init task pids for cancellation
      {Registry, keys: :unique, name: Canopy.Workspaces.InitRegistry},

      # 10. Phoenix Endpoint — HTTP server, last so all deps are ready
      CanopyWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Canopy.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      maybe_restore_sessions()

      # Register heartbeats for all hired agents after Oban has fully started.
      # Skipped in :test env — the SQL Sandbox requires explicit ownership per
      # process, and this Task runs outside any test process boundary.
      unless Application.get_env(:canopy, :env, :prod) == :test do
        Task.Supervisor.start_child(Canopy.TaskSupervisor, fn ->
          Process.sleep(500)

          # Hire Iris (Analytics) before HeartbeatRegistrar runs so her cron
          # is picked up in the same boot pass.
          case Canopy.Analytics.Iris.hire_if_missing() do
            {:ok, _agent} ->
              :ok

            {:error, reason} ->
              require Logger

              Logger.warning(
                "[Canopy.Application] Iris hire_if_missing failed (non-fatal): " <>
                  inspect(reason)
              )
          end

          # Hire Conductor (Build) — primary chat agent in the Build cockpit
          # that delegates to runtime adapters.
          case Canopy.Build.Conductor.hire_if_missing() do
            {:ok, _agent} ->
              :ok

            {:error, reason} ->
              require Logger

              Logger.warning(
                "[Canopy.Application] Conductor hire_if_missing failed (non-fatal): " <>
                  inspect(reason)
              )
          end

          HeartbeatRegistrar.register_all_hired()
          Canopy.Tools.register_all_builtins()

          # Register the super-module tool surfaces alongside the built-ins.
          Canopy.Tools.Registry.register_module(Canopy.Tools.Analytics)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Sandboxes)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Schedule)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Templates)
          Canopy.Tools.Registry.register_module(Canopy.Tools.SkillCurator)
          Canopy.Tools.Registry.register_module(Canopy.Tools.RuntimeAdapter)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Drive)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Build)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Runtimes)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Kanban)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Relay)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Reviews)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Workspace)
          Canopy.Tools.Registry.register_module(Canopy.Tools.WorkspaceEngine)
          Canopy.Tools.Registry.register_module(Canopy.Tools.Engine)

          Canopy.Analytics.Iris.register_tools()
          Canopy.Analytics.Iris.announce_online()
          Canopy.Build.Conductor.register_tools()
          Canopy.Build.Conductor.announce_online()
        end)
      end

      # Install agent hooks at boot. Wrapped so a bad FS state never crashes startup.
      try do
        Canopy.Hooks.Manager.install!()
      rescue
        e ->
          require Logger

          Logger.warning(
            "[Canopy.Application] Hook install failed (non-fatal): #{Exception.message(e)}"
          )
      end

      {:ok, pid}
    end
  end

  # Snapshot live sessions while Repo is still up, before children stop.
  @impl true
  def prep_stop(state) do
    unless Application.get_env(:canopy, :env, :prod) == :test do
      _ = Canopy.Sessions.Persistence.save_state()
    end

    state
  end

  # Callback invoked by Phoenix when the endpoint configuration changes
  # in hot-code reloads (e.g., `mix phx.server` in dev mode).
  @impl true
  def config_change(changed, _new, removed) do
    CanopyWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_restore_sessions do
    unless Application.get_env(:canopy, :env, :prod) == :test do
      case Canopy.Sessions.Persistence.restore_state() do
        {:ok, result} ->
          require Logger

          Logger.info("[Canopy.Application] session restore #{inspect(result)}")

        other ->
          require Logger

          Logger.warning("[Canopy.Application] session restore failed: #{inspect(other)}")
      end
    end
  end
end
