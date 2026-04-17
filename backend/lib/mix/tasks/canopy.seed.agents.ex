defmodule Mix.Tasks.Canopy.Seed.Agents do
  @shortdoc "Seed agents table from priv/agents markdown files"

  @moduledoc """
  Seeds the `agents` table from `priv/agents/<category>/<slug>.md` files.

  Reads every markdown file under `priv/agents/`, parses YAML frontmatter, maps
  the legacy `adapter:` field to a v2 runtime_type, and upserts each agent by
  slug. Idempotent — safe to rerun.

  Usage:

      mix canopy.seed.agents                # all categories
      mix canopy.seed.agents --dry-run      # preview without inserting
      mix canopy.seed.agents --only engineering,sales
  """

  use Mix.Task

  alias Canopy.Agents
  alias Canopy.Agents.Agent
  alias Canopy.Repo

  @requirements ["app.start"]

  # Legacy adapter names → v2 runtime_type. `nil` means skip (no v2 equivalent).
  @adapter_mapping %{
    "claude-code" => "claude-local",
    "claude_code" => "claude-local",
    "claude-local" => "claude-local",
    "codex" => "codex-local",
    "codex-local" => "codex-local",
    "gemini" => "gemini-local",
    "gemini-local" => "gemini-local",
    "cursor" => "cursor-local",
    "cursor-local" => "cursor-local",
    "opencode" => "opencode-local",
    "opencode-local" => "opencode-local",
    "aider" => "aider-local",
    "aider-local" => "aider-local",
    "windsurf" => "windsurf-local",
    "windsurf-local" => "windsurf-local",
    "pi" => "pi-local",
    "pi-local" => "pi-local",
    "hermes" => "hermes-local",
    "hermes-local" => "hermes-local"
  }

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [dry_run: :boolean, only: :string])
    dry_run = Keyword.get(opts, :dry_run, false)
    only = opts |> Keyword.get(:only) |> parse_only()

    Mix.shell().info(
      "Seeding agents from priv/agents#{if dry_run, do: " (DRY RUN)", else: ""}..."
    )

    # Read from source priv/ directly (not _build copy) so the latest files are
    # always seen — the _build/priv/ gets out of sync as agents are added.
    # Resolve from __DIR__ (this source file's location) so the task works
    # regardless of the shell's cwd when invoked.
    # __DIR__ = backend/lib/mix/tasks; go up 3 to reach backend/, then priv/agents
    root = Path.expand(Path.join([__DIR__, "..", "..", "..", "priv", "agents"]))

    {inserted, updated, skipped, invalid} =
      root
      |> list_files(only)
      |> Enum.reduce({0, 0, 0, 0}, fn path, acc ->
        process_file(path, root, dry_run, acc)
      end)

    Mix.shell().info("""

    Done.
      inserted: #{inserted}
      updated:  #{updated}
      skipped:  #{skipped}  (unmappable legacy adapter, soft-warn)
      invalid:  #{invalid}  (frontmatter parse errors)
    """)
  end

  # ---------------------------------------------------------------------------
  # File walking
  # ---------------------------------------------------------------------------

  defp list_files(root, only) do
    case File.ls(root) do
      {:ok, categories} ->
        # Recursive glob — some categories (creative-content, growth, technology)
        # have nested subcategory directories with agents several levels deep.
        # The top-level dir is still the canonical `category` attribute.
        categories
        |> Enum.filter(&File.dir?(Path.join(root, &1)))
        |> Enum.filter(&(only == :all or &1 in only))
        |> Enum.flat_map(fn cat ->
          Path.join(root, cat) |> Path.join("**/*.md") |> Path.wildcard()
        end)

      {:error, :enoent} ->
        Mix.raise("priv/agents/ not found — run from the Phoenix app root.")

      {:error, reason} ->
        Mix.raise("Failed to list priv/agents/: #{inspect(reason)}")
    end
  end

  defp parse_only(nil), do: :all
  defp parse_only(""), do: :all
  defp parse_only(str), do: String.split(str, ",", trim: true)

  # ---------------------------------------------------------------------------
  # Per-file processing
  # ---------------------------------------------------------------------------

  defp process_file(path, root, dry_run, {ins, upd, skp, inv}) do
    with {:ok, body} <- File.read(path),
         {:ok, frontmatter} <- extract_frontmatter(body),
         {:ok, attrs} <- build_attrs(frontmatter, path, root) do
      case attrs do
        :skip_unmappable ->
          {ins, upd, skp + 1, inv}

        %{} = attrs ->
          {op, _result} = upsert(attrs, dry_run)

          case op do
            :inserted -> {ins + 1, upd, skp, inv}
            :updated -> {ins, upd + 1, skp, inv}
            :error -> {ins, upd, skp, inv + 1}
          end
      end
    else
      {:error, reason} ->
        Mix.shell().error("  invalid #{Path.relative_to(path, root)}: #{inspect(reason)}")
        {ins, upd, skp, inv + 1}
    end
  end

  # ---------------------------------------------------------------------------
  # Frontmatter + attribute building
  # ---------------------------------------------------------------------------

  @frontmatter_regex ~r/\A---\n(.+?)\n---\n/s

  defp extract_frontmatter(body) do
    case Regex.run(@frontmatter_regex, body, capture: :all_but_first) do
      [yaml] ->
        case YamlElixir.read_from_string(yaml) do
          {:ok, map} when is_map(map) -> {:ok, map}
          {:ok, _other} -> {:error, :frontmatter_not_a_map}
          {:error, err} -> {:error, {:yaml_error, err}}
        end

      nil ->
        {:error, :no_frontmatter}
    end
  end

  defp build_attrs(frontmatter, path, root) do
    relative = Path.relative_to(path, root)
    category = relative |> Path.split() |> List.first()
    slug = path |> Path.basename(".md")

    legacy_adapter =
      frontmatter["adapter"]
      |> to_string()
      |> String.trim()

    # Mapping falls back to claude-local when the legacy adapter name isn't
    # known. Users can change `default_runtime` per-agent after import.
    default_runtime = Map.get(@adapter_mapping, legacy_adapter) || "claude-local"

    {:ok,
     %{
       slug: slug,
       category: category,
       name: frontmatter["name"] || slug,
       description: frontmatter["description"],
       persona_path: relative,
       default_runtime: default_runtime,
       default_model: frontmatter["model"],
       heartbeat_cron: frontmatter["heartbeat"],
       budget_monthly_usd: to_decimal(frontmatter["budget"])
     }}
  end

  defp to_decimal(nil), do: nil
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n)
  defp to_decimal(s) when is_binary(s), do: Decimal.new(s)
  defp to_decimal(_other), do: nil

  # ---------------------------------------------------------------------------
  # Upsert
  # ---------------------------------------------------------------------------

  defp upsert(_attrs, true = _dry_run), do: {:inserted, :dry_run}

  defp upsert(attrs, false) do
    case Agents.get_by_slug(attrs.slug) do
      {:ok, existing} ->
        changeset = Agent.changeset(existing, attrs)

        case Repo.update(changeset) do
          {:ok, _updated} -> {:updated, :ok}
          {:error, reason} -> {:error, reason}
        end

      {:error, :not_found} ->
        changeset = Agent.changeset(%Agent{}, attrs)

        case Repo.insert(changeset) do
          {:ok, _inserted} -> {:inserted, :ok}
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
