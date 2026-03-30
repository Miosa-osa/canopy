# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :canopy,
  ecto_repos: [Canopy.Repo],
  generators: [timestamp_type: :utc_datetime],
  auth_mode: "authenticated"

# Configure the endpoint
config :canopy, CanopyWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: CanopyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Canopy.PubSub,
  live_view: [signing_salt: "vRCERO/F"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Register text/event-stream so Phoenix accepts SSE requests
config :mime, :types, %{
  "text/event-stream" => ["event-stream"]
}

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Guardian JWT config
config :canopy, Canopy.Guardian,
  issuer: "canopy",
  secret_key: "dev-secret-key-change-in-production"

# Quantum scheduler — jobs loaded from DB at runtime
config :canopy, Canopy.Scheduler, jobs: []

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
