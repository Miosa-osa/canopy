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
#   default   — general async work (10 concurrency)
#   heartbeats — agent heartbeat runs (5 concurrency, rate-limited)
#   sessions  — session lifecycle jobs (20 concurrency)
config :canopy, Oban,
  repo: Canopy.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron, crontab: []}
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

# MIOSA client defaults (overridden by runtime.exs in prod, dev.exs in dev)
config :canopy, :miosa_api_url, "http://localhost:4001"
config :canopy, :miosa_api_key, "dev-placeholder-key"

import_config "#{config_env()}.exs"
