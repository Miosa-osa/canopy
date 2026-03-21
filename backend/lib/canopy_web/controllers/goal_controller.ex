defmodule CanopyWeb.GoalController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Goal, Issue}
  import Ecto.Query

  def index(conn, params) do
    workspace_id = params["workspace_id"]
    project_id = params["project_id"]

    query = from g in Goal, order_by: [asc: g.title]

    query =
      if workspace_id,
        do: where(query, [g], g.workspace_id == ^workspace_id),
        else: query

    query =
      if project_id,
        do: where(query, [g], g.project_id == ^project_id),
        else: query

    goals = Repo.all(query)
    json(conn, %{goals: Enum.map(goals, &serialize/1)})
  end

  def create(conn, params) do
    changeset = Goal.changeset(%Goal{}, params)

    case Repo.insert(changeset) do
      {:ok, goal} ->
        conn |> put_status(201) |> json(%{goal: serialize(goal)})

      {:error, cs} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(cs)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Goal, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      goal ->
        issue_count = Repo.aggregate(from(i in Issue, where: i.goal_id == ^id), :count)
        children = Repo.all(from(g in Goal, where: g.parent_id == ^id))

        json(conn, %{
          goal:
            serialize(goal)
            |> Map.put(:issue_count, issue_count)
            |> Map.put(:children, Enum.map(children, &serialize/1))
        })
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(Goal, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      goal ->
        changeset = Goal.changeset(goal, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            json(conn, %{goal: serialize(updated)})

          {:error, cs} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(cs)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Goal, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      goal ->
        Repo.delete!(goal)
        json(conn, %{ok: true})
    end
  end

  def ancestry(conn, %{"goal_id" => id}) do
    case Repo.get(Goal, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      goal ->
        chain = build_ancestry(goal, [])
        json(conn, %{ancestry: chain})
    end
  end

  def decompose(conn, %{"goal_id" => goal_id} = params) do
    opts = [
      max_issues: String.to_integer(params["max_issues"] || "10"),
      auto_assign: params["auto_assign"] != "false"
    ]

    case Canopy.GoalDecomposer.decompose(goal_id, opts) do
      {:ok, issues} ->
        conn
        |> put_status(201)
        |> json(%{issues: Enum.map(issues, &serialize/1), count: length(issues)})

      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: inspect(reason)})
    end
  end

  # --- Private helpers ---

  defp build_ancestry(%Goal{parent_id: nil} = goal, acc) do
    [serialize(goal) | acc]
  end

  defp build_ancestry(%Goal{parent_id: parent_id} = goal, acc) do
    case Repo.get(Goal, parent_id) do
      nil -> [serialize(goal) | acc]
      parent -> build_ancestry(parent, [serialize(goal) | acc])
    end
  end

  defp serialize(%Goal{} = g) do
    %{
      id: g.id,
      title: g.title,
      description: g.description,
      status: g.status,
      workspace_id: g.workspace_id,
      project_id: g.project_id,
      parent_id: g.parent_id,
      inserted_at: g.inserted_at,
      updated_at: g.updated_at
    }
  end

  # decompose/2 returns Issue structs; provide a matching clause so the response
  # serializes correctly instead of raising a FunctionClauseError.
  defp serialize(%Issue{} = i) do
    %{
      id: i.id,
      title: i.title,
      description: i.description,
      status: i.status,
      priority: i.priority,
      workspace_id: i.workspace_id,
      project_id: i.project_id,
      goal_id: i.goal_id,
      assignee_id: i.assignee_id,
      inserted_at: i.inserted_at,
      updated_at: i.updated_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
