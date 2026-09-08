import Config

# Test database — SQL sandbox for transaction isolation between tests
config :canopy, Canopy.Repo,
  username: System.get_env("PGUSER") || "rhl",
  password: System.get_env("PGPASSWORD") || "",
  hostname: System.get_env("PGHOST") || "localhost",
  port: String.to_integer(System.get_env("PGPORT") || "5432"),
  database: "canopy_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Test endpoint — server: false because we use ConnCase for HTTP tests
config :canopy, CanopyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+38WqF2FXshXAdB6HCZGmrxBJNS2XBQ1V0XWXFWdPawiseW2z5s9XjkKZ9eOygz+",
  server: false

# Oban — use manual testing mode. Jobs are inserted into the test sandbox but
# NOT auto-executed. Tests call `perform/1` directly on workers, or use
# `Oban.Testing.assert_enqueued/2`. We cannot use `:inline` because the
# Heartbeat worker's self-rescheduling pattern (insert-next-job from within
# perform) would create an infinite loop under inline execution.
config :canopy, Oban, testing: :manual

# Heartbeat — suppress boot registration in test env to avoid SQL sandbox
# ownership errors from the unsupervised Task in Application.start/2
config :canopy, :env, :test

# MIOSA — use the Mox mock in tests so no real HTTP calls are made.
# Tests that need a configured client set both values; tests that verify
# the "not configured" path leave them as empty strings.
config :canopy, :miosa_api_url, ""
config :canopy, :miosa_api_key, ""
config :canopy, :miosa_client, Canopy.Miosa.MockClient

# Silence logger in tests — warnings and above only
config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
config :phoenix, sort_verified_routes_query_params: true

# Rate limiter — disabled in test env so ConnCase tests never hit 429.
# The plug reads this at compile_env; test suite always passes through.
config :canopy, CanopyWeb.Plugs.RateLimiter, enabled: false
