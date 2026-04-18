# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# Base application configuration — applies to all environments.
# Environment-specific overrides are in dev.exs, test.exs, and runtime.exs.
import Config

config :canopy,
  ecto_repos: [Canopy.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Phoenix endpoint — dev/prod/test override port and secret_key_base below
config :canopy, CanopyWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: CanopyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Canopy.PubSub,
  live_view: [signing_salt: "XYj9WXI0"]

# Oban — Postgres-backed job queue.
# Queues:
#   default    — general async work (10 concurrency)
#   heartbeats — agent heartbeat runs (5 concurrency, rate-limited)
#   sessions   — session lifecycle jobs (20 concurrency)
#
# Static crontab — only for globally-scheduled system jobs. Per-agent heartbeats
# use self-rescheduling (see Canopy.Heartbeat.Worker), not static entries.
config :canopy, Oban,
  repo: Canopy.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       # Hourly spend snapshots for all enabled budgets
       {"0 * * * *", Canopy.Budgets.Snapshotter}
     ]}
  ],
  queues: [default: 10, heartbeats: 5, sessions: 20]

# Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# JSON library
config :phoenix, :json_library, Jason

# OpenApiSpex — provide spec via the ApiSpec module
config :open_api_spex, :spec_module, CanopyWeb.ApiSpec

# Hammer — ETS-backed rate limiting. 4-hour expiry window, cleanup every 10 min.
# In multi-node deployments, swap backend for Hammer.Backend.Redis.
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

# MIOSA client defaults (overridden by runtime.exs in prod, dev.exs in dev)
config :canopy, :miosa_api_url, "http://localhost:4001"
config :canopy, :miosa_api_key, "dev-placeholder-key"

# ---------------------------------------------------------------------------
# CanopyMCP — MCP stdio server configuration
# ---------------------------------------------------------------------------
# Controls the MCP server started by `mix canopy.mcp`.
# This section is owned by @backend-elixir. Do not add Oban or Phoenix keys here.
#
#   :protocol_version — MCP spec version this server declares (do not change
#                       unless CanopyMCP.Capabilities is updated to match).
#   :server_name      — Identifier reported in the MCP initialize handshake.
#   :server_version   — Semantic version of the Canopy MCP implementation.
#
config :canopy, :mcp,
  protocol_version: "2024-11-05",
  server_name: "canopy-mcp",
  server_version: "0.1.0"

import_config "#{config_env()}.exs"
