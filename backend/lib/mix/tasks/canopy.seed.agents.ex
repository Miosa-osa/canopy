defmodule Mix.Tasks.Canopy.Seed.Agents do
  @shortdoc "Seed agents table from priv/agents markdown files"

  @moduledoc """
  Seeds the `agents` table from `priv/agents/<category>/[sub/...]/<slug>.md` files.

  ## Conflict resolution

  All markdown files are discovered recursively. The **top-level directory** under
  `priv/agents/` is the canonical `category` for every file regardless of nesting
  depth (e.g., `technology/quality-assurance/test-engineering/foo.md` → category
  `technology`).

  When two files from **different** top-level categories produce the same base slug
  (filename without `.md`), both are kept by appending the category to the slug:

      technology/…/accessibility-auditor.md  → slug: accessibility-auditor-technology
      testing/accessibility-auditor.md       → slug: accessibility-auditor-testing

  Files whose base slug is globally unique keep their base slug unchanged.

  This strategy produces one agent per source file (target: all 337 source files
  → 337 unique slugs in the DB).

  ## Category normalisation

  The 19 canonical categories are enforced. Any top-level directory not in the
  canonical list is coerced to `specialized` with a warning. The empty `<cat> 2`
  macOS Finder duplicate directories are silently excluded.

  ## Idempotency

  Repeat runs upsert by slug — no duplicates are created.

  ## Emoji / title defaults

  If a file's frontmatter is missing `emoji`, a sensible default is derived from
  the category (see `@category_emoji`). If `name` is missing, the slug is used as
  a human-readable fallback.

  ## Usage

      mix canopy.seed.agents                # all categories
      mix canopy.seed.agents --dry-run      # preview without inserting
      mix canopy.seed.agents --only engineering,sales
  """

  use Mix.Task

  alias Canopy.Agents
  alias Canopy.Agents.Agent
  alias Canopy.Repo

  @requirements ["app.start"]

  # The 19 canonical top-level categories (matches desktop/src/lib/domain/agents/types.ts).
  @canonical_categories ~w(
    academic
    creative-content
    design
    engineering
    executive
    game-development
    growth
    marketing
    operations
    paid-media
    product
    project-management
    revenue
    sales
    spatial-computing
    specialized
    support
    technology
    testing
  )

  # Fallback emoji per category when frontmatter omits it.
  @category_emoji %{
    "academic" => "🎓",
    "creative-content" => "✍️",
    "design" => "🎨",
    "engineering" => "⚙️",
    "executive" => "👔",
    "game-development" => "🎮",
    "growth" => "📈",
    "marketing" => "📣",
    "operations" => "🔧",
    "paid-media" => "💰",
    "product" => "📦",
    "project-management" => "📋",
    "revenue" => "💵",
    "sales" => "🤝",
    "spatial-computing" => "🥽",
    "specialized" => "🤖",
    "support" => "🛟",
    "technology" => "💻",
    "testing" => "🧪"
  }

  # Legacy adapter names → v2 runtime_type. Falls back to claude-local.
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
    # always seen. Resolve from __DIR__ so the task works regardless of cwd.
    # __DIR__ = backend/lib/mix/tasks; go up 3 to reach backend/, then priv/agents.
    root = Path.expand(Path.join([__DIR__, "..", "..", "..", "priv", "agents"]))

    paths = list_files(root, only)
    source_count = length(paths)

    # Pre-compute slug map: base_slug → list of paths sharing that slug.
    # This drives conflict resolution before any DB interaction.
    slug_map = build_slug_map(paths, root)

    {inserted, updated, conflicts_resolved, invalid} =
      slug_map
      |> Enum.sort_by(fn {slug, _} -> slug end)
      |> Enum.reduce({0, 0, 0, 0}, fn {_final_slug, entry}, acc ->
        process_entry(entry, root, dry_run, acc)
      end)

    Mix.shell().info("""

    Done.
      source files:       #{source_count}
      inserted:           #{inserted}
      updated:            #{updated}
      conflicts resolved: #{conflicts_resolved}  (slug suffixed with category)
      invalid:            #{invalid}  (frontmatter parse errors)
      total in DB (est.): #{inserted + updated}
    """)
  end

  # ---------------------------------------------------------------------------
  # Slug-map construction (conflict resolution happens here, before DB I/O)
  # ---------------------------------------------------------------------------

  @doc false
  @spec build_slug_map([Path.t()], Path.t()) :: %{String.t() => map()}
  def build_slug_map(paths, root) do
    # Group paths by base slug.
    by_base_slug =
      Enum.group_by(paths, fn path -> Path.basename(path, ".md") end)

    # For each group, determine the final slug for each file.
    Enum.flat_map(by_base_slug, fn {base_slug, group_paths} ->
      if length(group_paths) == 1 do
        # Unique slug — no qualification needed.
        [path] = group_paths
        [{base_slug, %{path: path, slug: base_slug, conflict: false}}]
      else
        # Conflict — qualify every copy with its top-level category.
        Enum.map(group_paths, fn path ->
          relative = Path.relative_to(path, root)
          top_cat = relative |> Path.split() |> List.first() |> normalise_category()
          qualified = "#{base_slug}-#{top_cat}"
          Mix.shell().info("  [conflict] #{base_slug} → #{qualified}  (#{relative})")
          {qualified, %{path: path, slug: qualified, conflict: true}}
        end)
      end
    end)
    |> Map.new()
  end

  # ---------------------------------------------------------------------------
  # File walking
  # ---------------------------------------------------------------------------

  defp list_files(root, only) do
    case File.ls(root) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&File.dir?(Path.join(root, &1)))
        # Exclude macOS Finder " 2" duplicates — they are always empty.
        |> Enum.reject(&String.ends_with?(&1, " 2"))
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
  # Per-entry processing
  # ---------------------------------------------------------------------------

  defp process_entry(
         %{path: path, slug: final_slug, conflict: conflict},
         root,
         dry_run,
         {ins, upd, conf, inv}
       ) do
    with {:ok, body} <- File.read(path),
         {:ok, frontmatter} <- extract_frontmatter(body),
         {:ok, attrs} <- build_attrs(frontmatter, body, path, root, final_slug) do
      {op, _result} = upsert(attrs, dry_run)

      case op do
        :inserted -> {ins + 1, upd, conf + if(conflict, do: 1, else: 0), inv}
        :updated -> {ins, upd + 1, conf + if(conflict, do: 1, else: 0), inv}
        :error -> {ins, upd, conf, inv + 1}
      end
    else
      {:error, reason} ->
        relative = Path.relative_to(path, root)
        Mix.shell().error("  [invalid] #{relative}: #{inspect(reason)}")
        {ins, upd, conf, inv + 1}
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

  # Extracts the body portion of a markdown file — everything after the closing
  # `---` of the YAML frontmatter block. Returns "" when no frontmatter is found
  # (so bare-body files still get their content stored) or when body is blank.
  @spec extract_persona_body(String.t()) :: String.t()
  defp extract_persona_body(raw_body) do
    case Regex.run(@frontmatter_regex, raw_body) do
      [full_match | _] ->
        raw_body
        |> String.slice(String.length(full_match)..-1//1)
        |> String.trim()

      nil ->
        String.trim(raw_body)
    end
  end

  defp build_attrs(frontmatter, raw_body, path, root, final_slug) do
    relative = Path.relative_to(path, root)
    raw_category = relative |> Path.split() |> List.first()
    category = normalise_category(raw_category)

    if category != raw_category do
      Mix.shell().info("  [category] #{raw_category} → #{category}  (#{relative})")
    end

    legacy_adapter =
      frontmatter["adapter"]
      |> to_string()
      |> String.trim()

    # Fall back to claude-local when the legacy adapter name is unknown.
    default_runtime = Map.get(@adapter_mapping, legacy_adapter) || "claude-local"

    # Emoji default: use frontmatter value, or derive from category.
    _emoji =
      case frontmatter["emoji"] do
        nil -> Map.get(@category_emoji, category, "🤖")
        "" -> Map.get(@category_emoji, category, "🤖")
        e -> e
      end

    # Name default: use frontmatter value, or humanise the slug.
    name =
      case frontmatter["name"] do
        nil -> humanise(final_slug)
        "" -> humanise(final_slug)
        n -> n
      end

    {:ok,
     %{
       slug: final_slug,
       category: category,
       name: name,
       description: frontmatter["description"],
       persona_path: relative,
       # DB-authoritative persona content: body extracted from the markdown file
       # after the YAML frontmatter block. persona_path remains as a backward
       # reference to the seed source; never read at runtime.
       persona_markdown: extract_persona_body(raw_body),
       default_runtime: default_runtime,
       default_model: frontmatter["model"],
       # Only use frontmatter heartbeat_cron — never inject a default.
       heartbeat_cron: frontmatter["heartbeat"],
       budget_monthly_usd: to_decimal(frontmatter["budget"])
     }}
  end

  # ---------------------------------------------------------------------------
  # Category normalisation
  # ---------------------------------------------------------------------------

  @doc false
  @spec normalise_category(String.t()) :: String.t()
  def normalise_category(raw) do
    normalised = raw |> String.downcase() |> String.replace("_", "-")

    if normalised in @canonical_categories do
      normalised
    else
      Mix.shell().info("  [warn] non-canonical category #{inspect(raw)} → specialized")
      "specialized"
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp humanise(slug) do
    slug
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
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
