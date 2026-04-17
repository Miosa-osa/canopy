import Config

# runtime.exs is evaluated at runtime (not at compile time) for all environments,
# including releases. Load secrets from environment variables here.

if System.get_env("PHX_SERVER") do
  config :canopy, CanopyWeb.Endpoint, server: true
end

config :canopy, CanopyWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "9190"))]

if config_env() in [:dev, :prod] do
  # CORS origins, overridable via env. Comma-separated.
  cors_origins =
    "CANOPY_CORS_ORIGINS"
    |> System.get_env("")
    |> String.split(",", trim: true)

  if cors_origins != [] do
    config :canopy, :cors_origins, cors_origins
  end
end

if config_env() == :prod do
  # ---------------------------------------------------------------------------
  # Required environment variables — application will not start without these.
  # No defaults. Crash loudly at boot, not silently at runtime.
  # ---------------------------------------------------------------------------

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      Environment variable DATABASE_URL is required in production.
      Example: ecto://USER:PASS@HOST/DATABASE
      """

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      Environment variable SECRET_KEY_BASE is required in production.
      Generate one with: mix phx.gen.secret
      """

  miosa_api_url =
    System.get_env("MIOSA_API_URL") ||
      raise """
      Environment variable MIOSA_API_URL is required in production.
      This is the base URL of the MIOSA compute API.
      """

  miosa_api_key =
    System.get_env("MIOSA_API_KEY") ||
      raise """
      Environment variable MIOSA_API_KEY is required in production.
      This is the bearer token for authenticating with the MIOSA API.
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []
  host = System.get_env("PHX_HOST") || "canopy.app"

  config :canopy, Canopy.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :canopy, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :canopy, :miosa_api_url, miosa_api_url
  config :canopy, :miosa_api_key, miosa_api_key

  config :canopy, CanopyWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base
end
