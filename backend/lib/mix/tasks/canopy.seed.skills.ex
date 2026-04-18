defmodule Mix.Tasks.Canopy.Seed.Skills do
  @shortdoc "Seed skills table from priv/skills markdown files or external registry"

  @moduledoc """
  Seeds the `skills` table from `priv/skills/*.md` files or an external registry.

  Each markdown file must have YAML frontmatter with at minimum: `name` and
  `description`. Optional fields: `provider_format`, `tags`.

  Usage:

      mix canopy.seed.skills                    # seed from priv/skills/
      mix canopy.seed.skills --dry-run          # preview without inserting
      mix canopy.seed.skills --from clawhub     # import from ClawHub registry
      mix canopy.seed.skills --from skills_sh   # import from Skills.sh registry
  """

  use Mix.Task

  alias Canopy.Skills
  alias Canopy.Skills.Registry.Clawhub
  alias Canopy.Skills.Registry.SkillsSh

  @requirements ["app.start"]

  @frontmatter_regex ~r/\A---\n(.+?)\n---\n/s

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [dry_run: :boolean, from: :string])

    dry_run = Keyword.get(opts, :dry_run, false)
    source = Keyword.get(opts, :from)

    if source do
      run_registry_import(source, dry_run)
    else
      run_local_seed(dry_run)
    end
  end

  # ---------------------------------------------------------------------------
  # Registry import
  # ---------------------------------------------------------------------------

  defp run_registry_import(source, dry_run) when source in ["clawhub", "skills_sh"] do
    Mix.shell().info(
      "Importing skills from #{source}#{if dry_run, do: " (DRY RUN)", else: ""}..."
    )

    {:ok, raw_skills} = fetch_from_registry(source)
    Mix.shell().info("Fetched #{length(raw_skills)} skills from #{source}.")

    {inserted, errors} =
      Enum.reduce(raw_skills, {0, 0}, fn raw, {ok_count, err_count} ->
        attrs =
          Map.merge(raw, %{
            "source" => source,
            "imported_at" => DateTime.utc_now()
          })

        if dry_run do
          Mix.shell().info("  [dry-run] would upsert: #{raw["slug"] || "(no slug)"}")
          {ok_count + 1, err_count}
        else
          case Skills.upsert(attrs) do
            {:ok, _} ->
              {ok_count + 1, err_count}

            {:error, changeset} ->
              Mix.shell().error("  error: #{inspect(changeset.errors)}")
              {ok_count, err_count + 1}
          end
        end
      end)

    Mix.shell().info("\nDone. imported: #{inserted}  errors: #{errors}")
  end

  defp run_registry_import(source, _) do
    Mix.raise("Unknown source '#{source}'. Must be 'clawhub' or 'skills_sh'.")
  end

  defp fetch_from_registry("clawhub"), do: Clawhub.fetch_all()
  defp fetch_from_registry("skills_sh"), do: SkillsSh.fetch_all()

  # ---------------------------------------------------------------------------
  # Local seed from priv/skills/
  # ---------------------------------------------------------------------------

  defp run_local_seed(dry_run) do
    Mix.shell().info(
      "Seeding skills from priv/skills/#{if dry_run, do: " (DRY RUN)", else: ""}..."
    )

    root = Path.expand(Path.join([__DIR__, "..", "..", "..", "priv", "skills"]))

    {inserted, updated, invalid} =
      root
      |> list_skill_files()
      |> Enum.reduce({0, 0, 0}, fn path, acc ->
        process_file(path, root, dry_run, acc)
      end)

    Mix.shell().info("""

    Done.
      inserted: #{inserted}
      updated:  #{updated}
      invalid:  #{invalid}
    """)
  end

  defp list_skill_files(root) do
    case File.ls(root) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.map(&Path.join(root, &1))

      {:error, :enoent} ->
        Mix.shell().error("priv/skills/ not found — creating empty directory.")
        File.mkdir_p!(root)
        []

      {:error, reason} ->
        Mix.raise("Failed to list priv/skills/: #{inspect(reason)}")
    end
  end

  defp process_file(path, _, dry_run, {ins, upd, inv}) do
    with {:ok, body} <- File.read(path),
         {:ok, frontmatter, content} <- parse_file(body),
         {:ok, attrs} <- build_attrs(frontmatter, content, path) do
      apply_upsert(attrs, path, dry_run, {ins, upd, inv})
    else
      {:error, reason} ->
        Mix.shell().error("  error #{Path.basename(path)}: #{inspect(reason)}")
        {ins, upd, inv + 1}
    end
  end

  @spec apply_upsert(map(), String.t(), boolean(), {integer(), integer(), integer()}) ::
          {integer(), integer(), integer()}
  defp apply_upsert(attrs, _, true, {ins, upd, inv}) do
    Mix.shell().info("  [dry-run] would upsert: #{attrs["slug"]}")
    {ins + 1, upd, inv}
  end

  defp apply_upsert(attrs, path, false, {ins, upd, inv}) do
    case Skills.upsert(attrs) do
      {:ok, skill} ->
        if skill.inserted_at == skill.updated_at,
          do: {ins + 1, upd, inv},
          else: {ins, upd + 1, inv}

      {:error, changeset} ->
        Mix.shell().error("  invalid #{Path.basename(path)}: #{inspect(changeset.errors)}")
        {ins, upd, inv + 1}
    end
  end

  defp parse_file(body) do
    case Regex.run(@frontmatter_regex, body, capture: :all_but_first) do
      [yaml] ->
        case YamlElixir.read_from_string(yaml) do
          {:ok, map} when is_map(map) ->
            content =
              body
              |> String.replace(~r/\A---\n.+?\n---\n/s, "")
              |> String.trim()

            {:ok, map, content}

          {:ok, _} ->
            {:error, :frontmatter_not_a_map}

          {:error, err} ->
            {:error, {:yaml_error, err}}
        end

      nil ->
        {:error, :no_frontmatter}
    end
  end

  defp build_attrs(frontmatter, content, path) do
    slug = path |> Path.basename(".md")

    {:ok,
     %{
       "slug" => slug,
       "name" => frontmatter["name"] || slug,
       "description" => frontmatter["description"],
       "provider_format" => frontmatter["provider_format"] || "generic",
       "content" => content,
       "source" => "local",
       "tags" => frontmatter["tags"] || [],
       "enabled" => true,
       "imported_at" => DateTime.utc_now()
     }}
  end
end
