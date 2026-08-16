defmodule Canopy.Agents do
  @moduledoc """
  Public API for Canopy agent management.

  An agent is a persona (markdown frontmatter) combined with a runtime assignment,
  budget limits, and a heartbeat schedule. The 330+ agent library ships as markdown
  files in `priv/agents/`; this module provides the runtime CRUD and hire/fire lifecycle.

  Heartbeat scheduling is handled by `Canopy.Heartbeat.Registrar`. Hiring an agent
  registers its Oban cron job chain; firing unregisters it.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Agents.Agent
  alias Canopy.Agents.WorkspaceSync
  alias Canopy.Heartbeat.Registrar
  alias Canopy.Repo

  @doc """
  Returns all agents, ordered by category and name.

  Options:
  - `:hired` — `true` to return only hired agents, `false` for unhired, `nil` for all.
  - `:category` — filter by canonical top-level category.
  - `:query` — case-insensitive search across slug, name, description, and org metadata.
  """
  @spec list(keyword()) :: {:ok, [Agent.t()]}
  def list(opts \\ []) do
    hired_filter = Keyword.get(opts, :hired)
    category_filter = Keyword.get(opts, :category)
    query_filter = Keyword.get(opts, :query)

    query =
      from(a in Agent, order_by: [asc: a.category, asc: a.name])
      |> apply_hired_filter(hired_filter)
      |> apply_category_filter(category_filter)
      |> apply_query_filter(query_filter)

    {:ok, Repo.all(query)}
  end

  @doc "Returns only hired agents, ordered by category and name."
  @spec list_hired() :: {:ok, [Agent.t()]}
  def list_hired, do: list(hired: true)

  @doc """
  Creates a new user-defined agent and immediately hires it.

  Accepts a map with the following keys (atoms or strings):
    - `:slug` (required) — URL-safe identifier, lowercase kebab-case
    - `:name` (required)
    - `:category` (required)
    - `:persona_path` (required) — stored as-is; use a sentinel like `"user/<slug>.md"`
    - `:description` (optional)
    - `:persona_markdown` (optional) — the system-prompt body
    - `:default_runtime` (optional)
    - `:default_model` (optional)
    - `:heartbeat_cron` (optional)

  The new agent is inserted with `hired: true` so it is immediately available.

  Returns `{:ok, agent}` on success, `{:error, changeset}` on validation or
  uniqueness failure.
  """
  @spec create(map()) :: {:ok, Agent.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Agent{}
    |> Agent.changeset(Map.merge(%{hired: true}, normalize_attrs(attrs)))
    |> Repo.insert()
  end

  @doc "Returns an agent by slug, or `{:error, :not_found}`."
  @spec get_by_slug(String.t()) :: {:ok, Agent.t()} | {:error, :not_found}
  def get_by_slug(slug) do
    case Repo.get_by(Agent, slug: slug) do
      nil -> {:error, :not_found}
      agent -> {:ok, agent}
    end
  end

  @doc """
  Hires an agent: sets `hired: true` and registers its heartbeat cron schedule.

  If the agent has a `heartbeat_cron` set, an Oban job is inserted for the next
  fire time. Returns `{:ok, agent}`, `{:error, :not_found}`, or `{:error, changeset}`.

  If cron registration fails (e.g. invalid expression), the hire itself still
  succeeds — the error is logged by the Registrar.
  """
  @spec hire(String.t()) :: {:ok, Agent.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def hire(slug) do
    with {:ok, agent} <- get_by_slug(slug),
         {:ok, hired_agent} <-
           agent
           |> Agent.hire_changeset(true)
           |> Repo.update() do
      Registrar.register(hired_agent)
      {:ok, hired_agent}
    end
  end

  @doc """
  Updates the persona markdown content for an agent.

  Writes `content` into the `persona_markdown` DB column via a changeset and
  returns `{:ok, updated_agent}`. Returns `{:error, :not_found}` when the slug
  is unknown, or `{:error, changeset}` on a constraint violation.

  The file at `persona_path` is NOT touched — it is the seed source only and
  is never written at runtime. `persona_markdown` is the authoritative value.
  """
  @spec update_persona(String.t(), String.t()) ::
          {:ok, Agent.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_persona(slug, content) when is_binary(content) do
    with {:ok, agent} <- get_by_slug(slug) do
      with {:ok, updated_agent} <-
             agent
             |> Agent.persona_changeset(content)
             |> Repo.update(),
           :ok <- WorkspaceSync.write_persona_body(updated_agent.persona_path, content) do
        {:ok, updated_agent}
      end
    end
  end

  @doc """
  Imports `.canopy/agents/**/*.md` from a workspace into runtime agent rows.

  The markdown files remain the portable source. The database row is the runtime
  cache used by sessions, heartbeats, MCP prompts, and the UI.
  """
  @spec sync_workspace(String.t()) :: {:ok, WorkspaceSync.sync_result()} | {:error, term()}
  def sync_workspace(workspace_slug), do: WorkspaceSync.sync(workspace_slug)

  @doc """
  Fires an agent: sets `hired: false` and cancels pending heartbeat jobs.

  Returns `{:ok, agent}`, `{:error, :not_found}`, or `{:error, changeset}`.
  """
  @spec fire(String.t()) :: {:ok, Agent.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def fire(slug) do
    with {:ok, agent} <- get_by_slug(slug),
         {:ok, fired_agent} <-
           agent
           |> Agent.hire_changeset(false)
           |> Repo.update() do
      Registrar.unregister(slug)
      {:ok, fired_agent}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec apply_hired_filter(Ecto.Query.t(), boolean() | nil) :: Ecto.Query.t()
  defp apply_hired_filter(query, nil), do: query
  defp apply_hired_filter(query, val), do: from(a in query, where: a.hired == ^val)

  @spec apply_category_filter(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp apply_category_filter(query, nil), do: query
  defp apply_category_filter(query, ""), do: query

  defp apply_category_filter(query, category),
    do: from(a in query, where: a.category == ^category)

  @spec apply_query_filter(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp apply_query_filter(query, nil), do: query
  defp apply_query_filter(query, ""), do: query

  defp apply_query_filter(query, raw_query) do
    pattern = "%#{String.downcase(raw_query)}%"

    from(a in query,
      where:
        like(fragment("lower(?)", a.slug), ^pattern) or
          like(fragment("lower(?)", a.name), ^pattern) or
          like(fragment("lower(coalesce(?, ''))", a.description), ^pattern) or
          like(fragment("lower(coalesce(?->>'team', ''))", a.config), ^pattern) or
          like(fragment("lower(coalesce(?->>'department', ''))", a.config), ^pattern) or
          like(fragment("lower(coalesce(?->>'division', ''))", a.config), ^pattern)
    )
  end

  # Normalise string-keyed maps to atom-keyed maps so changeset cast works
  # regardless of whether the caller passes atom or string keys.
  @spec normalize_attrs(map()) :: map()
  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    ArgumentError -> attrs
  end
end
