defmodule Canopy.Workspaces.StackDetector do
  @moduledoc """
  Auto-detect project type from filesystem markers.

  Reads files under `root_path` using `File.exists?/1` and `File.read/1` only —
  no shell commands. Returns a list of stacks so monorepos surface multiple hits.
  """

  @type stack :: %{
          language: String.t(),
          framework: String.t() | nil,
          package_manager: String.t() | nil,
          monorepo: boolean(),
          markers_found: [String.t()]
        }

  @doc """
  Detect one or more stacks from the given root path.

  Returns `{:ok, [stack()]}` (list may be empty if nothing is detected).
  Returns `{:error, :invalid_path}` when `root_path` is `nil` or not a directory.
  """
  @spec detect(String.t() | nil) :: {:ok, [stack()]} | {:error, :invalid_path}
  def detect(nil), do: {:error, :invalid_path}

  def detect(root_path) do
    unless File.dir?(root_path) do
      {:error, :invalid_path}
    else
      monorepo = monorepo?(root_path)
      stacks = detect_stacks(root_path, monorepo)
      {:ok, stacks}
    end
  end

  # ---------------------------------------------------------------------------
  # Monorepo detection
  # ---------------------------------------------------------------------------

  @monorepo_markers ~w(turbo.json nx.json pnpm-workspace.yaml lerna.json)

  defp monorepo?(root_path) do
    Enum.any?(@monorepo_markers, fn marker ->
      File.exists?(Path.join(root_path, marker))
    end)
  end

  # ---------------------------------------------------------------------------
  # Per-language detection
  # ---------------------------------------------------------------------------

  defp detect_stacks(root_path, monorepo) do
    [
      detect_elixir(root_path, monorepo),
      detect_node(root_path, monorepo),
      detect_rust(root_path, monorepo),
      detect_go(root_path, monorepo),
      detect_python(root_path, monorepo),
      detect_ruby(root_path, monorepo)
    ]
    |> Enum.reject(&is_nil/1)
  end

  # Elixir — mix.exs required
  defp detect_elixir(root_path, monorepo) do
    if File.exists?(Path.join(root_path, "mix.exs")) do
      framework = detect_elixir_framework(root_path)

      %{
        language: "elixir",
        framework: framework,
        package_manager: "mix",
        monorepo: monorepo,
        markers_found: ["mix.exs"]
      }
    end
  end

  defp detect_elixir_framework(root_path) do
    with {:ok, content} <- File.read(Path.join(root_path, "mix.exs")) do
      cond do
        String.contains?(content, ":phoenix") -> "phoenix"
        String.contains?(content, "phoenix") -> "phoenix"
        true -> nil
      end
    else
      _ -> nil
    end
  end

  # Node / JS / TS — package.json required
  defp detect_node(root_path, monorepo) do
    pkg_path = Path.join(root_path, "package.json")

    if File.exists?(pkg_path) do
      {framework, markers} = detect_node_framework(root_path, pkg_path)
      package_manager = detect_node_pm(root_path)

      %{
        language: "typescript",
        framework: framework,
        package_manager: package_manager,
        monorepo: monorepo,
        markers_found: ["package.json" | markers]
      }
    end
  end

  defp detect_node_framework(root_path, pkg_path) do
    with {:ok, content} <- File.read(pkg_path) do
      cond do
        String.contains?(content, "\"next\"") or String.contains?(content, "\"next\":") ->
          {"nextjs", []}

        String.contains?(content, "@sveltejs/kit") ->
          {"sveltekit", []}

        String.contains?(content, "\"svelte\"") ->
          {"svelte", []}

        String.contains?(content, "\"react\"") or String.contains?(content, "\"react\":") ->
          {"react", []}

        String.contains?(content, "\"vite\"") ->
          {"vite", []}

        File.exists?(Path.join(root_path, "next.config.js")) or
            File.exists?(Path.join(root_path, "next.config.ts")) ->
          {"nextjs", ["next.config.js"]}

        File.exists?(Path.join(root_path, "svelte.config.js")) or
            File.exists?(Path.join(root_path, "svelte.config.ts")) ->
          {"sveltekit", ["svelte.config.js"]}

        true ->
          {nil, []}
      end
    else
      _ -> {nil, []}
    end
  end

  defp detect_node_pm(root_path) do
    cond do
      File.exists?(Path.join(root_path, "pnpm-lock.yaml")) -> "pnpm"
      File.exists?(Path.join(root_path, "yarn.lock")) -> "yarn"
      File.exists?(Path.join(root_path, "bun.lockb")) -> "bun"
      File.exists?(Path.join(root_path, "bun.lock")) -> "bun"
      File.exists?(Path.join(root_path, "package-lock.json")) -> "npm"
      true -> "npm"
    end
  end

  # Rust — Cargo.toml required
  defp detect_rust(root_path, monorepo) do
    if File.exists?(Path.join(root_path, "Cargo.toml")) do
      %{
        language: "rust",
        framework: nil,
        package_manager: "cargo",
        monorepo: monorepo,
        markers_found: ["Cargo.toml"]
      }
    end
  end

  # Go — go.mod required
  defp detect_go(root_path, monorepo) do
    if File.exists?(Path.join(root_path, "go.mod")) do
      %{
        language: "go",
        framework: detect_go_framework(root_path),
        package_manager: "go",
        monorepo: monorepo,
        markers_found: ["go.mod"]
      }
    end
  end

  defp detect_go_framework(root_path) do
    with {:ok, content} <- File.read(Path.join(root_path, "go.mod")) do
      cond do
        String.contains?(content, "gin-gonic/gin") -> "gin"
        String.contains?(content, "labstack/echo") -> "echo"
        String.contains?(content, "gofiber/fiber") -> "fiber"
        true -> nil
      end
    else
      _ -> nil
    end
  end

  # Python — pyproject.toml or requirements.txt
  defp detect_python(root_path, monorepo) do
    has_pyproject = File.exists?(Path.join(root_path, "pyproject.toml"))
    has_requirements = File.exists?(Path.join(root_path, "requirements.txt"))

    if has_pyproject or has_requirements do
      markers =
        for {flag, name} <- [
              {has_pyproject, "pyproject.toml"},
              {has_requirements, "requirements.txt"}
            ],
            flag,
            do: name

      framework = detect_python_framework(root_path)

      %{
        language: "python",
        framework: framework,
        package_manager: detect_python_pm(root_path),
        monorepo: monorepo,
        markers_found: markers
      }
    end
  end

  defp detect_python_framework(root_path) do
    sources =
      [
        Path.join(root_path, "pyproject.toml"),
        Path.join(root_path, "requirements.txt")
      ]
      |> Enum.find_value(fn path ->
        case File.read(path) do
          {:ok, content} -> content
          _ -> nil
        end
      end)

    case sources do
      nil ->
        nil

      content ->
        cond do
          String.contains?(content, "django") -> "django"
          String.contains?(content, "fastapi") -> "fastapi"
          String.contains?(content, "flask") -> "flask"
          true -> nil
        end
    end
  end

  defp detect_python_pm(root_path) do
    cond do
      File.exists?(Path.join(root_path, "uv.lock")) -> "uv"
      File.exists?(Path.join(root_path, "Pipfile.lock")) -> "pipenv"
      File.exists?(Path.join(root_path, "poetry.lock")) -> "poetry"
      true -> "pip"
    end
  end

  # Ruby — Gemfile required
  defp detect_ruby(root_path, monorepo) do
    if File.exists?(Path.join(root_path, "Gemfile")) do
      framework =
        with {:ok, content} <- File.read(Path.join(root_path, "Gemfile")) do
          cond do
            String.contains?(content, "rails") -> "rails"
            String.contains?(content, "sinatra") -> "sinatra"
            true -> nil
          end
        else
          _ -> nil
        end

      %{
        language: "ruby",
        framework: framework,
        package_manager: "bundler",
        monorepo: monorepo,
        markers_found: ["Gemfile"]
      }
    end
  end
end
