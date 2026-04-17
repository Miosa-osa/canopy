defmodule Canopy.Application do
  @moduledoc """
  OTP Application entry point for Canopy.

  Defines the supervision tree in startup order. Each child is annotated with
  its role. The tree uses the `one_for_one` strategy — a failed child restarts
  independently without taking down siblings.
  """

  use Application

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

      # 5. Finch — HTTP connection pool used by Req (MIOSA client, quota APIs)
      {Finch, name: Canopy.Finch},

      # 6. Oban — Postgres-backed job queue (heartbeats, cron, async enforcement)
      {Oban, Application.fetch_env!(:canopy, Oban)},

      # 7. Runtime Registry — unique Registry for RuntimeAdapter process lookup
      {Registry, keys: :unique, name: Canopy.Runtimes.Registry},

      # 8. Sessions Supervisor — DynamicSupervisor; one child per running session
      Canopy.Sessions.Supervisor,

      # 9. Adapter registrar — registers built-in adapters into the Runtime Registry.
      #    Must start after the Registry (7) and before the Endpoint (10).
      {Task, fn -> Canopy.Runtimes.register_adapter(Canopy.Runtimes.ClaudeLocal) end},

      # 10. Phoenix Endpoint — HTTP server, last so all deps are ready
      CanopyWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Canopy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Callback invoked by Phoenix when the endpoint configuration changes
  # in hot-code reloads (e.g., `mix phx.server` in dev mode).
  @impl true
  def config_change(changed, _new, removed) do
    CanopyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
