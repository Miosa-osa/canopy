defmodule Canopy.Agents.WorkspaceSync do
  @moduledoc """
  Imports workspace-local agent markdown from `.canopy/agents/**/*.md`.

  Workspace markdown is the portable source format. The database remains the
  runtime cache because sessions, heartbeats, MCP prompts, and the agent UI all
  read agent rows.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Agents.Agent
  alias Canopy.Repo
  alias Canopy.Workspaces

  @frontmatter_regex ~r/\A---\s*\n(.*?)\n---\s*(?:\n|\z)/s
  @canonical_categories ~w(
    academic creative-content design engineering executive game-development
    growth marketing operations paid-media product project-management revenue
    sales spatial-computing specialized support technology testing
  )

  @type sync_result :: %{
          workspace_slug: String.t(),
          root_path: String.t(),
          scanned: non_neg_integer(),
          imported: non_neg_integer(),
          updated: non_neg_integer(),
          skipped: non_neg_integer(),
          errors: [map()]
        }

  @doc "Scans `.canopy/agents/**/*.md` for a workspace and upserts agent rows."
  @spec sync(String.t()) :: {:ok, sync_result()} | {:error, :not_found | term()}
  def sync(workspace_slug) when is_binary(workspace_slug) do
    with {:ok, workspace} <- Workspaces.get_by_slug(workspace_slug) do
      root = Path.expand(workspace.root_path)
      agents_root = Path.join([root, ".canopy", "agents"])
      files = markdown_files(agents_root)

      result =
        Enum.reduce(files, base_result(workspace_slug, root), fn path, acc ->
          case import_file(path, root, workspace_slug) do
            {:inserted, agent} ->
              acc
              |> Map.update!(:imported, &(&1 + 1))
              |> Map.update!(:scanned, &(&1 + 1))
              |> add_agent(agent)

            {:updated, agent} ->
              acc
              |> Map.update!(:updated, &(&1 + 1))
              |> Map.update!(:scanned, &(&1 + 1))
              |> add_agent(agent)

            {:skipped, reason} ->
              acc
              |> Map.update!(:skipped, &(&1 + 1))
              |> Map.update!(:scanned, &(&1 + 1))
              |> add_error(path, reason)

            {:error, reason} ->
              acc
              |> Map.update!(:skipped, &(&1 + 1))
              |> Map.update!(:scanned, &(&1 + 1))
              |> add_error(path, reason)
          end
        end)

      {:ok, Map.delete(result, :agents)}
    end
  end

  @doc "Returns the absolute path for an agent persona_path backed by a workspace file."
  @spec workspace_file_path(String.t() | nil) :: {:ok, String.t()} | :error
  def workspace_file_path("workspace:" <> rest) do
    case String.split(rest, ":", parts: 2) do
      [workspace_slug, rel_path] when workspace_slug != "" and rel_path != "" ->
        with {:ok, workspace} <- Workspaces.get_by_slug(workspace_slug),
             {:ok, abs} <- safe_join(workspace.root_path, rel_path) do
          {:ok, abs}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  def workspace_file_path(_), do: :error

  @doc "Replaces just the body of a workspace agent markdown file, preserving frontmatter."
  @spec write_persona_body(String.t() | nil, String.t()) :: :ok | {:error, term()}
  def write_persona_body(persona_path, body) when is_binary(body) do
    with {:ok, abs_path} <- workspace_file_path(persona_path),
         {:ok, raw} <- File.read(abs_path) do
      content =
        case Regex.run(@frontmatter_regex, raw) do
          [frontmatter | _] ->
            String.trim_trailing(frontmatter) <> "\n\n" <> String.trim(body) <> "\n"

          nil ->
            String.trim(body) <> "\n"
        end

      File.write(abs_path, content)
    else
      :error -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def write_persona_body(_, _), do: :ok

  defp markdown_files(agents_root) do
    if File.dir?(agents_root) do
      agents_root
      |> Path.join("**/*.md")
      |> Path.wildcard()
      |> Enum.sort()
    else
      []
    end
  end

  defp base_result(workspace_slug, root_path) do
    %{
      workspace_slug: workspace_slug,
      root_path: root_path,
      scanned: 0,
      imported: 0,
      updated: 0,
      skipped: 0,
      errors: [],
      agents: []
    }
  end

  defp add_error(acc, path, reason) do
    rel = Path.relative_to(path, acc.root_path)
    Map.update!(acc, :errors, &[format_error(rel, reason) | &1])
  end

  defp add_agent(acc, agent), do: Map.update!(acc, :agents, &[agent | &1])

  defp import_file(path, root, workspace_slug) do
    with {:ok, raw} <- File.read(path),
         {:ok, attrs} <- attrs_from_markdown(raw, path, root, workspace_slug) do
      upsert(attrs)
    end
  end

  defp attrs_from_markdown(raw, path, root, workspace_slug) do
    frontmatter = parse_frontmatter(raw)
    body = extract_body(raw)
    rel = Path.relative_to(path, root)
    basename_slug = path |> Path.basename(".md") |> slugify()
    slug = frontmatter |> value(["slug", :slug], basename_slug) |> slugify()

    if slug == "" do
      {:error, :missing_slug}
    else
      category =
        frontmatter |> value(["category", :category], "specialized") |> normalise_category()

      name = value(frontmatter, ["name", :name], humanise(slug))

      config =
        %{
          "source" => "workspace",
          "workspace_slug" => workspace_slug,
          "workspace_path" => rel,
          "skills" => list_value(frontmatter, ["skills", :skills]),
          "tools" => list_value(frontmatter, ["tools", :tools]),
          "context_tier" => value(frontmatter, ["context_tier", :context_tier], nil)
        }
        |> Enum.reject(fn {_k, v} -> v in [nil, []] end)
        |> Map.new()

      {:ok,
       %{
         slug: slug,
         category: category,
         name: to_string(name),
         description: value(frontmatter, ["description", :description], nil),
         persona_path: "workspace:#{workspace_slug}:#{rel}",
         persona_markdown: body,
         default_runtime:
           value(frontmatter, ["runtime", :runtime, "default_runtime"], "claude-local"),
         default_model: value(frontmatter, ["model", :model, "default_model"], nil),
         heartbeat_cron:
           value(frontmatter, ["heartbeat_cron", :heartbeat_cron, "heartbeat"], nil),
         budget_monthly_usd:
           decimal_value(frontmatter, ["budget_monthly_usd", "budget", :budget]),
         hired: true,
         config: config
       }}
    end
  end

  defp parse_frontmatter(raw) do
    case Regex.run(@frontmatter_regex, raw, capture: :all_but_first) do
      [yaml] ->
        case YamlElixir.read_from_string(yaml) do
          {:ok, map} when is_map(map) -> map
          _ -> %{}
        end

      nil ->
        %{}
    end
  end

  defp extract_body(raw) do
    case Regex.run(@frontmatter_regex, raw) do
      [match | _] -> raw |> String.slice(String.length(match)..-1//1) |> String.trim()
      nil -> String.trim(raw)
    end
  end

  defp upsert(attrs) do
    case Repo.one(from a in Agent, where: a.slug == ^attrs.slug) do
      nil ->
        case %Agent{} |> Agent.changeset(attrs) |> Repo.insert() do
          {:ok, agent} -> {:inserted, agent}
          {:error, reason} -> {:error, reason}
        end

      %Agent{} = existing ->
        merged =
          Map.update(
            attrs,
            :config,
            existing.config || %{},
            &Map.merge(existing.config || %{}, &1)
          )

        case existing |> Agent.changeset(merged) |> Repo.update() do
          {:ok, agent} -> {:updated, agent}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp safe_join(root, rel_path) do
    root = Path.expand(root)
    abs = Path.expand(Path.join(root, rel_path))

    if abs == root or String.starts_with?(abs, root <> "/") do
      {:ok, abs}
    else
      {:error, :traversal}
    end
  end

  defp value(map, keys, default) do
    Enum.find_value(keys, default, fn key ->
      case Map.get(map, key) do
        nil -> false
        "" -> false
        value -> value
      end
    end)
  end

  defp list_value(map, keys) do
    case value(map, keys, []) do
      values when is_list(values) ->
        Enum.map(values, &to_string/1)

      value when is_binary(value) ->
        value |> String.split([",", "\n"], trim: true) |> Enum.map(&String.trim/1)

      _ ->
        []
    end
  end

  defp decimal_value(map, keys) do
    case value(map, keys, nil) do
      nil -> nil
      value -> Decimal.new(to_string(value))
    end
  rescue
    _ -> nil
  end

  defp normalise_category(raw) do
    category = raw |> to_string() |> String.downcase() |> String.replace("_", "-")
    if category in @canonical_categories, do: category, else: "specialized"
  end

  defp slugify(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp humanise(slug) do
    slug
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_error(path, %Ecto.Changeset{} = changeset),
    do: %{path: path, reason: inspect(changeset.errors)}

  defp format_error(path, reason), do: %{path: path, reason: inspect(reason)}
end
