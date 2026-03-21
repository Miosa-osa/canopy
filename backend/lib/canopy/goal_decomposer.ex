defmodule Canopy.GoalDecomposer do
  @moduledoc """
  Decomposes a goal into actionable issues using an LLM.

  The decomposer:
  1. Reads goal + project context
  2. Reads available agents and their roles
  3. Prompts the LLM for a structured list of issues
  4. Creates issues in the DB with suggested assignees
  """
  require Logger

  alias Canopy.Repo
  alias Canopy.Schemas.{Goal, Agent, Workspace}
  import Ecto.Query

  @doc """
  Decompose a goal into issues.

  Options:
    - :max_issues   - maximum number of issues to create (default: 10)
    - :auto_assign  - whether to auto-assign issues to agents (default: true)

  Returns `{:ok, [%Issue{}]}` or `{:error, reason}`.
  """
  def decompose(goal_id, opts \\ []) do
    max_issues = Keyword.get(opts, :max_issues, 10)
    auto_assign = Keyword.get(opts, :auto_assign, true)

    with %Goal{} = goal <- Repo.get(Goal, goal_id) |> Repo.preload(:project),
         workspace_id when not is_nil(workspace_id) <- goal.workspace_id,
         %Workspace{} = workspace <- Repo.get(Workspace, workspace_id),
         agents <- Repo.all(from a in Agent, where: a.workspace_id == ^workspace_id),
         {:ok, issues_data} <- generate_issues(goal, workspace, agents, max_issues) do
      created_issues = create_issues(issues_data, goal, workspace_id, agents, auto_assign)
      {:ok, created_issues}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp generate_issues(goal, workspace, agents, max_issues) do
    agent_roster =
      agents
      |> Enum.map(fn a -> "- #{a.name} (#{a.role}): #{a.slug}" end)
      |> Enum.join("\n")

    project_name =
      case goal.project do
        nil -> "None"
        project -> project.name
      end

    prompt = """
    You are a project manager. Decompose the following goal into #{max_issues} or fewer actionable issues.

    ## Goal
    Title: #{goal.title}
    Description: #{goal.description || "No description provided"}
    Project: #{project_name}

    ## Available Agents
    #{agent_roster}

    ## Instructions
    Return a JSON array of issues. Each issue must have:
    - "title": string (clear, actionable task title)
    - "description": string (detailed instructions for the agent, including input files to read and output files to write)
    - "priority": "critical" | "high" | "medium" | "low"
    - "suggested_agent_slug": string (slug of the best agent for this task, from the roster above)
    - "depends_on": number (0-indexed position of another issue this depends on, or null)

    Return ONLY the JSON array, no other text. Example:
    [{"title": "...", "description": "...", "priority": "high", "suggested_agent_slug": "market-researcher", "depends_on": null}]
    """

    case run_claude_prompt(prompt, workspace.path) do
      {:ok, response} -> parse_issues_json(response)
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_claude_prompt(prompt, cwd) do
    claude_path = Canopy.ClaudeBinary.find()

    case System.cmd(
           claude_path,
           ["--print", "--output-format", "text", prompt],
           cd: cwd,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        {:ok, output}

      {output, code} ->
        Logger.error("[GoalDecomposer] Claude exited #{code}: #{String.slice(output, 0, 200)}")
        {:error, {:claude_failed, code}}
    end
  end

  defp parse_issues_json(response) do
    # Strip markdown code fences if present, then find the JSON array.
    cleaned =
      response
      |> String.replace(~r/```json\n?/, "")
      |> String.replace(~r/```\n?/, "")
      |> String.trim()

    case Regex.run(~r/\[[\s\S]*\]/, cleaned) do
      [json] ->
        case Jason.decode(json) do
          {:ok, list} when is_list(list) -> {:ok, list}
          {:ok, _} -> {:error, :unexpected_json_shape}
          {:error, _} -> {:error, :invalid_json}
        end

      nil ->
        {:error, :no_json_found}
    end
  end

  defp create_issues(issues_data, goal, workspace_id, agents, auto_assign) do
    agents_by_slug = Map.new(agents, fn a -> {a.slug, a} end)

    issues_data
    |> Enum.map(fn data ->
      assignee_id =
        if auto_assign do
          case Map.get(agents_by_slug, data["suggested_agent_slug"]) do
            %Agent{id: id} -> id
            nil -> nil
          end
        end

      attrs = %{
        "title" => data["title"],
        "description" => data["description"],
        "priority" => data["priority"] || "medium",
        "status" => "backlog",
        "goal_id" => goal.id,
        "project_id" => goal.project_id,
        "workspace_id" => workspace_id,
        "assignee_id" => assignee_id
      }

      case Canopy.Work.create_issue(attrs) do
        {:ok, issue} ->
          if assignee_id do
            Canopy.EventBus.broadcast(
              Canopy.EventBus.workspace_topic(workspace_id),
              %{event: "issue.assigned", issue_id: issue.id, agent_id: assignee_id}
            )
          end

          issue

        {:error, changeset} ->
          Logger.warning(
            "[GoalDecomposer] Failed to create issue #{inspect(data["title"])}: #{inspect(changeset.errors)}"
          )

          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
