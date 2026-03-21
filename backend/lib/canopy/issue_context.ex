defmodule Canopy.IssueContext do
  @moduledoc """
  Pure functions for building structured context strings that are injected
  into an agent's prompt when it is assigned an issue.

  Callers are responsible for preloading associations before calling
  `build_context/2`:

      issue
      |> Repo.preload([:workspace, goal: :project])

      agent
      |> Repo.preload(:workspace)
  """

  alias Canopy.Schemas.Agent
  alias Canopy.Schemas.Issue

  @doc """
  Builds a plain-text context block describing the assigned issue and the
  executing agent's role.

  ## Parameters

    - `issue` - an `%Issue{}` with `:goal` preloaded (and `:goal` with
      `:project` preloaded when a goal is present).  The issue's `:workspace`
      association must also be preloaded so the workspace path is available.
    - `agent` - an `%Agent{}` with `:workspace` preloaded.

  ## Returns

  A `String.t()` containing the formatted context block.
  """
  @spec build_context(Issue.t(), Agent.t()) :: String.t()
  def build_context(%Issue{} = issue, %Agent{} = agent) do
    goal_title = goal_title(issue)
    project_name = project_name(issue)
    workspace_path = workspace_path(agent)

    """
    ## Assigned Task

    **Issue:** #{issue.title}
    **Priority:** #{issue.priority}
    **Goal:** #{goal_title}
    **Project:** #{project_name}

    ### Description
    #{issue.description || "No description provided."}

    ### Instructions
    - Read any referenced input files before starting
    - Write your output to the appropriate output/ subdirectory
    - Follow the methodology defined in your system prompt
    - Ensure output meets quality gates defined in the workspace spec

    ### Workspace
    - Path: #{workspace_path}
    - Your role: #{agent.role}
    """
    |> String.trim_trailing()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp goal_title(%Issue{goal: %{title: title}}) when is_binary(title), do: title
  defp goal_title(_issue), do: "None"

  defp project_name(%Issue{goal: %{project: %{name: name}}}) when is_binary(name), do: name
  defp project_name(_issue), do: "None"

  defp workspace_path(%Agent{workspace: %{path: path}}) when is_binary(path), do: path
  defp workspace_path(_agent), do: "Unknown"
end
