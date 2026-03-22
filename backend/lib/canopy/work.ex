defmodule Canopy.Work do
  @moduledoc "Work management context — issues, projects, goals."

  alias Canopy.Repo
  alias Canopy.Schemas.{Issue, Project, Goal, Comment}
  import Ecto.Query

  # ── Issues ──────────────────────────────────────────────────────────────────

  def list_issues(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from i in Issue, order_by: [desc: i.updated_at], limit: ^limit, offset: ^offset

    query = if ws = opts[:workspace_id], do: where(query, [i], i.workspace_id == ^ws), else: query
    query = if s = opts[:status], do: where(query, [i], i.status == ^s), else: query
    query = if p = opts[:priority], do: where(query, [i], i.priority == ^p), else: query
    query = if pid = opts[:project_id], do: where(query, [i], i.project_id == ^pid), else: query
    query = if aid = opts[:assignee_id], do: where(query, [i], i.assignee_id == ^aid), else: query

    {Repo.all(query), Repo.aggregate(Issue, :count)}
  end

  def get_issue(id), do: Repo.get(Issue, id)

  def get_issue_with_comments(id), do: Repo.get(Issue, id) |> Repo.preload(:comments)

  def create_issue(attrs) do
    result = %Issue{} |> Issue.changeset(attrs) |> Repo.insert()

    case result do
      {:ok, issue} ->
        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(issue.workspace_id),
          %{event: "issue.created", issue_id: issue.id, title: issue.title}
        )

        {:ok, issue}

      error ->
        error
    end
  end

  def update_issue(%Issue{} = issue, attrs) do
    old_status = issue.status
    result = issue |> Issue.changeset(attrs) |> Repo.update()

    case result do
      {:ok, updated} when old_status != updated.status ->
        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(updated.workspace_id),
          %{
            event: "issue.status_changed",
            issue_id: updated.id,
            from: old_status,
            to: updated.status
          }
        )

        {:ok, updated}

      other ->
        other
    end
  end

  def delete_issue(%Issue{} = issue), do: Repo.delete(issue)

  def assign_issue(%Issue{} = issue, agent_id) do
    {:ok, updated} = issue |> Ecto.Changeset.change(assignee_id: agent_id) |> Repo.update()

    Canopy.EventBus.broadcast(
      Canopy.EventBus.workspace_topic(updated.workspace_id),
      %{event: "issue.assigned", issue_id: updated.id, agent_id: agent_id}
    )

    {:ok, updated}
  end

  def checkout_issue(issue_id, agent_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.update_all(
      from(i in Issue,
        where: i.id == ^issue_id and is_nil(i.checked_out_by)
      ),
      set: [checked_out_by: agent_id, status: "in_progress", updated_at: now]
    ) do
      {1, _} -> {:ok, Repo.get!(Issue, issue_id)}
      {0, _} -> {:error, :already_checked_out}
    end
  end

  def create_comment(issue_id, attrs) do
    %Comment{}
    |> Comment.changeset(Map.put(attrs, "issue_id", issue_id))
    |> Repo.insert()
  end

  def list_comments(issue_id) do
    Repo.all(
      from c in Comment,
        where: c.issue_id == ^issue_id,
        order_by: [asc: c.inserted_at]
    )
  end

  # ── Projects ────────────────────────────────────────────────────────────────

  def list_projects(opts \\ []) do
    query = from p in Project, order_by: [desc: p.updated_at]
    query = if ws = opts[:workspace_id], do: where(query, [p], p.workspace_id == ^ws), else: query
    Repo.all(query)
  end

  def get_project(id), do: Repo.get(Project, id)

  def get_project_with_goals(id), do: Repo.get(Project, id) |> Repo.preload(:goals)

  def create_project(attrs), do: %Project{} |> Project.changeset(attrs) |> Repo.insert()

  def update_project(%Project{} = p, attrs), do: p |> Project.changeset(attrs) |> Repo.update()

  def delete_project(%Project{} = p), do: Repo.delete(p)

  def list_project_goals(project_id) do
    Repo.all(from g in Goal, where: g.project_id == ^project_id, order_by: [asc: g.title])
  end

  # ── Goals ────────────────────────────────────────────────────────────────────

  def list_goals(opts \\ []) do
    query = from g in Goal, order_by: [asc: g.title]
    query = if ws = opts[:workspace_id], do: where(query, [g], g.workspace_id == ^ws), else: query
    query = if pid = opts[:project_id], do: where(query, [g], g.project_id == ^pid), else: query
    Repo.all(query)
  end

  def get_goal(id), do: Repo.get(Goal, id)

  def get_goal_with_children(id) do
    goal = Repo.get(Goal, id)
    children = if goal, do: Repo.all(from g in Goal, where: g.parent_id == ^id), else: []

    issue_count =
      if goal, do: Repo.aggregate(from(i in Issue, where: i.goal_id == ^id), :count), else: 0

    {goal, children, issue_count}
  end

  def create_goal(attrs), do: %Goal{} |> Goal.changeset(attrs) |> Repo.insert()

  def update_goal(%Goal{} = g, attrs), do: g |> Goal.changeset(attrs) |> Repo.update()

  def delete_goal(%Goal{} = g), do: Repo.delete(g)

  def get_goal_ancestry(goal_id) do
    build_ancestry(goal_id, MapSet.new())
  end

  defp build_ancestry(nil, _visited), do: []

  defp build_ancestry(goal_id, visited) do
    if MapSet.member?(visited, goal_id) do
      []  # Break cycle
    else
      case Repo.get(Goal, goal_id) do
        nil -> []
        goal -> [goal | build_ancestry(goal.parent_id, MapSet.put(visited, goal_id))]
      end
    end
  end
end
