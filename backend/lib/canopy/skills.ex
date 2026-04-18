defmodule Canopy.Skills do
  @moduledoc """
  Public API for Canopy skill management.

  A skill is a markdown bundle stored in Postgres and injected into agent execution
  environments at runtime. The `content_hash` (SHA256) enables the Paperclip
  bundle-key optimization: if the hash matches the stored `prompt_bundle_key` on a
  session, skill injection is skipped entirely — saving 5–10K tokens per heartbeat.

  Skills are importable from external registries (clawhub, skills_sh) via the
  `Registry.*` modules, or seeded locally from `priv/skills/` via `mix canopy.seed.skills`.

  Provider formats control injection path:
  - `"claude"` — `.claude/skills/{slug}/SKILL.md` (discovered natively by Claude Code)
  - `"agents_md"` — `.agent_context/skills/{slug}/SKILL.md` (OpenCode, Copilot, etc.)
  - `"generic"` — raw markdown block appended to system prompt
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Skills.Skill

  @doc """
  Lists skills with optional filters.

  Options:
  - `:source` — filter by source string (e.g. `"local"`, `"clawhub"`)
  - `:enabled` — `true` or `false` to filter by enabled flag
  - `:tag` — filter to skills whose tags include the given string
  """
  @spec list(keyword()) :: {:ok, [Skill.t()]}
  def list(opts \\ []) do
    query =
      from(s in Skill, order_by: [asc: s.name])
      |> apply_source_filter(Keyword.get(opts, :source))
      |> apply_enabled_filter(Keyword.get(opts, :enabled))
      |> apply_tag_filter(Keyword.get(opts, :tag))

    {:ok, Repo.all(query)}
  end

  @doc "Returns a skill by slug, or `{:error, :not_found}`."
  @spec get_by_slug(String.t()) :: {:ok, Skill.t()} | {:error, :not_found}
  def get_by_slug(slug) do
    case Repo.get_by(Skill, slug: slug) do
      nil -> {:error, :not_found}
      skill -> {:ok, skill}
    end
  end

  @doc """
  Creates a new skill.

  Computes `content_hash` automatically if not provided.
  Returns `{:ok, skill}` or `{:error, changeset}`.
  """
  @spec create(map()) :: {:ok, Skill.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    attrs = maybe_hash(attrs)

    %Skill{}
    |> Skill.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing skill.

  Recomputes `content_hash` when `content` is in attrs.
  Returns `{:ok, skill}` or `{:error, changeset}`.
  """
  @spec update(Skill.t(), map()) :: {:ok, Skill.t()} | {:error, Ecto.Changeset.t()}
  def update(%Skill{} = skill, attrs) do
    attrs = maybe_hash(attrs)

    skill
    |> Skill.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a skill.

  Returns `{:ok, skill}` or `{:error, changeset}`.
  """
  @spec delete(Skill.t()) :: {:ok, Skill.t()} | {:error, Ecto.Changeset.t()}
  def delete(%Skill{} = skill) do
    Repo.delete(skill)
  end

  @doc """
  Computes the SHA256 bundle key for a set of enabled skills.

  Accepts a list of `Skill` structs (or fetches all enabled skills when given slugs).
  The key is derived from sorted, concatenated content — identical content = identical
  key = session skip re-injection. Matches the Paperclip `prompt_bundle_key` pattern.
  """
  @spec bundle_key([Skill.t()] | [String.t()]) :: {:ok, String.t()}
  def bundle_key([]), do: {:ok, hash("")}

  def bundle_key([%Skill{} | _] = skills) do
    combined =
      skills
      |> Enum.sort_by(& &1.slug)
      |> Enum.map_join("\n\n", & &1.content)

    {:ok, hash(combined)}
  end

  def bundle_key(slugs) when is_list(slugs) do
    {:ok, skills} = list(enabled: true)
    matching = Enum.filter(skills, &(&1.slug in slugs))
    bundle_key(matching)
  end

  @doc """
  Builds the markdown injection block for an agent.

  The block is formatted according to `provider_format`:
  - `"claude"` — heading + markdown content (injected via CLAUDE.md)
  - `"agents_md"` — heading + markdown content (injected via AGENTS.md)
  - `"generic"` — heading + markdown content (appended directly to system prompt)

  Returns a single string concatenating all matching skills.
  """
  @spec inject_for(String.t(), String.t()) :: String.t()
  def inject_for(agent_slug, runtime_type) do
    {:ok, skills} = list(enabled: true)

    format = runtime_type_to_format(runtime_type)

    skills
    |> Enum.filter(&(&1.provider_format == format or &1.provider_format == "generic"))
    |> Enum.sort_by(& &1.slug)
    |> Enum.map_join("\n\n---\n\n", fn skill ->
      render_skill_block(skill, agent_slug)
    end)
  end

  @doc """
  Upserts a skill by slug (insert or update on conflict).

  Used by `mix canopy.seed.skills` and the import API. Computes `content_hash`
  automatically.
  """
  @spec upsert(map()) :: {:ok, Skill.t()} | {:error, Ecto.Changeset.t()}
  def upsert(attrs) do
    attrs = maybe_hash(attrs)

    case get_by_slug(attrs[:slug] || attrs["slug"]) do
      {:ok, skill} -> update(skill, attrs)
      {:error, :not_found} -> create(attrs)
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec apply_source_filter(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp apply_source_filter(query, nil), do: query
  defp apply_source_filter(query, source), do: from(s in query, where: s.source == ^source)

  @spec apply_enabled_filter(Ecto.Query.t(), boolean() | nil) :: Ecto.Query.t()
  defp apply_enabled_filter(query, nil), do: query
  defp apply_enabled_filter(query, val), do: from(s in query, where: s.enabled == ^val)

  @spec apply_tag_filter(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp apply_tag_filter(query, nil), do: query

  defp apply_tag_filter(query, tag),
    do: from(s in query, where: ^tag in s.tags)

  @spec maybe_hash(map()) :: map()
  defp maybe_hash(%{"content" => content} = attrs) when is_binary(content),
    do: Map.put(attrs, "content_hash", hash(content))

  defp maybe_hash(%{content: content} = attrs) when is_binary(content),
    do: Map.put(attrs, :content_hash, hash(content))

  defp maybe_hash(attrs), do: attrs

  @spec hash(String.t()) :: String.t()
  defp hash(content) do
    :crypto.hash(:sha256, content)
    |> Base.encode16(case: :lower)
  end

  @spec runtime_type_to_format(String.t()) :: String.t()
  defp runtime_type_to_format("claude-local"), do: "claude"
  defp runtime_type_to_format("claude-code"), do: "claude"
  defp runtime_type_to_format("opencode"), do: "agents_md"
  defp runtime_type_to_format("copilot"), do: "agents_md"
  defp runtime_type_to_format(_), do: "generic"

  @spec render_skill_block(Skill.t(), String.t()) :: String.t()
  defp render_skill_block(skill, _) do
    """
    ## Skill: #{skill.name}

    #{skill.content}
    """
    |> String.trim_trailing()
  end
end
