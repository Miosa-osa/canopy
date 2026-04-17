defmodule Canopy.Agents do
  @moduledoc """
  Public API for Canopy agent management.

  An agent is a persona (markdown frontmatter) combined with a runtime assignment,
  budget limits, and a heartbeat schedule. The 330+ agent library ships as markdown
  files in `priv/agents/`; this module provides the runtime CRUD and hire/fire lifecycle.

  Full heartbeat scheduling via Oban cron is Week 2 scope.
  """

  alias Canopy.Agents.Agent
  alias Canopy.Repo

  @doc "Returns all agents, ordered by category and name."
  @spec list() :: {:ok, [Agent.t()]}
  def list do
    agents = Repo.all(Agent)
    {:ok, agents}
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
  Hires an agent: sets `hired: true`.

  Returns `{:ok, agent}`, `{:error, :not_found}`, or `{:error, changeset}`.
  """
  @spec hire(String.t()) :: {:ok, Agent.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def hire(slug) do
    with {:ok, agent} <- get_by_slug(slug) do
      agent
      |> Agent.hire_changeset(true)
      |> Repo.update()
    end
  end

  @doc """
  Fires an agent: sets `hired: false`.

  Returns `{:ok, agent}`, `{:error, :not_found}`, or `{:error, changeset}`.
  """
  @spec fire(String.t()) :: {:ok, Agent.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def fire(slug) do
    with {:ok, agent} <- get_by_slug(slug) do
      agent
      |> Agent.hire_changeset(false)
      |> Repo.update()
    end
  end
end
