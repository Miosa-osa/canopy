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

      # 9b. Sessions Supervisor — DynamicSupervisor; one child per running session
      Canopy.Sessions.Supervisor,

      # 10. Task Supervisor — for fire-and-forget tasks (e.g. boot heartbeat registration)
      {Task.Supervisor, name: Canopy.TaskSupervisor},

      # 10. Phoenix Endpoint — HTTP server, last so all deps are ready
      CanopyWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Canopy.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      # Register heartbeats for all hired agents after Oban has fully started.
      # Skipped in :test env — the SQL Sandbox requires explicit ownership per
      # process, and this Task runs outside any test process boundary.
      unless Application.get_env(:canopy, :env, :prod) == :test do
        Task.Supervisor.start_child(Canopy.TaskSupervisor, fn ->
          Process.sleep(500)
          HeartbeatRegistrar.register_all_hired()
          Canopy.Tools.register_all_builtins()
        end)
      end

      {:ok, pid}
    end
  end

  # Callback invoked by Phoenix when the endpoint configuration changes
  # in hot-code reloads (e.g., `mix phx.server` in dev mode).
  @impl true
  def config_change(changed, _new, removed) do
    CanopyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
