defmodule Canopy.MixProject do
  use Mix.Project

  def project do
    [
      app: :canopy,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Canopy.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Framework
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:bandit, "~> 1.5"},
      # Telemetry
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      # Serialization
      {:jason, "~> 1.2"},
      # DNS clustering (multi-node prep)
      {:dns_cluster, "~> 0.2.0"},
      # Background jobs (replaces Quantum)
      {:oban, "~> 2.18"},
      # HTTP client
      {:req, "~> 0.5"},
      # OpenAPI spec generation
      {:open_api_spex, "~> 3.21"},
      # Authentication
      {:guardian, "~> 2.3"},
      {:bcrypt_elixir, "~> 3.1"},
      # pgvector support
      {:pgvector, "~> 0.3"},
      # Nano IDs for human-readable slugs
      {:nanoid, "~> 2.1"},
      # CORS for dev (Tauri devUrl 5280 → Phoenix 9190)
      {:corsica, "~> 2.1"},
      # Rate limiting — ETS backend; redis backend available for multi-node
      {:hammer, "~> 6.2"},
      {:hammer_backend_redis, "~> 6.1", optional: true},
      # YAML parsing for agent persona frontmatter (mix canopy.seed.agents)
      {:yaml_elixir, "~> 2.11"},
      # Test-only
      {:mox, "~> 1.2", only: :test},
      {:ex_machina, "~> 2.8", only: :test},
      # Dev/test tooling
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
