import Config

# Test database — SQL sandbox for transaction isolation between tests
config :canopy, Canopy.Repo,
  username: System.get_env("PGUSER") || "rhl",
  password: System.get_env("PGPASSWORD") || "",
  hostname: "localhost",
  database: "canopy_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Test endpoint — server: false because we use ConnCase for HTTP tests
config :canopy, CanopyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+38WqF2FXshXAdB6HCZGmrxBJNS2XBQ1V0XWXFWdPawiseW2z5s9XjkKZ9eOygz+",
  server: false

# Oban — use inline testing mode so jobs execute synchronously in tests
config :canopy, Oban, testing: :inline

# Silence logger in tests — warnings and above only
config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
config :phoenix, sort_verified_routes_query_params: true
