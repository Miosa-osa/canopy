defmodule Canopy.Workspaces do
  @moduledoc """
  Public API for Canopy workspace management.

  A workspace is a directory on the user's filesystem (or MIOSA sandbox) that
  follows the Canopy Workspace Protocol: structured markdown folders defining
  org context, goals, agent assignments, and active tasks.

  Full workspace protocol parsing and MIOSA sandbox integration are Week 2 scope.
  """

  alias Canopy.Repo
  alias Canopy.Workspaces.Workspace

  @doc "Returns all workspaces, ordered by name."
  @spec list() :: {:ok, [Workspace.t()]}
  def list do
    workspaces = Repo.all(Workspace)
    {:ok, workspaces}
  end

  @doc "Returns a workspace by slug, or `{:error, :not_found}`."
  @spec get_by_slug(String.t()) :: {:ok, Workspace.t()} | {:error, :not_found}
  def get_by_slug(slug) do
    case Repo.get_by(Workspace, slug: slug) do
      nil -> {:error, :not_found}
      workspace -> {:ok, workspace}
    end
  end

  @doc """
  Creates a new workspace from the given attrs.

  Returns `{:ok, workspace}` or `{:error, changeset}`.
  """
  @spec create(map()) :: {:ok, Workspace.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end
end
